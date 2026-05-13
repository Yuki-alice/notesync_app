// 笔记同步核心逻辑
// 负责笔记的增量双向同步，包括：
// - 笔记拉取与推送（含隐私笔记加密处理）
// - 委托 SupabaseCategoryTagSync 处理分类和标签同步
// - 委托 SupabaseNoteConflictResolver 处理冲突解决

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/note_repository.dart';
import '../security/privacy_service.dart';
import '../storage/storage_quota_service.dart';
import '../../../models/user_quota.dart';
import '../../../models/note.dart';

import '../../constants/sync_constants.dart';
import 'sync_models.dart';
import 'supabase_retry_wrapper.dart';
import 'supabase_deletion_sync.dart';
import 'supabase_category_tag_sync.dart';
import 'supabase_note_conflict_resolver.dart';

export '../../repositories/note_repository.dart' show NoteSyncMeta;

/// 🌟 后台 Isolate 解析函数：将云端 JSON 列表解析为 Note 对象
List<Note> _parseNotesFromJson(List<dynamic> rawList) {
  final List<Note> notes = [];
  for (var map in rawList) {
    try {
      final rawTags = map['note_tags'] as List<dynamic>?;
      final List<String> tagIds = rawTags != null ? rawTags.map((t) => t['tag_id'].toString()).toList() : [];

      notes.add(Note(
        id: map['id'].toString(),
        title: map['title']?.toString() ?? '',
        content: map['content']?.toString() ?? '',
        createdAt: DateTime.parse(map['created_at'].toString()).toLocal(),
        updatedAt: DateTime.parse(map['updated_at'].toString()).toLocal(),
        categoryId: map['category_id']?.toString(),
        tagIds: tagIds,
        version: (map['version'] as int?) ?? 1,
        isPinned: map['is_pinned'] == true,
        isDeleted: map['is_deleted'] == true,
        isPrivate: map['is_private'] == true,
      ));
    } catch (e) {
      // 解析失败的笔记跳过，不影响其他笔记
    }
  }
  return notes;
}

/// 笔记同步结果（用于协调图片同步）
class NoteSyncResult {
  final List<Note> pulledNotes;
  final List<Note> pushedNotes;

  NoteSyncResult({required this.pulledNotes, required this.pushedNotes});
}

class SupabaseNoteSync {
  final SupabaseClient _supabase;
  final NoteRepository? _noteRepo;
  final SupabaseRetryWrapper _retry;
  final SupabaseDeletionSync _deletionSync;
  final SupabaseCategoryTagSync _categoryTagSync;
  final SupabaseNoteConflictResolver _conflictResolver;

  SupabaseNoteSync(
      this._supabase,
      this._noteRepo,
      this._retry,
      this._deletionSync,
      this._categoryTagSync,
      this._conflictResolver,
      );

  // =========================================================================
  // 笔记同步主入口
  // =========================================================================

