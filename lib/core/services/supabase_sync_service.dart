// 文件路径: lib/core/services/supabase_sync_service.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/note_repository.dart';
import '../repositories/todo_repository.dart';
import '../../models/note.dart';
import '../../models/todo.dart';
import 'package:uuid/uuid.dart';

class SupabaseSyncService {
  final _supabase = Supabase.instance.client;

  final NoteRepository? _noteRepo;
  final TodoRepository? _todoRepo;

  SupabaseSyncService([this._noteRepo, this._todoRepo]);

  // =================================================================
  // 🪦 墓碑机制：记录被彻底删除的 ID
  // =================================================================
  static const String _deletedTodosKey = 'deleted_todo_ids';
  static const String _deletedNotesKey = 'deleted_note_ids';

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

  // =================================================================
  // ✅ 笔记 (Notes) 同步模块
  // =================================================================
  static const String _lastNoteSyncKey = 'last_sync_time';
  static const String _imageBucket = 'note_images';

  Map<String, dynamic> _noteToMap(Note note) {
    return {
      'id': note.id,
      'title': note.title,
      'content': note.content,
      'created_at': note.createdAt.toUtc().toIso8601String(),
      'updated_at': note.updatedAt.toUtc().toIso8601String(),
      'tags': note.tags,
      'category': note.category,
      'is_pinned': note.isPinned,
      'is_deleted': note.isDeleted,
      'user_id': _supabase.auth.currentUser!.id,
    };
  }

