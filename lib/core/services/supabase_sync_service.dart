import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' hide Category;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../repositories/category_repository.dart';
import '../repositories/note_repository.dart';
import '../repositories/tag_repository.dart';
import '../repositories/todo_repository.dart';

import '../../models/note.dart';
import '../../models/todo.dart';
import '../../models/category.dart';
import '../../models/tag.dart';

class _SyncLogger {
  static void info(String module, String msg) {
    if (kDebugMode) {
      final time = DateTime.now().toIso8601String().split('T')[1].substring(0, 12);
      print('[$time] 🟢 [SYNC-$module] $msg');
    }
  }

  static void warn(String module, String msg) {
    if (kDebugMode) {
      final time = DateTime.now().toIso8601String().split('T')[1].substring(0, 12);
      print('[$time] ⚠️ [SYNC-$module] $msg');
    }
  }

  static void error(String module, String msg, [dynamic error]) {
    if (kDebugMode) {
      final time = DateTime.now().toIso8601String().split('T')[1].substring(0, 12);
      print('[$time] ❌ [SYNC-$module] $msg ${error != null ? '-> $error' : ''}');
    }
  }
}

class SupabaseSyncService {
  final _supabase = Supabase.instance.client;
  final NoteRepository? _noteRepo;
  final TodoRepository? _todoRepo;
  final CategoryRepository? _categoryRepo;
  final TagRepository? _tagRepo;

  SupabaseSyncService([this._noteRepo, this._todoRepo, this._categoryRepo, this._tagRepo]);

  static const String _deletedTodosKey = 'deleted_todo_ids';
  static const String _deletedNotesKey = 'deleted_note_ids';
  static const String _deletedCategoriesKey = 'deleted_categories';
  static const String _lastNoteSyncKey = 'last_sync_time';
  static const String _lastTodoSyncKey = 'last_todo_sync_time';
  static const String _imageBucket = 'note_images';

  static const Duration _timeBuffer = Duration(seconds: 2);

