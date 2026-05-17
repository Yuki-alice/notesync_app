// Supabase 云端同步主协调器
// 作为同步体系的入口，协调各子服务完成笔记、待办、分类标签、图片的双向同步。
// 子服务职责拆分如下：
// - SupabaseDeletionSync: 本地删除记录与废纸篓清理
// - SupabaseNoteSync: 笔记增量同步与冲突解决
// - SupabaseCategoryTagSync: 分类和标签同步
// - SupabaseNoteConflictResolver: 笔记冲突检测与对话框交互
// - SupabaseTodoSync: 待办增量同步
// - SupabaseImageSync: 图片上传下载与隐私图片同步
// - SupabaseRetryWrapper: 网络重试机制
//
// 公共 API 接口保持不变，调用方无需感知内部拆分。

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/category_repository.dart';
import '../../repositories/note_repository.dart';
import '../../repositories/tag_repository.dart';
import '../../repositories/todo_repository.dart';
import '../../../models/note.dart';

import '../performance/perf.dart';
import 'sync_models.dart';
import 'supabase_retry_wrapper.dart';
import 'supabase_deletion_sync.dart';
import 'supabase_note_sync.dart';
import 'supabase_category_tag_sync.dart';
import 'supabase_note_conflict_resolver.dart';
import 'supabase_todo_sync.dart';
import 'supabase_image_sync.dart';

// Re-export for backward compatibility
export 'sync_models.dart' show SyncException, SyncErrorType;
export 'supabase_note_sync.dart' show NoteSyncMeta, NoteSyncResult;

class SupabaseSyncService {
  final _supabase = Supabase.instance.client;
  final NoteRepository? _noteRepo;
  final TodoRepository? _todoRepo;
  final CategoryRepository? _categoryRepo;
  final TagRepository? _tagRepo;

  late final SupabaseRetryWrapper _retry;
  late final SupabaseDeletionSync _deletionSync;
  late final SupabaseCategoryTagSync _categoryTagSync;
  late final SupabaseNoteConflictResolver _conflictResolver;
  late final SupabaseNoteSync _noteSync;
  late final SupabaseTodoSync _todoSync;
  late final SupabaseImageSync _imageSync;

  SupabaseSyncService([this._noteRepo, this._todoRepo, this._categoryRepo, this._tagRepo]) {
    _retry = const SupabaseRetryWrapper();
    _deletionSync = SupabaseDeletionSync(_supabase, _retry);
    _categoryTagSync = SupabaseCategoryTagSync(_supabase, _categoryRepo, _tagRepo, _retry);
    _conflictResolver = SupabaseNoteConflictResolver(_supabase, _noteRepo);
    _noteSync = SupabaseNoteSync(_supabase, _noteRepo, _retry, _deletionSync, _categoryTagSync, _conflictResolver);
    _todoSync = SupabaseTodoSync(_supabase, _todoRepo, _retry, _deletionSync);
    _imageSync = SupabaseImageSync(_supabase, _noteRepo);
  }

  // =========================================================================
  // 公共 API - 删除记录
  // =========================================================================

  Future<void> recordDeletedTodoId(String id) => _deletionSync.recordDeletedTodoId(id);
  Future<void> recordDeletedNoteId(String id) => _deletionSync.recordDeletedNoteId(id);
  Future<void> recordDeletedCategory(String categoryId) => _deletionSync.recordDeletedCategory(categoryId);
  Future<void> recordDeletedTag(String tagId) => _deletionSync.recordDeletedTag(tagId);

  // =========================================================================
  // 公共 API - 笔记同步
  // =========================================================================

  Future<void> syncNotes({
    Function()? onTextSyncComplete,
    dynamic context,
  }) async {
    final syncStopwatch = Stopwatch()..start();
    SyncLogger.info('SYNC', '🚀 笔记同步开始');
    await Perf.trace('sync.notes', () async {
      final syncResult = await _noteSync.syncNotes(
        onTextSyncComplete: onTextSyncComplete,
        context: context,
      );

      // 🌟 让出事件循环，允许 UI 渲染帧
      await Future(() {});

      // 笔记文本同步完成后，执行图片资源同步
      if (_noteRepo != null && _supabase.auth.currentUser != null) {
        try {
          // 🌟 优化：只同步本次推送/拉取的笔记图片，而非所有笔记
          final notesToSyncImages = <Note>[];
          notesToSyncImages.addAll(syncResult.pushedNotes);
          notesToSyncImages.addAll(syncResult.pulledNotes);

          if (notesToSyncImages.isNotEmpty) {
            SyncLogger.info('IMAGE', '开始同步 ${notesToSyncImages.length} 条笔记的图片（推送 ${syncResult.pushedNotes.length}，拉取 ${syncResult.pulledNotes.length}）');

            // 只上传本次推送的笔记图片
            if (syncResult.pushedNotes.isNotEmpty) {
              await _imageSync.uploadImages(syncResult.pushedNotes);
              await Future(() {}); // 让出事件循环
            }

            // 只下载本次拉取的笔记图片
            if (syncResult.pulledNotes.isNotEmpty) {
              await _imageSync.downloadImages(syncResult.pulledNotes);
              await Future(() {}); // 让出事件循环
            }

            // 云端垃圾回收（只在有推送时执行）
            if (syncResult.pushedNotes.isNotEmpty) {
              await _imageSync.cleanUpCloudImages(_noteRepo!.getAllNotes());
            }
          } else {
            SyncLogger.info('IMAGE', '无需同步图片');
          }

          // 同步 attachments 表（迁移已有数据，仅首次执行，独立于笔记同步）
          await _imageSync.syncAttachmentsTable(_noteRepo!.getAllNotes());
        } catch (e) {
          SyncLogger.error('IMAGE', '图片同步或清理管线异常', e);
        }
      }
    });
    syncStopwatch.stop();
    SyncLogger.info('SYNC', '✅ 笔记同步完成，耗时 ${syncStopwatch.elapsedMilliseconds}ms');
  }

  // =========================================================================
  // 公共 API - 隐私图片同步
  // =========================================================================

  Future<void> syncPrivateImagesOnly() => _imageSync.syncPrivateImagesOnly();

  // =========================================================================
  // 公共 API - 待办同步
  // =========================================================================

  Future<void> syncTodos({Function()? onSyncComplete}) async {
    await Perf.trace('sync.todos', () => _todoSync.syncTodos(onSyncComplete: onSyncComplete));
  }
}
