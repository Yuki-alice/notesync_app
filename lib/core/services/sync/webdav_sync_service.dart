import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import '../../../models/note.dart';
import '../../../models/todo.dart';
import '../../../models/category.dart';
import '../../../models/tag.dart';
import '../../repositories/note_repository.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/tag_repository.dart';
import '../../repositories/todo_repository.dart';
import 'sync_models.dart';

class WebDavSyncService {
  final NoteRepository _noteRepo;
  final CategoryRepository _categoryRepo;
  final TagRepository _tagRepo;
  final TodoRepository _todoRepo;

  static const String _remoteBaseDir = '/Komorebi';
  static const String _remoteJsonPath = '$_remoteBaseDir/komorebi_data.json';
  static const String _remoteImageDir = '$_remoteBaseDir/images';

  WebDavSyncService({
    required NoteRepository noteRepository,
    required CategoryRepository categoryRepository,
    required TagRepository tagRepository,
    required TodoRepository todoRepository,
  })  : _noteRepo = noteRepository,
        _categoryRepo = categoryRepository,
        _tagRepo = tagRepository,
        _todoRepo = todoRepository;

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

    final prefs = await SharedPreferences.getInstance();

    // 读取上次增量同步时间戳（null 则为首次全量同步）
    final lastNoteSyncTime = _parseLastSyncTime(prefs.getString(webdavLastNoteSyncKey));
    final lastTodoSyncTime = _parseLastSyncTime(prefs.getString(webdavLastTodoSyncKey));
    final lastCategorySyncTime = _parseLastSyncTime(prefs.getString(webdavLastCategorySyncKey));

    final isIncremental = lastNoteSyncTime != null ||
        lastTodoSyncTime != null ||
        lastCategorySyncTime != null;

    debugPrint('🟢 [SYNC-WEBDAV] ====== 🚀 启动 WebDAV 双向同步引擎 ======');
    debugPrint('🟢 [SYNC-WEBDAV] 同步模式: ${isIncremental ? "增量" : "全量"}');
    if (isIncremental) {
      debugPrint('🟢 [SYNC-WEBDAV] 上次同步时间 - notes: $lastNoteSyncTime, todos: $lastTodoSyncTime, categories: $lastCategorySyncTime');
    }

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

      // 3. 增量合并：只处理 updatedAt > lastSyncTime 的记录
      await _mergeData(
        remoteData,
        lastNoteSyncTime: lastNoteSyncTime,
        lastTodoSyncTime: lastTodoSyncTime,
        lastCategorySyncTime: lastCategorySyncTime,
      );

      // 4. 增量推送：将本地变更合并进云端快照后推送
      final newJsonData = await _generateSnapshotJson(
        remoteData: remoteData,
        lastNoteSyncTime: lastNoteSyncTime,
        lastTodoSyncTime: lastTodoSyncTime,
        lastCategorySyncTime: lastCategorySyncTime,
      );
      final jsonString = jsonEncode(newJsonData);
      final Uint8List jsonBytes = Uint8List.fromList(utf8.encode(jsonString));
      await client.write(_remoteJsonPath, jsonBytes);
      debugPrint('🟢 [SYNC-WEBDAV] 成功将最新快照推送至云端');

      // 5. 更新增量同步时间戳
      final now = DateTime.now().toUtc().toIso8601String();
      await prefs.setString(webdavLastNoteSyncKey, now);
      await prefs.setString(webdavLastTodoSyncKey, now);
      await prefs.setString(webdavLastCategorySyncKey, now);
      debugPrint('🟢 [SYNC-WEBDAV] 已更新同步时间戳: $now');

      // 6. 清空删除黑名单
      await prefs.setStringList('deleted_note_ids', []);
      await prefs.setStringList('deleted_todo_ids', []);
      await prefs.setStringList('deleted_categories', []);

      // 7. 附件同步 (简单的差异上传)
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