  Future<NoteSyncResult> syncNotes({
    Function()? onTextSyncComplete,
    BuildContext? context,
  }) async {
    if (_noteRepo == null) return NoteSyncResult(pulledNotes: [], pushedNotes: []);
    if (_supabase.auth.currentUser == null) {
      SyncLogger.warn('NOTE', '未登录，中止同步');
      return NoteSyncResult(pulledNotes: [], pushedNotes: []);
    }

    SyncLogger.info('NOTE', '====== 🚀 启动 V2.0 笔记同步管线 ======');
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = _supabase.auth.currentUser!.id;

      // 1. 优先同步分类和标签字典 (基建数据先到位)
      await _categoryTagSync.syncCategoriesAndTags(currentUserId, prefs);
      await Future(() {}); // 让出事件循环，避免阻塞 UI

      // 2. 清理笔记废纸篓
      await _deletionSync.processLocalDeletions(prefs, 'notes', deletedNotesKey);
      await Future(() {}); // 让出事件循环

      final lastSyncStr = prefs.getString(lastNoteSyncKey);
      final lastSyncTime = lastSyncStr != null ? DateTime.parse(lastSyncStr) : null;
      SyncLogger.info('NOTE', '上次同步时间: ${lastSyncTime?.toLocal() ?? "从未同步"}');

      // 🌟 读取上次同步时的版本号记录
      final lastSyncedVersionsJson = prefs.getString(lastSyncedVersionsKey);
      final Map<String, int> lastSyncedVersions = lastSyncedVersionsJson != null
          ? Map<String, int>.from(jsonDecode(lastSyncedVersionsJson) as Map)
          : {};
      SyncLogger.info('NOTE', '已记录 ${lastSyncedVersions.length} 条笔记的上次同步版本');

      // 3. 笔记主表拉取比对 (🌟 基于版本号 + lastSyncedVersion，支持真正的冲突检测)
      final cloudMetadataWithVersion = await _fetchCloudMetadataWithVersion(currentUserId);
      final localMetaMapWithVersion = _noteRepo.getAllNotesMetadataWithVersion();

      final plan = _conflictResolver.reconcileDataWithVersion(
        localMetaMap: localMetaMapWithVersion,
        cloudMetadata: cloudMetadataWithVersion,
        lastSyncTime: lastSyncTime,
        lastSyncedVersions: lastSyncedVersions,
      );

      // 🌟 处理冲突（如果有）
      Map<String, String> conflictResults = {};
      if (plan.conflicts.isNotEmpty && context != null && context.mounted) {
        SyncLogger.warn('NOTE', '检测到 ${plan.conflicts.length} 条笔记冲突，显示解决对话框');
        conflictResults = await _conflictResolver.resolveConflicts(
          context: context,
          conflicts: plan.conflicts,
        );
      } else if (plan.conflicts.isNotEmpty) {
        SyncLogger.warn('NOTE', '检测到 ${plan.conflicts.length} 条笔记冲突，但无上下文，跳过处理');
      }

      // 合并冲突解决结果到同步计划
      final finalToPull = [...plan.toPull];
      final finalToPush = [...plan.toPush];

      for (var entry in conflictResults.entries) {
        final conflictId = entry.key;
        final choice = entry.value;

        if (choice == 'skip') {
          finalToPull.remove(conflictId);
          finalToPush.remove(conflictId);
        } else if (choice == 'local') {
          finalToPull.remove(conflictId);
          if (!finalToPush.contains(conflictId)) {
            finalToPush.add(conflictId);
          }
        } else if (choice == 'cloud') {
          finalToPush.remove(conflictId);
          if (!finalToPull.contains(conflictId)) {
            finalToPull.add(conflictId);
          }
        }
      }

      // 🌟 执行拉取操作
      List<Note> pulledNotes = [];
      if (finalToPull.isNotEmpty) {
        SyncLogger.info('SYNC', '📥 计划拉取 ${finalToPull.length} 条笔记从云端');
        pulledNotes = await _pullNotes(finalToPull, currentUserId, localMetaMapWithVersion.keys.toSet());
        await Future(() {}); // 让出事件循环，允许 UI 渲染
      } else {
        SyncLogger.info('SYNC', '📥 无需拉取笔记（云端无更新）');
      }

      // 🌟 执行推送操作
      List<Note> pushedNotes = [];
      if (finalToPush.isNotEmpty) {
        SyncLogger.info('SYNC', '📤 计划推送 ${finalToPush.length} 条笔记到云端');
        pushedNotes = await _pushNotes(finalToPush, currentUserId);
        await Future(() {}); // 让出事件循环
      } else {
        SyncLogger.info('SYNC', '📤 无需推送笔记（本地无更新）');
      }

      // 🌟 处理本地删除
      for (var id in plan.toDeleteLocally) {
        await _noteRepo.deleteNote(id);
        SyncLogger.info('NOTE', '👻 成功抹除本地幽灵笔记: $id');
      }

      await prefs.setString(lastNoteSyncKey, DateTime.now().toUtc().toIso8601String());

      // 🌟 保存本次同步后的版本号记录（用于下次冲突检测）
      final updatedLastSyncedVersions = <String, int>{};
      for (var entry in localMetaMapWithVersion.entries) {
        updatedLastSyncedVersions[entry.key] = entry.value.version;
      }
      // 合并云端版本（对于云端有但本地没有的笔记）
      for (var entry in cloudMetadataWithVersion.entries) {
        if (!updatedLastSyncedVersions.containsKey(entry.key)) {
          updatedLastSyncedVersions[entry.key] = entry.value.version;
        }
      }
      await prefs.setString(lastSyncedVersionsKey, jsonEncode(updatedLastSyncedVersions));
      SyncLogger.info('NOTE', '已保存 ${updatedLastSyncedVersions.length} 条笔记的同步版本号');

      if (onTextSyncComplete != null) onTextSyncComplete();

      // 4. 图片资源分离同步（由主协调器调用 SupabaseImageSync）
      // 图片同步逻辑已移至 SupabaseImageSync，此处通过 onTextSyncComplete 回调通知主协调器

      SyncLogger.info('NOTE', '====== ✅ 笔记同步管线完美收官 ======');
      return NoteSyncResult(pulledNotes: pulledNotes, pushedNotes: pushedNotes);
    } catch (e) {
      SyncLogger.error('NOTE', '同步管线崩溃', e);
      return NoteSyncResult(pulledNotes: [], pushedNotes: []);
    }
  }

  // =========================================================================
  // 笔记拉取
  // =========================================================================

  Future<List<Note>> _pullNotes(List<String> idsToFetch, String userId, Set<String> existingLocalIds) async {
    SyncLogger.info('PULL', '准备从云端拉取 ${idsToFetch.length} 条笔记内容...');

    // 构建所有批次
    final List<List<String>> batches = [];
    for (var i = 0; i < idsToFetch.length; i += SyncConstants.supabaseBatchSize) {
      final end = i + SyncConstants.supabaseBatchSize > idsToFetch.length
          ? idsToFetch.length
          : i + SyncConstants.supabaseBatchSize;
      batches.add(idsToFetch.sublist(i, end));
    }

    // 🌟 并发拉取所有批次
    final List<List<dynamic>> allResults = await Future.wait(
      batches.map((chunk) => _fetchNoteChunk(chunk, userId)),
    );

    // 🌟 在后台 Isolate 中解析 JSON，避免阻塞主线程
    final flatResults = allResults.expand((e) => e).toList();
    final List<Note> allNotes = await compute(_parseNotesFromJson, flatResults);

    // 🌟 一次性批量写入所有笔记
    if (allNotes.isNotEmpty) {
      await _noteRepo!.saveNotesFromSync(allNotes);
      SyncLogger.info('PULL', '✅ 批量写入 ${allNotes.length} 条笔记到本地');
    }

    return allNotes;
  }

  /// 获取单个批次的笔记数据（支持降级查询）
  Future<List<dynamic>> _fetchNoteChunk(List<String> chunk, String userId) async {
    try {
      final res = await _retry.withRetry(
        operation: () => _supabase.from('notes')
            .select('*, note_tags(tag_id)')
            .inFilter('id', chunk)
            .eq('user_id', userId),
        operationName: '拉取笔记详情',
      );
      return res as List<dynamic>;
    } catch (e) {
      SyncLogger.warn('PULL', '包含 note_tags 的高级查询失败，自动退回基础单表查询: $e');
      try {
        final res = await _retry.withRetry(
          operation: () => _supabase.from('notes')
              .select('*')
              .inFilter('id', chunk)
              .eq('user_id', userId),
          operationName: '拉取笔记详情(降级)',
        );
        return res as List<dynamic>;
      } catch (innerError) {
        SyncLogger.error('PULL', '基础查询也失败了，跳过本批次', innerError);
        return [];
      }
    }
  }

  // =========================================================================
  // 笔记推送
  // =========================================================================

  Future<List<Note>> _pushNotes(List<String> idsToPush, String userId) async {
    // 🌟 配额检查：估算推送大小（避免 O(n) 遍历所有笔记精确计算）
    // 平均每条笔记约 2KB，取保守上限
    const averageNoteSizeBytes = 2048;
    final estimatedBytes = idsToPush.length * averageNoteSizeBytes;

    if (estimatedBytes > 0) {
      final quotaService = StorageQuotaService();
      final quotaCheck = await quotaService.checkStorageQuota(
        requiredBytes: estimatedBytes,
        resourceType: ResourceType.note,
      );

      if (!quotaCheck.canProceed) {
        SyncLogger.warn('QUOTA', '存储配额不足，跳过推送: ${quotaCheck.message}');
        throw SyncException(
          '云端存储空间不足: ${quotaCheck.message}',
          type: SyncErrorType.quotaExceeded,
        );
      }
    }

    List<Map<String, dynamic>> payloads = [];
    List<Note> pushedNotes = [];

    for (var id in idsToPush) {
      final note = _noteRepo!.getNoteById(id);
      if (note != null) {
        // 🌟 隐私笔记加密：在同步前加密 title 和 content
        String titleToSync = note.title;
        String contentToSync = note.content;

        if (note.isPrivate) {
          final privacy = PrivacyService();
          if (privacy.isUnlocked) {
            // 如果隐私空间已解锁，确保内容已加密后再上传
            titleToSync = privacy.encryptText(note.title);
            contentToSync = privacy.encryptText(note.content);
            SyncLogger.info('PUSH', '隐私笔记 [${note.id}] 已加密后上传');
          } else {
            // 如果未解锁，检查内容是否已经是加密格式
            if (!note.title.startsWith('AES_V1::')) {
              SyncLogger.warn('PUSH', '隐私笔记 [${note.id}] 未加密且无法加密，跳过上传');
              continue; // 跳过这条笔记的上传
            }
            // 内容已经是加密的，直接使用
            titleToSync = note.title;
            contentToSync = note.content;
          }
        }

        payloads.add({
          'id': note.id,
          'title': titleToSync,
          'content': contentToSync,
          'created_at': note.createdAt.toUtc().toIso8601String(),
          'updated_at': note.updatedAt.toUtc().toIso8601String(),
          // 确保空分类强转 null，防止外键冲突
          'category_id': (note.categoryId?.trim().isEmpty ?? true) ? null : note.categoryId,
          'version': note.version,
          'is_pinned': note.isPinned,
          'is_deleted': note.isDeleted,
          'is_private': note.isPrivate,
          'user_id': userId,
        });
        pushedNotes.add(note);
      }
    }

    if (payloads.isNotEmpty) {
      try {
        await _retry.withRetry(
          operation: () => _supabase.from('notes').upsert(payloads),
          operationName: '推送笔记到云端',
        );
      } catch (e) {
        // 🌟 降级策略：如果包含 is_private 字段失败，尝试不包含
        SyncLogger.warn('PUSH', '包含 is_private 推送失败，尝试降级推送: $e');
        try {
          final legacyPayloads = payloads.map((p) => {
            'id': p['id'],
            'title': p['title'],
            'content': p['content'],
            'created_at': p['created_at'],
            'updated_at': p['updated_at'],
            'category_id': p['category_id'],
            'version': p['version'],
            'is_pinned': p['is_pinned'],
            'is_deleted': p['is_deleted'],
            'user_id': p['user_id'],
          }).toList();
          await _retry.withRetry(
            operation: () => _supabase.from('notes').upsert(legacyPayloads),
            operationName: '推送笔记到云端(降级)',
          );
          SyncLogger.info('PUSH', '降级推送成功（不含 is_private）');
        } catch (legacyError) {
          SyncLogger.error('PUSH', '笔记主表推送失败（降级也失败），已中止', legacyError);
          return [];
        }
      }

      // 🌟 批量处理标签关系
      if (pushedNotes.isNotEmpty) {
        try {
          // 收集所有需要删除的 note_id
          final noteIds = pushedNotes.map((n) => n.id).toList();

          // 批量删除这些笔记的所有标签关系
          await _retry.withRetry(
            operation: () => _supabase.from('note_tags').delete().inFilter('note_id', noteIds),
            operationName: '批量删除笔记标签关联',
          );

          // 收集所有需要插入的标签关系
          final allTagPayloads = <Map<String, dynamic>>[];
          for (var note in pushedNotes) {
            if (note.tagIds.isNotEmpty) {
              allTagPayloads.addAll(
                note.tagIds.map((tagId) => {'note_id': note.id, 'tag_id': tagId}),
              );
            }
          }

          // 批量插入所有标签关系
          if (allTagPayloads.isNotEmpty) {
            await _retry.withRetry(
              operation: () => _supabase.from('note_tags').insert(allTagPayloads),
              operationName: '批量插入笔记标签关联',
            );
          }

          SyncLogger.info('PUSH', '批量处理 ${allTagPayloads.length} 条标签关系');
        } catch (e) {
          SyncLogger.warn('PUSH', '批量处理标签关系失败: $e');
        }
      }
      SyncLogger.info('PUSH', '✅ 成功推送 ${payloads.length} 条笔记到云端');
    } else {
      SyncLogger.info('PUSH', 'ℹ️ 无笔记需要推送');
    }
    return pushedNotes;
  }

  // =========================================================================
  // 云端元数据获取
  // =========================================================================

  Future<Map<String, CloudNoteMeta>> _fetchCloudMetadataWithVersion(String userId) async {
    try {
      final response = await _retry.withRetry(
        operation: () => _supabase
            .from('notes')
            .select('id, updated_at, version')
            .eq('user_id', userId),
        operationName: '拉取云端版本号',
      );
      final data = response as List<dynamic>;
      SyncLogger.info('META', '从云端获取 ${data.length} 条笔记版本号');
      return {
        for (var item in data)
          item['id'].toString(): CloudNoteMeta(
            updatedAt: DateTime.parse(item['updated_at'].toString()).toLocal(),
            version: (item['version'] as int?) ?? SyncConstants.defaultVersion,
          )
      };
    } catch (e) {
      SyncLogger.error('META', '拉取云端版本号失败', e);
      return {};
    }
  }
}