  // =========================================================================
  // 🌟 1. 本地废纸篓记录
  // =========================================================================
  Future<void> recordDeletedTodoId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final deletedIds = prefs.getStringList(_deletedTodosKey) ?? [];
    if (!deletedIds.contains(id)) {
      deletedIds.add(id);
      await prefs.setStringList(_deletedTodosKey, deletedIds);
    }
  }

  Future<void> recordDeletedNoteId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final deletedIds = prefs.getStringList(_deletedNotesKey) ?? [];
    if (!deletedIds.contains(id)) {
      deletedIds.add(id);
      await prefs.setStringList(_deletedNotesKey, deletedIds);
    }
  }

  Future<void> recordDeletedCategory(String categoryId) async {
    final prefs = await SharedPreferences.getInstance();
    final deletedCats = prefs.getStringList(_deletedCategoriesKey) ?? [];
    if (!deletedCats.contains(categoryId)) {
      deletedCats.add(categoryId);
      await prefs.setStringList(_deletedCategoriesKey, deletedCats);
    }
  }

  // =========================================================================
  // 🌟 2. 笔记同步全链路
  // =========================================================================
  Future<void> syncNotes({Function()? onTextSyncComplete}) async {
    if (_noteRepo == null) return;
    if (_supabase.auth.currentUser == null) return;

    _SyncLogger.info('NOTE', '====== 🚀 启动 V3.1 笔记防御性同步管线 ======');
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = _supabase.auth.currentUser!.id;

      await _syncCategoriesAndTags(currentUserId, prefs);
      await _processLocalDeletions(prefs, 'notes', _deletedNotesKey);

      final lastSyncStr = prefs.getString(_lastNoteSyncKey);
      final lastSyncTime = lastSyncStr != null ? DateTime.parse(lastSyncStr) : null;

      final cloudMetadata = await _fetchCloudMetadata('notes', currentUserId);
      final allLocalNotes = _noteRepo.getAllNotes();
      final localMetaMap = {for (var n in allLocalNotes) n.id: {'updated_at': n.updatedAt, 'version': n.version}};

      final plan = _reconcileDataWithVersion(
        localMetaMap: localMetaMap,
        cloudMetadata: cloudMetadata,
        lastSyncTime: lastSyncTime,
      );

      if (plan.toPull.isNotEmpty) {
      }

      List<Note> pushedNotes = [];
      if (plan.toPush.isNotEmpty) {
        pushedNotes = await _pushNotes(plan.toPush, currentUserId);
      }

      for (var id in plan.toDeleteLocally) {
        await _noteRepo.deleteNote(id);
      }

      await prefs.setString(_lastNoteSyncKey, DateTime.now().toUtc().toIso8601String());
      if (onTextSyncComplete != null) onTextSyncComplete();

      try {
        final allNotesAfterSync = _noteRepo.getAllNotes();
        if (pushedNotes.isNotEmpty) await _uploadImages(pushedNotes,currentUserId);
        await _downloadImages(allNotesAfterSync);
        await _cleanUpCloudImages();
      } catch (e) {
        _SyncLogger.error('IMAGE', '图片管线异常', e);
      }

      _SyncLogger.info('NOTE', '====== ✅ 笔记同步管线完美收官 ======');
    } catch (e) {
      _SyncLogger.error('NOTE', '同步管线崩溃', e);
    }
  }

  _SyncPlan _reconcileDataWithVersion({
    required Map<String, Map<String, dynamic>> localMetaMap,
    required Map<String, Map<String, dynamic>> cloudMetadata,
    required DateTime? lastSyncTime,
  }) {
    final toPull = <String>[];
    final toPush = <String>[];
    final toDeleteLocally = <String>[];

    for (var cloudMeta in cloudMetadata.entries) {
      final cloudId = cloudMeta.key;
      final cloudTime = cloudMeta.value['updated_at'] as DateTime;
      final cloudVersion = cloudMeta.value['version'] as int;

      final localData = localMetaMap[cloudId];

      if (localData == null) {
        toPull.add(cloudId);
      } else {
        final localTime = localData['updated_at'] as DateTime;
        final localVersion = localData['version'] as int;

        if (cloudVersion > localVersion) {
          toPull.add(cloudId);
        } else if (localVersion > cloudVersion) {
          toPush.add(cloudId);
        } else {
          if (cloudTime.difference(localTime).inSeconds.abs() > _timeBuffer.inSeconds) {
            if (cloudTime.isAfter(localTime)) {
              toPull.add(cloudId);
            } else {
              toPush.add(cloudId);
            }
          }
        }
      }
    }

    for (var localMeta in localMetaMap.entries) {
      final localId = localMeta.key;
      final localTime = localMeta.value['updated_at'] as DateTime;

      if (!cloudMetadata.containsKey(localId)) {
        if (lastSyncTime == null) {
          toPush.add(localId);
        } else {
          if (localTime.isAfter(lastSyncTime.add(_timeBuffer))) {
            toPush.add(localId);
          } else {
            toDeleteLocally.add(localId);
          }
        }
      }
    }

    return _SyncPlan(toPull: toPull, toPush: toPush, toDeleteLocally: toDeleteLocally);
  }

  Future<Map<String, Map<String, dynamic>>> _fetchCloudMetadata(String table, String userId) async {
    try {
      final response = await _supabase.from(table).select('id, updated_at, version').eq('user_id', userId).timeout(const Duration(seconds: 15));
      return {
        for (var item in response) item['id'] as String: {
          'updated_at': DateTime.parse(item['updated_at']).toLocal(),
          'version': (item['version'] as int?) ?? 1,
        }
      };
    } catch (e) {
      _SyncLogger.error('META', '拉取 [$table] 元数据失败', e);
      return {};
    }
  }

  // =========================================================================
  // 🌟 核心防御降级：_pullNotes
  // =========================================================================
  Future<List<Note>> _pullNotes(List<String> idsToFetch, String userId, Set<String> existingLocalIds) async {
    List<Note> pulled = [];
    for (var i = 0; i < idsToFetch.length; i += 50) {
      final chunk = idsToFetch.sublist(i, i + 50 > idsToFetch.length ? idsToFetch.length : i + 50);

      List<dynamic> cloudUpdates = [];
      try {
        // 尝试高级关联查询
        cloudUpdates = await _supabase.from('notes')
            .select('*, note_tags(tag_id)')
            .inFilter('id', chunk)
            .eq('user_id', userId)
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        _SyncLogger.warn('PULL', '高级关联查询失败，退回安全模式 (请检查 note_tags 外键约束): $e');
        // 防御降级：如果不识别关联表，仅拉取基础表！
        cloudUpdates = await _supabase.from('notes')
            .select()
            .inFilter('id', chunk)
            .eq('user_id', userId)
            .timeout(const Duration(seconds: 15));
      }

      for (var map in cloudUpdates) {
        final tagIds = (map['note_tags'] as List<dynamic>?)?.map((t) => t['tag_id'] as String).toList() ?? [];

        final updatedNote = Note(
          id: map['id'],
          title: map['title'] ?? '',
          content: map['content'] ?? '',
          createdAt: DateTime.parse(map['created_at']).toLocal(),
          updatedAt: DateTime.parse(map['updated_at']).toLocal(),
          categoryId: map['category_id'],
          tagIds: tagIds,
          version: map['version'] ?? 1,
          isPinned: map['is_pinned'] ?? false,
          isDeleted: map['is_deleted'] ?? false,
        );

        if (existingLocalIds.contains(updatedNote.id)) {
          await _noteRepo!.updateNote(updatedNote);
        } else {
          await _noteRepo!.addNote(updatedNote);
        }
        pulled.add(updatedNote);
      }
    }
    _SyncLogger.info('PULL', '成功拉取 ${pulled.length} 条笔记');
    return pulled;
  }

  // =========================================================================
  // 🌟 核心防御降级：_pushNotes
  // =========================================================================
  Future<List<Note>> _pushNotes(List<String> idsToPush, String userId) async {
    List<Map<String, dynamic>> payloads = [];
    List<Note> pushedNotes = [];

    for (var id in idsToPush) {
      final note = _noteRepo!.getNoteById(id);
      if (note != null) {
        payloads.add({
          'id': note.id,
          'title': note.title,
          'content': note.content,
          'created_at': note.createdAt.toUtc().toIso8601String(),
          'updated_at': note.updatedAt.toUtc().toIso8601String(),
          // 确保空白字符串转换为 null，防止外键报错
          'category_id': (note.categoryId?.trim().isEmpty ?? true) ? null : note.categoryId,
          'version': note.version,
          'is_pinned': note.isPinned,
          'is_deleted': note.isDeleted,
          'user_id': userId,
        });
        pushedNotes.add(note);
      }
    }

    if (payloads.isNotEmpty) {
      // 1. 核心笔记主表推送（绝不让后续逻辑影响它！）
      try {
        await _supabase.from('notes').upsert(payloads).timeout(const Duration(seconds: 15));
        _SyncLogger.info('PUSH', '成功推送 ${payloads.length} 条笔记主表');
      } catch (e) {
        _SyncLogger.error('PUSH', '笔记主表推送致命错误！', e);
        return []; // 主表失败直接返回
      }

      // 2. 标签关联表独立容错推送
      for (var note in pushedNotes) {
        try {
          await _supabase.from('note_tags').delete().eq('note_id', note.id);

          final validTags = note.tagIds.where((id) => id.trim().isNotEmpty).toSet().toList();
          if (validTags.isNotEmpty) {
            final tagPayloads = validTags.map((tagId) => {'note_id': note.id, 'tag_id': tagId}).toList();
            await _supabase.from('note_tags').insert(tagPayloads);
          }
        } catch (e) {
          // 仅警告，绝不向上抛出异常！
          _SyncLogger.warn('PUSH', '标签关系写入失败，请检查 note_tags 表的 RLS 权限: $e');
        }
      }
    }
    return pushedNotes;
  }

  // =========================================================================
  // 🌟 3. 待办同步
  // =========================================================================
  Future<void> syncTodos({Function()? onSyncComplete}) async {
    if (_todoRepo == null || _supabase.auth.currentUser == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = _supabase.auth.currentUser!.id;

      await _processLocalDeletions(prefs, 'todos', _deletedTodosKey);

      final lastSyncStr = prefs.getString(_lastTodoSyncKey);
      final lastSyncTime = lastSyncStr != null ? DateTime.parse(lastSyncStr) : null;

      final cloudMetadata = await _fetchCloudMetadata('todos', currentUserId);
      final allLocalTodos = _todoRepo.getAllTodos();
      final localMetaMap = {for (var t in allLocalTodos) t.id: {'updated_at': t.updatedAt, 'version': t.version}};

      final plan = _reconcileDataWithVersion(
        localMetaMap: localMetaMap,
        cloudMetadata: cloudMetadata,
        lastSyncTime: lastSyncTime,
      );

      if (plan.toPull.isNotEmpty) await _pullTodos(plan.toPull, currentUserId, localMetaMap.keys.toSet());
      if (plan.toPush.isNotEmpty) await _pushTodos(plan.toPush, currentUserId);

      for (var id in plan.toDeleteLocally) {
        await _todoRepo.deleteTodo(id);
      }

      await prefs.setString(_lastTodoSyncKey, DateTime.now().toUtc().toIso8601String());
      if (onSyncComplete != null) onSyncComplete();
    } catch (e) {
      _SyncLogger.error('TODO', '同步管线崩溃', e);
    }
  }

  Future<void> _pullTodos(List<String> idsToFetch, String userId, Set<String> existingLocalIds) async {
    int pullCount = 0;
    for (var i = 0; i < idsToFetch.length; i += 50) {
      final chunk = idsToFetch.sublist(i, i + 50 > idsToFetch.length ? idsToFetch.length : i + 50);
      final List<dynamic> cloudUpdates = await _supabase.from('todos').select().inFilter('id', chunk).eq('user_id', userId);

      for (var data in cloudUpdates) {
        List<SubTask> parsedSubTasks = [];
        if (data['sub_tasks'] != null) {
          final List<dynamic> stList = data['sub_tasks'] as List<dynamic>;
          parsedSubTasks = stList.map((e) => SubTask.fromMap(e as Map<String, dynamic>)).toList();
        }

        final updatedTodo = Todo(
          id: data['id'],
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          createdAt: DateTime.parse(data['created_at']).toLocal(),
          updatedAt: DateTime.parse(data['updated_at']).toLocal(),
          dueDate: data['due_date'] != null ? DateTime.parse(data['due_date']).toLocal() : null,
          isCompleted: data['is_completed'] ?? false,
          isDeleted: data['is_deleted'] ?? false,
          sortOrder: (data['sort_order'] as num?)?.toDouble() ?? 0.0,
          categoryId: data['category_id'],
          version: data['version'] ?? 1,
          subTasks: parsedSubTasks,
        );

        if (existingLocalIds.contains(updatedTodo.id)) {
          await _todoRepo!.updateTodo(updatedTodo);
        } else {
          await _todoRepo!.addTodo(updatedTodo);
        }
        pullCount++;
      }
    }
    _SyncLogger.info('PULL', '成功拉取 $pullCount 条 Todo');
  }

  Future<void> _pushTodos(List<String> idsToPush, String userId) async {
    List<Map<String, dynamic>> payloads = [];
    for (var id in idsToPush) {
      final fullTodo = _todoRepo!.getTodoById(id);
      if (fullTodo != null) {
        payloads.add({
          'id': fullTodo.id,
          'title': fullTodo.title,
          'description': fullTodo.description,
          'created_at': fullTodo.createdAt.toUtc().toIso8601String(),
          'updated_at': fullTodo.updatedAt.toUtc().toIso8601String(),
          'due_date': fullTodo.dueDate?.toUtc().toIso8601String(),
          'is_completed': fullTodo.isCompleted,
          'is_deleted': fullTodo.isDeleted,
          'sort_order': fullTodo.sortOrder,
          'category_id': (fullTodo.categoryId?.trim().isEmpty ?? true) ? null : fullTodo.categoryId,
          'version': fullTodo.version,
          'user_id': userId,
          'sub_tasks': fullTodo.subTasks.map((st) => st.toMap()).toList(),
        });
      }
    }
    if (payloads.isNotEmpty) {
      await _supabase.from('todos').upsert(payloads).timeout(const Duration(seconds: 15));
      _SyncLogger.info('PUSH', '成功推送 ${payloads.length} 条 Todo');
    }
  }

  // =========================================================================
  // 基础字典同步与图片管线
  // =========================================================================
  Future<void> _syncCategoriesAndTags(String userId, SharedPreferences prefs) async {
    if (_categoryRepo == null || _tagRepo == null) return;

    final deletedCats = prefs.getStringList(_deletedCategoriesKey) ?? [];
    if (deletedCats.isNotEmpty) {
      await _supabase.from('categories').delete().inFilter('id', deletedCats);
      await prefs.setStringList(_deletedCategoriesKey, []);
    }

    final localCats = _categoryRepo.getAllCategories();
    final cloudCatsData = await _supabase.from('categories').select().eq('user_id', userId);
    final localCatsMap = { for (var c in localCats) c.id: c };
    final catsToPush = <Map<String, dynamic>>[];

    Map<String, dynamic> catToPayload(Category c) => {
      'id': c.id, 'user_id': userId, 'name': c.name, 'color': c.color, 'icon': c.icon,
      'sort_order': c.sortOrder, 'is_deleted': c.isDeleted,
      'created_at': c.createdAt.toUtc().toIso8601String(), 'updated_at': c.updatedAt.toUtc().toIso8601String(),
    };

    for (var localCat in localCats) {
      final cloudData = cloudCatsData.firstWhere((element) => element['id'] == localCat.id, orElse: () => {});
      if (cloudData.isEmpty) {
        catsToPush.add(catToPayload(localCat));
      } else {
        final cloudTime = DateTime.parse(cloudData['updated_at'] ?? DateTime.now().toIso8601String()).toLocal();
        if (localCat.updatedAt.difference(cloudTime).inSeconds > 2) catsToPush.add(catToPayload(localCat));
      }
    }

    for (var cloudData in cloudCatsData) {
      final cloudId = cloudData['id'] as String;
      final localCat = localCatsMap[cloudId];
      final cloudTime = DateTime.parse(cloudData['updated_at'] ?? DateTime.now().toIso8601String()).toLocal();
      final cloudCatModel = Category(
        id: cloudId, name: cloudData['name'], color: cloudData['color'], icon: cloudData['icon'],
        sortOrder: (cloudData['sort_order'] as num?)?.toDouble() ?? 0.0, isDeleted: cloudData['is_deleted'] ?? false,
        createdAt: DateTime.parse(cloudData['created_at'] ?? DateTime.now().toIso8601String()).toLocal(), updatedAt: cloudTime,
      );

      if (localCat == null) {
        await _categoryRepo.addCategory(cloudCatModel);
      } else if (cloudTime.difference(localCat.updatedAt).inSeconds > 2) {
        await _categoryRepo.updateCategory(cloudCatModel);
      }
    }
    if (catsToPush.isNotEmpty) await _supabase.from('categories').upsert(catsToPush);

    final localTags = _tagRepo.getAllTags();
    final cloudTagsData = await _supabase.from('tags').select().eq('user_id', userId);
    final cloudTagsMap = { for (var map in cloudTagsData) map['id'] as String: map };
    final tagsToPush = <Map<String, dynamic>>[];

    for (var localTag in localTags) {
      if (!cloudTagsMap.containsKey(localTag.id)) {
        tagsToPush.add({
          'id': localTag.id, 'user_id': userId, 'name': localTag.name, 'color': localTag.color,
          'is_deleted': localTag.isDeleted, 'created_at': localTag.createdAt.toUtc().toIso8601String(),
        });
      }
    }

    for (var cloudData in cloudTagsData) {
      final cloudId = cloudData['id'] as String;
      if (!localTags.any((t) => t.id == cloudId)) {
        await _tagRepo.addTag(Tag(
          id: cloudId, name: cloudData['name'], color: cloudData['color'],
          isDeleted: cloudData['is_deleted'] ?? false,
          createdAt: DateTime.parse(cloudData['created_at'] ?? DateTime.now().toIso8601String()).toLocal(),
        ));
      }
    }
    if (tagsToPush.isNotEmpty) await _supabase.from('tags').upsert(tagsToPush);
  }

  Future<void> _processLocalDeletions(SharedPreferences prefs, String table, String key) async {
    final deletedIds = prefs.getStringList(key) ?? [];
    if (deletedIds.isEmpty) return;
    try {
      await _supabase.from(table).delete().inFilter('id', deletedIds).timeout(const Duration(seconds: 15));
      await prefs.setStringList(key, []);
    } catch (e) {
      _SyncLogger.error('TRASH', '清理废纸篓失败', e);
    }
  }

  Future<void> _uploadImages(List<Note> pushedNotes, String userId) async {
    final storage = _supabase.storage.from(_imageBucket);
    final appDir = await getApplicationDocumentsDirectory();

    for (var note in pushedNotes) {
      final paths = Note.extractAllImagePaths(note.content);

      // 如果笔记里没有图片了，直接清空该笔记在 attachments 表里的记录
      if (paths.isEmpty) {
        try {
          await _supabase.from('attachments').delete().eq('note_id', note.id);
        } catch (_) {}
        continue;
      }

      List<Map<String, dynamic>> attachmentPayloads = [];

      for (var path in paths) {
        final fileName = path.replaceAll('\\', '/').split('/').last;
        final localFile = File(p.join(appDir.path, 'note_images', fileName));

        if (await localFile.exists()) {
          try {
            // 1. 上传物理文件到 Storage 桶
            await storage.upload(fileName, localFile, fileOptions: const FileOptions(upsert: true));

            // 2. 收集物理文件元数据
            final size = await localFile.length();
            final ext = p.extension(fileName).replaceAll('.', ''); // 获取无点后缀，如 png

            // 3. 准备写入 attachments 表的 Payload
            attachmentPayloads.add({
              'note_id': note.id,
              'user_id': userId,
              'file_path': fileName,
              'file_size': size,
              'file_type': ext,
            });
          } catch (e) {
            _SyncLogger.warn('IMAGE', '图片 $fileName 上传跳过: $e');
          }
        }
      }

      try {
        await _supabase.from('attachments').delete().eq('note_id', note.id);
        if (attachmentPayloads.isNotEmpty) {
          await _supabase.from('attachments').insert(attachmentPayloads);
        }
      } catch (e) {
        _SyncLogger.warn('IMAGE', 'Attachments 记录写入失败，请检查 RLS 权限: $e');
      }
    }
  }

  Future<void> _downloadImages(List<Note> allNotes) async {
    final storage = _supabase.storage.from(_imageBucket);
    final appDir = await getApplicationDocumentsDirectory();
    Set<String> fileNames = {};
    for (var note in allNotes) {
      if (note.isDeleted) continue;
      for(var path in Note.extractAllImagePaths(note.content)) {
        fileNames.add(path.replaceAll('\\', '/').split('/').last);
      }
    }
    if (fileNames.isEmpty) return;

    final fileList = fileNames.toList();
    for (int i = 0; i < fileList.length; i += 5) {
      final chunk = fileList.sublist(i, i + 5 < fileList.length ? i + 5 : fileList.length);
      await Future.wait(chunk.map((fileName) async {
        try {
          final localFile = File(p.join(appDir.path, 'note_images', fileName));
          if (!await localFile.exists()) {
            final bytes = await storage.download(fileName);
            await localFile.parent.create(recursive: true);
            await localFile.writeAsBytes(bytes);
          }
        } catch (e) {}
      }));
    }
  }


  Future<void> _cleanUpCloudImages() async {
    try {
      await _supabase.from('attachments').delete().isFilter('note_id', null);
      final validAttachments = await _supabase.from('attachments').select('file_path');
      final validFileNames = validAttachments.map((a) => a['file_path'] as String).toSet();
      final storage = _supabase.storage.from(_imageBucket);
      final cloudFiles = await storage.list(searchOptions: const SearchOptions(limit: 5000));

      final orphanedFiles = cloudFiles
          .where((f) => f.name != '.emptyFolderPlaceholder' && !f.name.startsWith('.') && !validFileNames.contains(f.name))
          .map((f) => f.name)
          .toList();
      if (orphanedFiles.isNotEmpty) {
        await storage.remove(orphanedFiles);
        _SyncLogger.info('CLOUD-GC', '🧹 极速空间清理：优雅回收云端僵尸图片 ${orphanedFiles.length} 张');
      }
    } catch (e) {
      _SyncLogger.warn('CLOUD-GC', '云端图片对账与回收失败: $e');
    }
  }
}

class _SyncPlan {
  final List<String> toPull;
  final List<String> toPush;
  final List<String> toDeleteLocally;
  _SyncPlan({required this.toPull, required this.toPush, required this.toDeleteLocally});
}