  /// 解析 ISO-8601 时间戳字符串，null 安全
  DateTime? _parseLastSyncTime(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  /// 统一冲突解决策略 (与 Supabase/LAN 一致):
  ///   - Notes/Todos: version 优先，version 相同时用 updatedAt 作为后备
  ///   - Categories: updatedAt LWW (无 version 字段)
  ///   - Tags: 仅补全存在性
  ///
  /// 增量模式下只合并 updatedAt > lastSyncTime 的记录。
  /// Tags 始终全量合并（仅追加新标签，开销极小）。
  Future<void> _mergeData(
    Map<String, dynamic>? remoteData, {
    DateTime? lastNoteSyncTime,
    DateTime? lastTodoSyncTime,
    DateTime? lastCategorySyncTime,
  }) async {
    // 🌟 1. 获取本地记录的”物理删除黑名单”
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

    // 🌟 合并 Notes (增量过滤 + version 优先 + updatedAt 后备)
    int noteMerged = 0;
    final localNotesMap = {
      for (var n in _noteRepo.getAllNotes()) n.id: n,
    };
    for (var rNote in remoteNotes) {
      if (lastNoteSyncTime != null &&
          !rNote.updatedAt.isAfter(lastNoteSyncTime)) {
        continue; // 增量模式：跳过未变更记录
      }
      final lNote = localNotesMap[rNote.id];
      if (lNote == null ||
          rNote.version > lNote.version ||
          (rNote.version == lNote.version &&
           rNote.updatedAt.isAfter(lNote.updatedAt))) {
        await _noteRepo.saveNoteFromSync(rNote);
        noteMerged++;
      }
    }

    // 🌟 合并 Todos (增量过滤 + version 优先 + updatedAt 后备)
    int todoMerged = 0;
    final localTodosMap = {
      for (var t in _todoRepo.getAllTodos()) t.id: t,
    };
    for (var rTodo in remoteTodos) {
      if (lastTodoSyncTime != null &&
          !rTodo.updatedAt.isAfter(lastTodoSyncTime)) {
        continue; // 增量模式：跳过未变更记录
      }
      final lTodo = localTodosMap[rTodo.id];
      if (lTodo == null ||
          rTodo.version > lTodo.version ||
          (rTodo.version == lTodo.version &&
           rTodo.updatedAt.isAfter(lTodo.updatedAt))) {
        await _todoRepo.addTodo(rTodo);
        todoMerged++;
      }
    }

    // 🌟 合并 Categories (增量过滤 + LWW)
    int categoryMerged = 0;
    final localCatsMap = {
      for (var c in _categoryRepo.getAllCategories()) c.id: c,
    };
    for (var rCat in remoteCategories) {
      if (lastCategorySyncTime != null &&
          !rCat.updatedAt.isAfter(lastCategorySyncTime)) {
        continue; // 增量模式：跳过未变更记录
      }
      final lCat = localCatsMap[rCat.id];
      if (lCat == null || rCat.updatedAt.isAfter(lCat.updatedAt)) {
        await _categoryRepo.addCategory(rCat);
        categoryMerged++;
      }
    }

    // 🌟 合并 Tags (始终全量，仅追加新标签)
    final localTagsMap = {
      for (var t in _tagRepo.getAllTags()) t.id: t,
    };
    for (var rTag in remoteTags) {
      if (!localTagsMap.containsKey(rTag.id)) {
        await _tagRepo.addTag(rTag);
      }
    }

    if (lastNoteSyncTime != null || lastTodoSyncTime != null || lastCategorySyncTime != null) {
      debugPrint('🟢 [SYNC-WEBDAV] 增量合并完成 - notes: $noteMerged, todos: $todoMerged, categories: $categoryMerged');
    }
  }

  /// 生成推送快照 JSON。
  ///
  /// 增量模式下，将本地 updatedAt > lastSyncTime 的记录合并进云端快照，
  /// 未变更的记录保留云端版本，避免全量序列化开销。
  Future<Map<String, dynamic>> _generateSnapshotJson({
    Map<String, dynamic>? remoteData,
    DateTime? lastNoteSyncTime,
    DateTime? lastTodoSyncTime,
    DateTime? lastCategorySyncTime,
  }) async {
    // 增量模式：基于云端快照 + 本地变更合并
    if (lastNoteSyncTime != null && remoteData != null) {
      // Notes: 云端未变更的 + 本地所有记录（本地为准）
      final cloudNotes = <String, Map<String, dynamic>>{};
      for (var m in (remoteData['notes'] as List? ?? [])) {
        final map = Map<String, dynamic>.from(m);
        cloudNotes[map['id'] as String] = map;
      }
      final localNotes = _noteRepo.getAllNotes();
      // 本地记录全覆盖云端，未变更的保留云端
      final pushNotes = <Map<String, dynamic>>[];
      for (var n in localNotes) {
        if (lastNoteSyncTime.isAfter(n.updatedAt)) {
          // 本地未变更，保留云端版本
          if (cloudNotes.containsKey(n.id)) {
            pushNotes.add(cloudNotes[n.id]!);
          } else {
            pushNotes.add(_noteToMap(n));
          }
        } else {
          pushNotes.add(_noteToMap(n));
        }
      }
      // 云端有但本地没有的（已被删除），不加入快照
      debugPrint('🟢 [SYNC-WEBDAV] Notes 增量推送: ${pushNotes.length} 条');

      // Todos
      final cloudTodos = <String, Map<String, dynamic>>{};
      for (var m in (remoteData['todos'] as List? ?? [])) {
        final map = Map<String, dynamic>.from(m);
        cloudTodos[map['id'] as String] = map;
      }
      final localTodos = _todoRepo.getAllTodos();
      final pushTodos = <Map<String, dynamic>>[];
      for (var t in localTodos) {
        if (lastTodoSyncTime != null && lastTodoSyncTime.isAfter(t.updatedAt)) {
          if (cloudTodos.containsKey(t.id)) {
            pushTodos.add(cloudTodos[t.id]!);
          } else {
            pushTodos.add(_todoToMap(t));
          }
        } else {
          pushTodos.add(_todoToMap(t));
        }
      }
      debugPrint('🟢 [SYNC-WEBDAV] Todos 增量推送: ${pushTodos.length} 条');

      // Categories
      final cloudCats = <String, Map<String, dynamic>>{};
      for (var m in (remoteData['categories'] as List? ?? [])) {
        final map = Map<String, dynamic>.from(m);
        cloudCats[map['id'] as String] = map;
      }
      final localCats = _categoryRepo.getAllCategories();
      final pushCats = <Map<String, dynamic>>[];
      for (var c in localCats) {
        if (lastCategorySyncTime != null && lastCategorySyncTime.isAfter(c.updatedAt)) {
          if (cloudCats.containsKey(c.id)) {
            pushCats.add(cloudCats[c.id]!);
          } else {
            pushCats.add(_categoryToMap(c));
          }
        } else {
          pushCats.add(_categoryToMap(c));
        }
      }
      debugPrint('🟢 [SYNC-WEBDAV] Categories 增量推送: ${pushCats.length} 条');

      return {
        'version': 2,
        'exportAt': DateTime.now().toIso8601String(),
        'notes': pushNotes,
        'todos': pushTodos,
        'categories': pushCats,
        'tags': _tagRepo.getAllTags().map(_tagToMap).toList(),
      };
    }

    // 全量模式：直接序列化本地全部数据
    return {
      'version': 2,
      'exportAt': DateTime.now().toIso8601String(),
      'notes': _noteRepo.getAllNotes().map(_noteToMap).toList(),
      'todos': _todoRepo.getAllTodos().map(_todoToMap).toList(),
      'categories': _categoryRepo.getAllCategories().map(_categoryToMap).toList(),
      'tags': _tagRepo.getAllTags().map(_tagToMap).toList(),
    };
  }

  Future<void> _syncImages(webdav.Client client) async {
    final appDir = await getApplicationDocumentsDirectory();
    final localImgDir = Directory(p.join(appDir.path, 'note_images'));
    if (!localImgDir.existsSync()) return;

    // 🌟 1. 核心：从本地 Repository 扫描所有”活着的”笔记，提取它们真正引用的图片
    final allNotes = _noteRepo.getAllNotes().where((n) => !n.isDeleted).toList();
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
    'updatedAt': t.updatedAt.toIso8601String(),
  };
  Tag _mapToTag(Map<String, dynamic> m) => Tag(
    id: m['id'],
    name: m['name'],
    color: m['color'],
    isDeleted: m['isDeleted'] ?? false,
    createdAt: DateTime.parse(m['createdAt']),
    updatedAt: DateTime.parse(m['updatedAt'] ?? m['createdAt']),
  );
}
