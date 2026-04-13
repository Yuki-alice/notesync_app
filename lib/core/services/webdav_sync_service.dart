import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import '../../models/note.dart';
import '../../models/todo.dart';
import '../../models/category.dart';
import '../../models/tag.dart';

class WebDavSyncService {
  final Isar _isar;
  static const String _remoteBaseDir = '/NoteSync';
  static const String _remoteJsonPath = '$_remoteBaseDir/notesync_data.json';
  static const String _remoteImageDir = '$_remoteBaseDir/images';

  WebDavSyncService(this._isar);

  // =========================================================================
  // 🔌 1. 引擎点火与连接测试
  // =========================================================================
  Future<webdav.Client?> _getClient() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('webdav_url');
    final user = prefs.getString('webdav_user');
    final pwd = prefs.getString('webdav_pwd');

    if (url == null || url.isEmpty || user == null || pwd == null) return null;

    final client = webdav.newClient(
      url,
      user: user,
      password: pwd,
      debug: kDebugMode, // 调试模式下会在控制台打印 WebDAV 报文
    );
    return client;
  }

  /// 提供给 UI 测试连接使用
  Future<bool> pingConnection(String url, String user, String pwd) async {
    try {
      final client = webdav.newClient(url, user: user, password: pwd);
      await client.ping();
      return true;
    } catch (e) {
      debugPrint('🚨 WebDAV 测通失败: $e');
      return false;
    }
  }

  // =========================================================================
  // 🔄 2. 核心 2-Way JSON 增量合并同步
  // =========================================================================
  Future<void> syncAll() async {
    final client = await _getClient();
    if (client == null) {
      debugPrint('⚠️ WebDAV 未配置，中止同步');
      return;
    }

    debugPrint('🟢 [SYNC-WEBDAV] ====== 🚀 启动 WebDAV 双向同步引擎 ======');
    try {
      // 1. 确保云端目录结构存在
      try {
        await client.mkdir(_remoteBaseDir);
      } catch (_) {}
      try {
        await client.mkdir(_remoteImageDir);
      } catch (_) {}

      // 2. 尝试从 WebDAV 下载最新的 JSON 快照
      final tempDir = await getTemporaryDirectory();
      final localJsonPath = p.join(tempDir.path, 'webdav_download.json');
      final downloadFile = File(localJsonPath);
      if (downloadFile.existsSync()) {
        downloadFile.deleteSync();
      }
      Map<String, dynamic>? remoteData;

      try {
        await client.read2File(_remoteJsonPath, localJsonPath);
        final jsonString = File(localJsonPath).readAsStringSync();
        remoteData = jsonDecode(jsonString) as Map<String, dynamic>;
        debugPrint('🟢 [SYNC-WEBDAV] 成功拉取云端 JSON 快照');
      } catch (e) {
        debugPrint('⚠️ [SYNC-WEBDAV] 云端无历史快照，将执行全量初始推送');
      }

      // 3. 内存双向合并算法 (Last-Write-Wins)
      await _mergeData(remoteData);

      // 4. 将合并后的最终真理写入本地 Isar，并重新打包成 JSON Push 到云端
      final newJsonData = _generateSnapshotJson();
      final jsonString = jsonEncode(newJsonData);
      final Uint8List jsonBytes = Uint8List.fromList(utf8.encode(jsonString));
      await client.write(_remoteJsonPath, jsonBytes);
      debugPrint('🟢 [SYNC-WEBDAV] 成功将最新快照推送至云端');


      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('deleted_note_ids', []);
      await prefs.setStringList('deleted_todo_ids', []);
      await prefs.setStringList('deleted_categories', []);

      // 5. 附件同步 (简单的差异上传)
      await _syncImages(client);

      debugPrint('🟢 [SYNC-WEBDAV] ====== ✅ WebDAV 同步完美收官 ======');
    } catch (e) {
      debugPrint('❌ [SYNC-WEBDAV] 引擎崩溃: $e');
      rethrow;
    }
  }