  Note _mapToNote(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      createdAt: DateTime.parse(map['created_at']).toLocal(),
      updatedAt: DateTime.parse(map['updated_at']).toLocal(),
      tags: List<String>.from(map['tags'] ?? []),
      category: map['category'],
      isPinned: map['is_pinned'] ?? false,
      isDeleted: map['is_deleted'] ?? false,
    );
  }

  Future<void> syncNotes({Function()? onTextSyncComplete}) async {
    if (_noteRepo == null) return;
    if (_supabase.auth.currentUser == null) {
      print('⚠️ 未登录，暂停笔记同步');
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. 处理墓碑：优先清理云端
      final deletedIds = prefs.getStringList(_deletedNotesKey) ?? [];
      if (deletedIds.isNotEmpty) {
        try {
          await _supabase.from('notes').delete().inFilter('id', deletedIds);
          await prefs.setStringList(_deletedNotesKey, []);
          print('🗑️ 成功清空云端笔记回收站数据: ${deletedIds.length} 条');
        } catch (e) {
          print('🗑️ ❌ 云端笔记回收站清理失败: $e');
        }
      }

      final lastSyncStr = prefs.getString(_lastNoteSyncKey);
      DateTime? lastSyncTime;
      if (lastSyncStr != null) {
        lastSyncTime = DateTime.parse(lastSyncStr);
      }

      List<Note> pulledNotes = [];
      List<Note> pushedNotes = [];

      final currentUserId = _supabase.auth.currentUser!.id;
      final List<dynamic> cloudMetadata = await _supabase.from('notes').select('id, updated_at').eq('user_id', currentUserId);
      final localNotes = _noteRepo!.getAllNotes();
      final localNotesMap = {for (var note in localNotes) note.id: note};

      final List<String> idsToFetch = [];
      final Set<String> pulledIds = {};
      final Set<String> cloudIds = {};

      // PULL 阶段
      for (var meta in cloudMetadata) {
        final cloudId = meta['id'] as String;
        if (deletedIds.contains(cloudId)) continue;

        final cloudUpdatedAt = DateTime.parse(meta['updated_at']).toLocal();
        cloudIds.add(cloudId);

        final localNote = localNotesMap[cloudId];

        if (localNote == null) {
          idsToFetch.add(cloudId);
          pulledIds.add(cloudId);
        } else {
          if (cloudUpdatedAt.difference(localNote.updatedAt).inSeconds.abs() < 2) continue;

          bool cloudChanged = lastSyncTime != null && cloudUpdatedAt.isAfter(lastSyncTime);
          bool localChanged = lastSyncTime != null && localNote.updatedAt.isAfter(lastSyncTime);

          if (cloudChanged && localChanged) {
            final conflictedNote = localNote.copyWith(
              id: const Uuid().v4(),
              title: '${localNote.title} (冲突副本)',
              updatedAt: DateTime.now(),
            );
            await _noteRepo!.addNote(conflictedNote);
            idsToFetch.add(cloudId);
            pulledIds.add(cloudId);
          } else if (cloudUpdatedAt.isAfter(localNote.updatedAt)) {
            idsToFetch.add(cloudId);
            pulledIds.add(cloudId);
          }
        }
      }

      int pullCount = 0;
      if (idsToFetch.isNotEmpty) {
        for (var i = 0; i < idsToFetch.length; i += 50) {
          final chunk = idsToFetch.sublist(i, i + 50 > idsToFetch.length ? idsToFetch.length : i + 50);
          final List<dynamic> cloudUpdates = await _supabase.from('notes').select().inFilter('id', chunk).eq('user_id', currentUserId);

          for (var cloudData in cloudUpdates) {
            final cloudNoteId = cloudData['id'];
            final updatedNote = _mapToNote(cloudData);

            if (localNotesMap.containsKey(cloudNoteId)) {
              await _noteRepo!.updateNote(updatedNote);
            } else {
              await _noteRepo!.addNote(updatedNote);
            }
            pulledNotes.add(updatedNote);
            pullCount++;
          }
        }
      }

      // 🟢 PUSH 阶段 & 幽灵数据抹除
      List<Map<String, dynamic>> notesToPush = [];
      List<String> notesToDeleteLocally = [];

      for (var note in _noteRepo!.getAllNotes()) {
        if (pulledIds.contains(note.id)) continue;

        bool isMissingInCloud = !cloudIds.contains(note.id);

        // 👻 终极幽灵防御机制
        if (isMissingInCloud && lastSyncTime != null && !note.updatedAt.isAfter(lastSyncTime)) {
          // 这个数据以前同步过，但现在云端没了，且本地没修改过 -> 另一台设备把它彻底删除了！本地也必须抹除。
          notesToDeleteLocally.add(note.id);
          continue;
        }

        if (isMissingInCloud || lastSyncTime == null || note.updatedAt.isAfter(lastSyncTime)) {
          notesToPush.add(_noteToMap(note));
          pushedNotes.add(note);
        }
      }

      // 执行本地物理删除
      for (var id in notesToDeleteLocally) {
        await _noteRepo!.deleteNote(id);
      }

      await _uploadImages(pushedNotes);
      if (notesToPush.isNotEmpty) {
        await _supabase.from('notes').upsert(notesToPush);
      }
      if (onTextSyncComplete != null) {
        onTextSyncComplete(); // 这里会刷新 UI，刚才被抹除的幽灵数据会从列表中消失
      }
      await _downloadImages(pulledNotes);

      await prefs.setString(_lastNoteSyncKey, DateTime.now().toUtc().toIso8601String());
      print('✅ 笔记同步完成！拉取: $pullCount 条，推送: ${notesToPush.length} 条，抹除本地幽灵: ${notesToDeleteLocally.length} 条');

    } catch (e) {
      print('❌ 笔记同步失败: $e');
    }
  }

  // ------------------------- 图片处理逻辑不变 -------------------------
  Future<void> _uploadImages(List<Note> pushedNotes) async {
    if (pushedNotes.isEmpty) return;
    final storage = _supabase.storage.from(_imageBucket);
    final appDir = await getApplicationDocumentsDirectory();

    Set<String> imagesToUpload = {};
    for (var note in pushedNotes) {
      imagesToUpload.addAll(Note.extractAllImagePaths(note.content));
    }

    List<Future<void>> uploadTasks = imagesToUpload.where((path) => !p.isAbsolute(path)).map((rawPath) async {
      try {
        final normalizedPath = rawPath.replaceAll('\\', '/');
        final fileName = normalizedPath.split('/').last;
        final localFile = File(p.join(appDir.path, 'note_images', fileName));

        if (await localFile.exists()) {
          await storage.upload(fileName, localFile, fileOptions: const FileOptions(upsert: true));
        }
      } catch (e) {
        print('🖼️ ❌ 上传图片失败 $rawPath: $e');
      }
    }).toList();

    await Future.wait(uploadTasks);
  }

  Future<void> _downloadImages(List<Note> pulledNotes) async {
    if (pulledNotes.isEmpty) return;
    final storage = _supabase.storage.from(_imageBucket);
    final appDir = await getApplicationDocumentsDirectory();

    Set<String> imagesToDownload = {};
    for (var note in pulledNotes) {
      imagesToDownload.addAll(Note.extractAllImagePaths(note.content));
    }

    List<Future<void>> downloadTasks = imagesToDownload.where((path) => !p.isAbsolute(path)).map((rawPath) async {
      try {
        final normalizedPath = rawPath.replaceAll('\\', '/');
        final fileName = normalizedPath.split('/').last;
        final localFile = File(p.join(appDir.path, 'note_images', fileName));

        if (!await localFile.exists()) {
          final bytes = await storage.download(fileName);
          await localFile.parent.create(recursive: true);
          await localFile.writeAsBytes(bytes);
        }
      } catch (e) {
        print('🖼️ ❌ 下载图片失败 $rawPath: $e');
      }
    }).toList();

    await Future.wait(downloadTasks);
  }

  // =================================================================
  // ✅ 待办 (Todos) 同步模块 (同款幽灵防御升级)
  // =================================================================
  static const String _lastTodoSyncKey = 'last_todo_sync_time';

  Future<void> syncTodos({Function()? onSyncComplete}) async {
    if (_todoRepo == null) return;
    if (_supabase.auth.currentUser == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. 处理墓碑
      final deletedIds = prefs.getStringList(_deletedTodosKey) ?? [];
      if (deletedIds.isNotEmpty) {
        try {
          await _supabase.from('todos').delete().inFilter('id', deletedIds);
          await prefs.setStringList(_deletedTodosKey, []);
          print('🗑️ 成功清空云端回收站待办: ${deletedIds.length} 条');
        } catch (e) {
          print('🗑️ ❌ 云端回收站待办清理失败: $e');
        }
      }

      final lastSyncStr = prefs.getString(_lastTodoSyncKey);
      DateTime? lastSyncTime;
      if (lastSyncStr != null) lastSyncTime = DateTime.parse(lastSyncStr);

      final currentUserId = _supabase.auth.currentUser!.id;
      final List<dynamic> cloudMetadata = await _supabase.from('todos').select('id, updated_at').eq('user_id', currentUserId);
      final localTodos = _todoRepo!.getAllTodos();
      final localTodosMap = {for (var todo in localTodos) todo.id: todo};
      final List<String> idsToFetch = [];
      final Set<String> pulledIds = {}; // 🟢 记录被拉取的 ID
      final Set<String> cloudIds = {};

      for (var meta in cloudMetadata) {
        final cloudId = meta['id'] as String;
        if (deletedIds.contains(cloudId)) continue;

        final cloudUpdatedAt = DateTime.parse(meta['updated_at']).toLocal();
        cloudIds.add(cloudId);

        final localTodo = localTodosMap[cloudId];
        if (localTodo == null || cloudUpdatedAt.isAfter(localTodo.updatedAt)) {
          idsToFetch.add(cloudId);
          pulledIds.add(cloudId); // 加入拉取名单，防止等下直接又给推回去了
        }
      }

      int pullCount = 0;
      if (idsToFetch.isNotEmpty) {
        for (var i = 0; i < idsToFetch.length; i += 50) {
          final chunk = idsToFetch.sublist(i, i + 50 > idsToFetch.length ? idsToFetch.length : i + 50);
          final List<dynamic> cloudUpdates = await _supabase.from('todos').select().inFilter('id', chunk).eq('user_id', currentUserId);

          for (var data in cloudUpdates) {
            final cloudTodoId = data['id'];

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
              subTasks: parsedSubTasks,
            );

            if (localTodosMap.containsKey(cloudTodoId)) {
              await _todoRepo!.updateTodo(updatedTodo);
            } else {
              await _todoRepo!.addTodo(updatedTodo);
            }
            pullCount++;
          }
        }
      }

      // 🟢 PUSH 阶段 & 幽灵待办抹除
      List<Map<String, dynamic>> todosToPush = [];
      List<String> todosToDeleteLocally = [];

      for (var todo in _todoRepo!.getAllTodos()) {
        if (pulledIds.contains(todo.id)) continue;

        bool isMissingInCloud = !cloudIds.contains(todo.id);

        // 👻 防御幽灵数据
        if (isMissingInCloud && lastSyncTime != null && !todo.updatedAt.isAfter(lastSyncTime)) {
          todosToDeleteLocally.add(todo.id);
          continue;
        }

        if (isMissingInCloud || lastSyncTime == null || todo.updatedAt.isAfter(lastSyncTime)) {
          todosToPush.add({
            'id': todo.id,
            'title': todo.title,
            'description': todo.description,
            'created_at': todo.createdAt.toUtc().toIso8601String(),
            'updated_at': todo.updatedAt.toUtc().toIso8601String(),
            'due_date': todo.dueDate?.toUtc().toIso8601String(),
            'is_completed': todo.isCompleted,
            'is_deleted': todo.isDeleted,
            'sort_order': todo.sortOrder,
            'user_id': _supabase.auth.currentUser!.id,
            'sub_tasks': todo.subTasks.map((st) => st.toMap()).toList(),
          });
        }
      }

      // 物理删除本地幽灵
      for (var id in todosToDeleteLocally) {
        await _todoRepo!.deleteTodo(id);
      }

      if (todosToPush.isNotEmpty) {
        await _supabase.from('todos').upsert(todosToPush);
      }

      await prefs.setString(_lastTodoSyncKey, DateTime.now().toUtc().toIso8601String());
      if (onSyncComplete != null) onSyncComplete();

      print('✅ 待办同步完成！拉取: $pullCount 条，推送: ${todosToPush.length} 条，抹除本地幽灵: ${todosToDeleteLocally.length} 条');

    } catch (e) {
      print('❌ 待办同步失败: $e');
    }
  }
}