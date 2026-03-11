
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
      final lastSyncStr = prefs.getString(_lastNoteSyncKey);
      DateTime? lastSyncTime;
      if (lastSyncStr != null) {
        lastSyncTime = DateTime.parse(lastSyncStr);
      }

      List<Note> pulledNotes = [];
      List<Note> pushedNotes = [];

      final currentUserId=_supabase.auth.currentUser!.id;
      final List<dynamic> cloudMetadata = await _supabase.from('notes').select('id, updated_at').eq('user_id', currentUserId);
      final localNotes = _noteRepo!.getAllNotes();
      final localNotesMap = {for (var note in localNotes) note.id: note};

      final List<String> idsToFetch = [];
      final Set<String> pulledIds = {};

      // 🟢 核心修复 1：记录云端目前拥有的所有 ID
      final Set<String> cloudIds = {};

      for (var meta in cloudMetadata) {
        final cloudId = meta['id'] as String;
        final cloudUpdatedAt = DateTime.parse(meta['updated_at']).toLocal();

        cloudIds.add(cloudId); // 记录云端存在的 ID

        final localNote = localNotesMap[cloudId];

        if (localNote == null) {
          idsToFetch.add(cloudId);
          pulledIds.add(cloudId);
        } else {
          if (cloudUpdatedAt.difference(localNote.updatedAt).inSeconds.abs() < 2) {
            continue;
          }

          bool cloudChanged = lastSyncTime != null && cloudUpdatedAt.isAfter(lastSyncTime);
          bool localChanged = lastSyncTime != null && localNote.updatedAt.isAfter(lastSyncTime);

          if (cloudChanged && localChanged) {
            print('⚠️ 侦测到数据冲突！正在生成冲突副本: ${localNote.title}');
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

      // =================================================================
      // PHASE 2: PUSH 本地新数据
      // =================================================================
      List<Map<String, dynamic>> notesToPush = [];

      for (var note in _noteRepo!.getAllNotes()) {
        if (pulledIds.contains(note.id)) continue;

        // 🟢 核心修复 2：如果云端根本没有这个 ID，无视时间戳，直接强制 Push！
        bool isMissingInCloud = !cloudIds.contains(note.id);

        if (isMissingInCloud || lastSyncTime == null || note.updatedAt.isAfter(lastSyncTime)) {
          notesToPush.add(_noteToMap(note));
          pushedNotes.add(note);
        }
      }

      await _uploadImages(pushedNotes);
      if (notesToPush.isNotEmpty) {
        await _supabase.from('notes').upsert(notesToPush);
      }
      if (onTextSyncComplete != null) {
        onTextSyncComplete();
      }
      await _downloadImages(pulledNotes);

      await prefs.setString(_lastNoteSyncKey, DateTime.now().toUtc().toIso8601String());
      print('✅ 笔记同步完成！拉取: $pullCount 条，推送: ${notesToPush.length} 条');

    } catch (e) {
      print('❌ 笔记同步失败: $e');
    }
  }

  Future<void> _uploadImages(List<Note> pushedNotes) async {
    if (pushedNotes.isEmpty) return;
    final storage = _supabase.storage.from(_imageBucket);
    final appDir = await getApplicationDocumentsDirectory();

    Set<String> imagesToUpload = {};
    for (var note in pushedNotes) {
      imagesToUpload.addAll(Note.extractAllImagePaths(note.content));
    }

    List<Future<void>> uploadTasks = imagesToUpload
        .where((path) => !p.isAbsolute(path))
        .map((rawPath) async {
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

    List<Future<void>> downloadTasks = imagesToDownload
        .where((path) => !p.isAbsolute(path))
        .map((rawPath) async {
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
  // ✅ 待办 (Todos) 同步模块
  // =================================================================
  static const String _lastTodoSyncKey = 'last_todo_sync_time';

  Future<void> syncTodos({Function()? onSyncComplete}) async {
    if (_todoRepo == null) return;
    if (_supabase.auth.currentUser == null) {
      print('⚠️ 未登录，暂停待办同步');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncStr = prefs.getString(_lastTodoSyncKey);
      DateTime? lastSyncTime;
      if (lastSyncStr != null) {
        lastSyncTime = DateTime.parse(lastSyncStr);
      }
      final currentUserId = _supabase.auth.currentUser!.id;
      final List<dynamic> cloudMetadata = await _supabase.from('todos').select('id, updated_at').eq('user_id', currentUserId);
      final localTodos = _todoRepo!.getAllTodos();
      final localTodosMap = {for (var todo in localTodos) todo.id: todo};
      final List<String> idsToFetch = [];

      // 🟢 核心修复 3：记录云端待办 ID
      final Set<String> cloudIds = {};

      for (var meta in cloudMetadata) {
        final cloudId = meta['id'] as String;
        final cloudUpdatedAt = DateTime.parse(meta['updated_at']).toLocal();

        cloudIds.add(cloudId); // 记录

        final localTodo = localTodosMap[cloudId];
        if (localTodo == null || cloudUpdatedAt.isAfter(localTodo.updatedAt)) {
          idsToFetch.add(cloudId);
        }
      }

      int pullCount = 0;
      if (idsToFetch.isNotEmpty) {
        for (var i = 0; i < idsToFetch.length; i += 50) {
          final chunk = idsToFetch.sublist(i, i + 50 > idsToFetch.length ? idsToFetch.length : i + 50);
          final List<dynamic> cloudUpdates = await _supabase.from('todos').select().inFilter('id', chunk).eq('user_id', currentUserId);

          for (var data in cloudUpdates) {
            final cloudTodoId = data['id'];
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

      List<Map<String, dynamic>> todosToPush = [];
      for (var todo in _todoRepo!.getAllTodos()) {

        // 🟢 核心修复 4：云端缺失直接强制上传
        bool isMissingInCloud = !cloudIds.contains(todo.id);

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
          });
        }
      }

      if (todosToPush.isNotEmpty) {
        await _supabase.from('todos').upsert(todosToPush);
      }

      await prefs.setString(_lastTodoSyncKey, DateTime.now().toUtc().toIso8601String());
      if (onSyncComplete != null) onSyncComplete();

      print('✅ 待办同步完成！拉取: $pullCount 条，推送: ${todosToPush.length} 条');

    } catch (e) {
      print('❌ 待办同步失败: $e');
    }
  }
}