// =========================================================================
  // 🧠 3. 合并逻辑与序列化助手
  // =========================================================================
  Future<void> _mergeData(Map<String, dynamic>? remoteData) async {
    // 🌟 1. 获取本地记录的“物理删除黑名单”
    final prefs = await SharedPreferences.getInstance();
    final deletedNoteIds = prefs.getStringList('deleted_note_ids') ?? [];
    final deletedTodoIds = prefs.getStringList('deleted_todo_ids') ?? [];
    final deletedCategoryIds = prefs.getStringList('deleted_categories') ?? [];

    List<Note> remoteNotes = [];
    List<Todo> remoteTodos = [];
    List<Category> remoteCategories = [];
    List<Tag> remoteTags = [];

    if (remoteData != null) {
      remoteNotes = (remoteData['notes'] as List).map((e) => _mapToNote(e)).toList();
      remoteTodos = (remoteData['todos'] as List).map((e) => _mapToTodo(e)).toList();
      remoteCategories = (remoteData['categories'] as List).map((e) => _mapToCategory(e)).toList();
      remoteTags = (remoteData['tags'] as List).map((e) => _mapToTag(e)).toList();

      // 🌟 2. 拔管操作：如果云端拉下来的数据在黑名单里，直接强制抹除！防止借尸还魂！
      remoteNotes.removeWhere((n) => deletedNoteIds.contains(n.id));
      remoteTodos.removeWhere((t) => deletedTodoIds.contains(t.id));
      remoteCategories.removeWhere((c) => deletedCategoryIds.contains(c.id));
    }

    _isar.writeTxnSync(() {
      // 🌟 合并 Notes
      final localNotesMap = {
        for (var n in _isar.notes.where().findAllSync()) n.id: n,
      };
      for (var rNote in remoteNotes) {
        final lNote = localNotesMap[rNote.id];
        if (lNote == null || rNote.updatedAt.isAfter(lNote.updatedAt)) {
          _isar.notes.putSync(rNote);
        }
      }

      // 🌟 合并 Todos
      final localTodosMap = {
        for (var t in _isar.todos.where().findAllSync()) t.id: t,
      };
      for (var rTodo in remoteTodos) {
        final lTodo = localTodosMap[rTodo.id];
        if (lTodo == null || rTodo.updatedAt.isAfter(lTodo.updatedAt)) {
          _isar.todos.putSync(rTodo);
        }
      }

      // 🌟 合并 Categories
      final localCatsMap = {
        for (var c in _isar.categorys.where().findAllSync()) c.id: c,
      };
      for (var rCat in remoteCategories) {
        final lCat = localCatsMap[rCat.id];
        if (lCat == null || rCat.updatedAt.isAfter(lCat.updatedAt)) {
          _isar.categorys.putSync(rCat);
        }
      }

      // 🌟 合并 Tags
      final localTagsMap = {
        for (var t in _isar.tags.where().findAllSync()) t.id: t,
      };
      for (var rTag in remoteTags) {
        if (!localTagsMap.containsKey(rTag.id)) {
          _isar.tags.putSync(rTag);
        }
      }
    });
  }

  Map<String, dynamic> _generateSnapshotJson() {
    return {
      'version': 2,
      'exportAt': DateTime.now().toIso8601String(),
      'notes': _isar.notes.where().findAllSync().map(_noteToMap).toList(),
      'todos': _isar.todos.where().findAllSync().map(_todoToMap).toList(),
      'categories':
          _isar.categorys.where().findAllSync().map(_categoryToMap).toList(),
      'tags': _isar.tags.where().findAllSync().map(_tagToMap).toList(),
    };
  }

  Future<void> _syncImages(webdav.Client client) async {
    final appDir = await getApplicationDocumentsDirectory();
    final localImgDir = Directory(p.join(appDir.path, 'note_images'));
    if (!localImgDir.existsSync()) return;

    // 🌟 1. 核心：从本地 Isar 扫描所有“活着的”笔记，提取它们真正引用的图片
    final allNotes = _isar.notes.filter().isDeletedEqualTo(false).findAllSync();
    final Set<String> usedImageNames = {};
    for (var note in allNotes) {
      final paths = Note.extractAllImagePaths(note.content);
      for (var path in paths) {
        usedImageNames.add(p.basename(path.replaceAll('\\', '/')));
      }
    }

    // 2. 获取本地物理文件列表
    final localFiles = localImgDir.listSync().whereType<File>().toList();
    final localFileNames = localFiles.map((f) => p.basename(f.path)).toSet();

    // 3. 获取云端图片列表
    List<webdav.File> remoteFiles = [];
    try {
      remoteFiles = await client.readDir(_remoteImageDir);
    } catch (_) {}

    final Map<String, String> remoteFileMap = {
      for (var f in remoteFiles) if (f.name != null && f.path != null) f.name!: f.path!
    };

    // 🌟 4. 云端 GC (Garbage Collection)：绞杀云端僵尸图片
    // 如果云端图片没有被任何一篇本地笔记引用，直接从服务器删除！
    for (var remoteName in remoteFileMap.keys) {
      if (!usedImageNames.contains(remoteName)) {
        try {
          await client.remove(remoteFileMap[remoteName]!);
          debugPrint('🧹 [SYNC-WEBDAV] 成功绞杀云端僵尸图片: $remoteName');
        } catch (e) {
          debugPrint('⚠️ WebDAV 删除云端孤儿图片失败: $e');
        }
      }
    }

    // 5. 推送本地有效图片 (仅推送被引用的且云端缺失的)
    for (var file in localFiles) {
      final fileName = p.basename(file.path);
      if (usedImageNames.contains(fileName) && !remoteFileMap.containsKey(fileName)) {
        try {
          final fileBytes = await file.readAsBytes();
          await client.write('$_remoteImageDir/$fileName', fileBytes);
        } catch (e) {
          debugPrint('⚠️ WebDAV 上传图片失败 $fileName: $e');
        }
      }
    }

    // 6. 自动修复 (仅拉取被引用但本地缺失的)
    for (var remoteName in remoteFileMap.keys) {
      if (usedImageNames.contains(remoteName) && !localFileNames.contains(remoteName)) {
        try {
          final targetPath = p.join(localImgDir.path, remoteName);
          await client.read2File(remoteFileMap[remoteName]!, targetPath);
          debugPrint('✨ [SYNC-WEBDAV] 自动修复下载缺失图片: $remoteName');
        } catch (e) {
          debugPrint('⚠️ WebDAV 下载图片失败 $remoteName: $e');
        }
      }
    }
  }

  // JSON 映射方法 (复用你之前写的逻辑)
  Map<String, dynamic> _noteToMap(Note n) => {
    'id': n.id,
    'title': n.title,
    'content': n.content,
    'createdAt': n.createdAt.toIso8601String(),
    'updatedAt': n.updatedAt.toIso8601String(),
    'tagIds': n.tagIds,
    'categoryId': n.categoryId,
    'version': n.version,
    'lastModifiedBy': n.lastModifiedBy,
    'isPinned': n.isPinned,
    'isDeleted': n.isDeleted,
  };
  Note _mapToNote(Map<String, dynamic> m) => Note(
    id: m['id'],
    title: m['title'],
    content: m['content'],
    createdAt: DateTime.parse(m['createdAt']),
    updatedAt: DateTime.parse(m['updatedAt']),
    tagIds: List<String>.from(m['tagIds'] ?? []),
    categoryId: m['categoryId'],
    version: m['version'] ?? 1,
    lastModifiedBy: m['lastModifiedBy'],
    isPinned: m['isPinned'] ?? false,
    isDeleted: m['isDeleted'] ?? false,
  );
  Map<String, dynamic> _todoToMap(Todo t) => {
    'id': t.id,
    'title': t.title,
    'isCompleted': t.isCompleted,
    'createdAt': t.createdAt.toIso8601String(),
    'updatedAt': t.updatedAt.toIso8601String(),
    'description': t.description,
    'dueDate': t.dueDate?.toIso8601String(),
    'sortOrder': t.sortOrder,
    'categoryId': t.categoryId,
    'version': t.version,
    'lastModifiedBy': t.lastModifiedBy,
    'isDeleted': t.isDeleted,
    'subTasks': t.subTasks.map((st) => st.toMap()).toList(),
  };
  Todo _mapToTodo(Map<String, dynamic> m) => Todo(
    id: m['id'],
    title: m['title'],
    isCompleted: m['isCompleted'],
    createdAt: DateTime.parse(m['createdAt']),
    updatedAt: DateTime.parse(m['updatedAt']),
    description: m['description'] ?? '',
    dueDate: m['dueDate'] != null ? DateTime.parse(m['dueDate']) : null,
    sortOrder: m['sortOrder'] ?? 0.0,
    categoryId: m['categoryId'],
    version: m['version'] ?? 1,
    lastModifiedBy: m['lastModifiedBy'],
    isDeleted: m['isDeleted'] ?? false,
    subTasks:
        (m['subTasks'] as List?)
            ?.map((e) => SubTask.fromMap(Map<String, dynamic>.from(e)))
            .toList() ??
        [],
  );
  Map<String, dynamic> _categoryToMap(Category c) => {
    'id': c.id,
    'name': c.name,
    'color': c.color,
    'icon': c.icon,
    'sortOrder': c.sortOrder,
    'isDeleted': c.isDeleted,
    'createdAt': c.createdAt.toIso8601String(),
    'updatedAt': c.updatedAt.toIso8601String(),
  };
  Category _mapToCategory(Map<String, dynamic> m) => Category(
    id: m['id'],
    name: m['name'],
    color: m['color'],
    icon: m['icon'],
    sortOrder: m['sortOrder'] ?? 0.0,
    isDeleted: m['isDeleted'] ?? false,
    createdAt: DateTime.parse(m['createdAt']),
    updatedAt: DateTime.parse(m['updatedAt']),
  );
  Map<String, dynamic> _tagToMap(Tag t) => {
    'id': t.id,
    'name': t.name,
    'color': t.color,
    'isDeleted': t.isDeleted,
    'createdAt': t.createdAt.toIso8601String(),
  };
  Tag _mapToTag(Map<String, dynamic> m) => Tag(
    id: m['id'],
    name: m['name'],
    color: m['color'],
    isDeleted: m['isDeleted'] ?? false,
    createdAt: DateTime.parse(m['createdAt']),
  );
}
