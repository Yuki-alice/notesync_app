import 'dart:io';
import 'package:flutter/foundation.dart';
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
      if (kDebugMode) {
        print('⚠️ 未登录，暂停笔记同步');
      }
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();

      final deletedIds = prefs.getStringList(_deletedNotesKey) ?? [];
      if (deletedIds.isNotEmpty) {
        try {
          await _supabase.from('notes').delete().inFilter('id', deletedIds);
          await prefs.setStringList(_deletedNotesKey, []);
          if (kDebugMode) {
            print('🗑️ 成功清空云端笔记回收站数据: ${deletedIds.length} 条');
          }
        } catch (e) {
          if (kDebugMode) {
            print('🗑️ ❌ 云端笔记回收站清理失败: $e');
          }
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

      final localMetaMap = _noteRepo.getAllNotesMetadata();

      final List<String> idsToFetch = [];
      final Set<String> pulledIds = {};
      final Set<String> cloudIds = {};

      for (var meta in cloudMetadata) {
        final cloudId = meta['id'] as String;
        if (deletedIds.contains(cloudId)) continue;

        final cloudUpdatedAt = DateTime.parse(meta['updated_at']).toLocal();
        cloudIds.add(cloudId);

        final localUpdatedAt = localMetaMap[cloudId];

        if (localUpdatedAt == null) {
          idsToFetch.add(cloudId);
          pulledIds.add(cloudId);
        } else {
          if (cloudUpdatedAt.difference(localUpdatedAt).inSeconds.abs() < 2) continue;

          bool cloudChanged = lastSyncTime != null && cloudUpdatedAt.isAfter(lastSyncTime);
          bool localChanged = lastSyncTime != null && localUpdatedAt.isAfter(lastSyncTime);

          if (cloudChanged && localChanged) {
            final localNote = _noteRepo.getNoteById(cloudId);
            if (localNote != null) {
              final conflictedNote = localNote.copyWith(
                id: const Uuid().v4(),
                title: '${localNote.title} (冲突副本)',
                updatedAt: DateTime.now(),
              );
              await _noteRepo.addNote(conflictedNote);
            }
            idsToFetch.add(cloudId);
            pulledIds.add(cloudId);
          } else if (cloudUpdatedAt.isAfter(localUpdatedAt)) {
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

            if (localMetaMap.containsKey(cloudNoteId)) {
              await _noteRepo.updateNote(updatedNote);
            } else {
              await _noteRepo.addNote(updatedNote);
            }
            pulledNotes.add(updatedNote);
            pullCount++;
          }
        }
      }

      List<Map<String, dynamic>> notesToPush = [];
      List<String> notesToDeleteLocally = [];

      for (var noteId in localMetaMap.keys) {
        if (pulledIds.contains(noteId)) continue;

        final localUpdatedAt = localMetaMap[noteId]!;
        bool isMissingInCloud = !cloudIds.contains(noteId);

        if (isMissingInCloud && lastSyncTime != null && !localUpdatedAt.isAfter(lastSyncTime)) {
          notesToDeleteLocally.add(noteId);
          continue;
        }

        if (isMissingInCloud || lastSyncTime == null || localUpdatedAt.isAfter(lastSyncTime)) {
          final fullNote = _noteRepo.getNoteById(noteId);
          if (fullNote != null) {
            notesToPush.add(_noteToMap(fullNote));
            pushedNotes.add(fullNote);
          }
        }
      }

      for (var id in notesToDeleteLocally) {
        await _noteRepo.deleteNote(id);
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
      if (kDebugMode) {
        print('✅ 笔记同步完成！拉取: $pullCount 条，推送: ${notesToPush.length} 条，抹除本地幽灵: ${notesToDeleteLocally.length} 条');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ 笔记同步失败: $e');
      }
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

    List<Future<void>> uploadTasks = imagesToUpload.where((path) => !p.isAbsolute(path)).map((rawPath) async {
      try {
        final normalizedPath = rawPath.replaceAll('\\', '/');
        final fileName = normalizedPath.split('/').last;
        final localFile = File(p.join(appDir.path, 'note_images', fileName));

        if (await localFile.exists()) {
          await storage.upload(fileName, localFile, fileOptions: const FileOptions(upsert: true));
        }
      } catch (e) {
        if (kDebugMode) {
          print('🖼️ ❌ 上传图片失败 $rawPath: $e');
        }
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

    final rawPaths = imagesToDownload.where((path) => !p.isAbsolute(path)).toList();

    const int maxConcurrent = 5;
    for (int i = 0; i < rawPaths.length; i += maxConcurrent) {
      final end = (i + maxConcurrent < rawPaths.length) ? i + maxConcurrent : rawPaths.length;
      final chunk = rawPaths.sublist(i, end);

      final tasks = chunk.map((rawPath) async {
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
          if (kDebugMode) {
            print('🖼️ ❌ 下载图片失败 $rawPath: $e');
          }
        }
      });
      await Future.wait(tasks);
    }
  }


  static const String _lastTodoSyncKey = 'last_todo_sync_time';

  Future<void> syncTodos({Function()? onSyncComplete}) async {
    if (_todoRepo == null) return;
    if (_supabase.auth.currentUser == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      final deletedIds = prefs.getStringList(_deletedTodosKey) ?? [];
      if (deletedIds.isNotEmpty) {
        try {
          await _supabase.from('todos').delete().inFilter('id', deletedIds);
          await prefs.setStringList(_deletedTodosKey, []);
          if (kDebugMode) {
            print('🗑️ 成功清空云端回收站待办: ${deletedIds.length} 条');
          }
        } catch (e) {
          if (kDebugMode) {
            print('🗑️ ❌ 云端回收站待办清理失败: $e');
          }
        }
      }

      final lastSyncStr = prefs.getString(_lastTodoSyncKey);
      DateTime? lastSyncTime;
      if (lastSyncStr != null) lastSyncTime = DateTime.parse(lastSyncStr);

      final currentUserId = _supabase.auth.currentUser!.id;
      final List<dynamic> cloudMetadata = await _supabase.from('todos').select('id, updated_at').eq('user_id', currentUserId);

      final localMetaMap = _todoRepo.getAllTodosMetadata();

      final List<String> idsToFetch = [];
      final Set<String> pulledIds = {};
      final Set<String> cloudIds = {};

      for (var meta in cloudMetadata) {
        final cloudId = meta['id'] as String;
        if (deletedIds.contains(cloudId)) continue;

        final cloudUpdatedAt = DateTime.parse(meta['updated_at']).toLocal();
        cloudIds.add(cloudId);

        final localUpdatedAt = localMetaMap[cloudId];
        if (localUpdatedAt == null || cloudUpdatedAt.isAfter(localUpdatedAt)) {
          idsToFetch.add(cloudId);
          pulledIds.add(cloudId);
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

            if (localMetaMap.containsKey(cloudTodoId)) {
              await _todoRepo.updateTodo(updatedTodo);
            } else {
              await _todoRepo.addTodo(updatedTodo);
            }
            pullCount++;
          }
        }
      }

      List<Map<String, dynamic>> todosToPush = [];
      List<String> todosToDeleteLocally = [];

      for (var todoId in localMetaMap.keys) {
        if (pulledIds.contains(todoId)) continue;

        final localUpdatedAt = localMetaMap[todoId]!;
        bool isMissingInCloud = !cloudIds.contains(todoId);

        if (isMissingInCloud && lastSyncTime != null && !localUpdatedAt.isAfter(lastSyncTime)) {
          todosToDeleteLocally.add(todoId);
          continue;
        }

        if (isMissingInCloud || lastSyncTime == null || localUpdatedAt.isAfter(lastSyncTime)) {
          final fullTodo = _todoRepo.getTodoById(todoId);
          if (fullTodo != null) {
            todosToPush.add({
              'id': fullTodo.id,
              'title': fullTodo.title,
              'description': fullTodo.description,
              'created_at': fullTodo.createdAt.toUtc().toIso8601String(),
              'updated_at': fullTodo.updatedAt.toUtc().toIso8601String(),
              'due_date': fullTodo.dueDate?.toUtc().toIso8601String(),
              'is_completed': fullTodo.isCompleted,
              'is_deleted': fullTodo.isDeleted,
              'sort_order': fullTodo.sortOrder,
              'user_id': _supabase.auth.currentUser!.id,
              'sub_tasks': fullTodo.subTasks.map((st) => st.toMap()).toList(),
            });
          }
        }
      }

      for (var id in todosToDeleteLocally) {
        await _todoRepo.deleteTodo(id);
      }

      if (todosToPush.isNotEmpty) {
        await _supabase.from('todos').upsert(todosToPush);
      }

      await prefs.setString(_lastTodoSyncKey, DateTime.now().toUtc().toIso8601String());
      if (onSyncComplete != null) onSyncComplete();

      if (kDebugMode) {
        print('✅ 待办同步完成！拉取: $pullCount 条，推送: ${todosToPush.length} 条，抹除本地幽灵: ${todosToDeleteLocally.length} 条');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ 待办同步失败: $e');
      }
    }
  }
}