import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../models/note.dart';
import '../../models/tag.dart';
import '../../models/todo.dart';
import '../../models/category.dart';


class LocalBackupService {
  final Isar _isar;

  LocalBackupService(this._isar);

  // 获取本地图片存储目录
  Future<Directory> get _imageDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'note_images'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // =========================================================================
  // 📦 导出：将数据库和图片打包成 ZIP 并分享
  // =========================================================================
  Future<void> exportData(String userName) async { // 🌟 新增了 userName 参数
    try {
      // 1. 获取数据库全量数据
      final notes = _isar.notes.where().findAllSync();
      final todos = _isar.todos.where().findAllSync();
      final categories = _isar.categorys.where().findAllSync();
      final tags = _isar.tags.where().findAllSync();

      // 2. 将数据序列化为 JSON Map
      final backupData = {
        'version': 1,
        'exportAt': DateTime.now().toIso8601String(),
        'notes': notes.map(_noteToMap).toList(),
        'todos': todos.map(_todoToMap).toList(),
        'categories': categories.map(_categoryToMap).toList(),
        'tags': tags.map(_tagToMap).toList(),
      };

      // 3. 将 JSON 转为字节流
      final jsonBytes = utf8.encode(jsonEncode(backupData));

      // 4. 创建内存 Archive
      final archive = Archive();
      archive.addFile(ArchiveFile('notesync_data.json', jsonBytes.length, jsonBytes));

      // 5. 将本地所有的图片加入 Archive
      final imgDir = await _imageDir;
      if (imgDir.existsSync()) {
        final imgFiles = imgDir.listSync().whereType<File>();
        for (var file in imgFiles) {
          final fileName = p.basename(file.path);
          final fileBytes = file.readAsBytesSync();
          archive.addFile(ArchiveFile('images/$fileName', fileBytes.length, fileBytes));
        }
      }

      // 6. 将 Archive 编码为 ZIP 文件并存入临时目录
      final zipEncoder = ZipFileEncoder();
      final tempDir = await getTemporaryDirectory();

      // 🌟 核心防线：净化用户名，防止带有系统不允许的文件名特殊字符（如 / \ : * ? " < > | 等）
      final safeUserName = userName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

      // 🌟 构造人类可读的时间戳
      final now = DateTime.now();
      final timeString = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final zipPath = p.join(tempDir.path, 'NoteSync_${safeUserName}_$timeString.zip');

      zipEncoder.create(zipPath);
      for (var file in archive) {
        zipEncoder.addArchiveFile(file);
      }
      zipEncoder.close();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(zipPath)],
          text: '这是 $userName 的 NoteSync 数据备份', //
        ),
      );

    } catch (e) {
      debugPrint('🚨 导出失败: $e');
      rethrow;
    }
  }

  Future<bool> importData() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.single.path == null) {
        return false;
      }

      final zipFile = File(result.files.single.path!);
      final bytes = zipFile.readAsBytesSync();

      // 2. 解压 ZIP
      final archive = ZipDecoder().decodeBytes(bytes);

      // 3. 寻找并解析 JSON 数据
      final jsonArchiveFile = archive.findFile('notesync_data.json');
      if (jsonArchiveFile == null) {
        throw Exception("无效的备份文件：找不到 notesync_data.json");
      }

      final jsonString = utf8.decode(jsonArchiveFile.content as List<int>);
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      // 4. 反序列化对象，并执行 🌟“确定性深度洗白 (Idempotent Wash)”🌟
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final uuidGen = const Uuid();
      final now = DateTime.now();

      // 🌟 核心：使用当前用户 ID 作为 UUID v5 的命名空间
      // 这样：同一个原始 ID + 同一个用户 ID = 永远得到同一个新 ID
      final String namespace = currentUserId ?? uuidGen.v4();

      final Map<String, String> categoryIdMap = {};
      final Map<String, String> tagIdMap = {};

      // 4.1 洗白分类
      final List<Category> importedCategories = (backupData['categories'] as List).map((e) {
        final oldCat = _mapToCategory(e);
        // 🌟 使用 v5 替代 v4
        final newId = uuidGen.v5(namespace, oldCat.id);
        categoryIdMap[oldCat.id] = newId;
        return oldCat.copyWith(id: newId, updatedAt: now);
      }).toList();

      // 4.2 洗白标签
      final List<Tag> importedTags = (backupData['tags'] as List).map((e) {
        final oldTag = _mapToTag(e);
        final newId = uuidGen.v5(namespace, oldTag.id);
        tagIdMap[oldTag.id] = newId;
        return Tag(
          id: newId,
          name: oldTag.name,
          color: oldTag.color,
          isDeleted: oldTag.isDeleted,
          createdAt: now,
        );
      }).toList();

      // 4.3 洗白笔记
      final List<Note> importedNotes = (backupData['notes'] as List).map((e) {
        final oldNote = _mapToNote(e);
        final newId = uuidGen.v5(namespace, oldNote.id);
        final newCatId = oldNote.categoryId != null ? categoryIdMap[oldNote.categoryId] : null;
        final newTagIds = oldNote.tagIds.map((id) => tagIdMap[id] ?? id).toList();

        return oldNote.copyWith(
          id: newId,
          categoryId: newCatId,
          tagIds: newTagIds,
          lastModifiedBy: currentUserId,
          updatedAt: now, // 🌟 必须刷新时间，否则会被同步引擎误删
        );
      }).toList();

      // 4.4 洗白待办
      final List<Todo> importedTodos = (backupData['todos'] as List).map((e) {
        final oldTodo = _mapToTodo(e);
        final newId = uuidGen.v5(namespace, oldTodo.id);
        final newCatId = oldTodo.categoryId != null ? categoryIdMap[oldTodo.categoryId] : null;

        return oldTodo.copyWith(
          id: newId,
          categoryId: newCatId,
          lastModifiedBy: currentUserId,
          updatedAt: now,
        );
      }).toList();

      // 5. 恢复图片文件
      final imgDir = await _imageDir;
      for (var file in archive) {
        if (file.isFile && file.name.startsWith('images/')) {
          final fileName = file.name.replaceFirst('images/', '');
          final targetPath = p.join(imgDir.path, fileName);
          final imgFile = File(targetPath);
          imgFile.writeAsBytesSync(file.content as List<int>);
        }
      }

      // 6. 覆盖写入 Isar 数据库 (极其危险但彻底的恢复操作)
      await _isar.writeTxn(() async {
        await _isar.notes.clear();
        await _isar.todos.clear();
        await _isar.categorys.clear();
        await _isar.tags.clear();

        await _isar.notes.putAll(importedNotes);
        await _isar.todos.putAll(importedTodos);
        await _isar.categorys.putAll(importedCategories);
        await _isar.tags.putAll(importedTags);
      });

      return true;
    } catch (e) {
      debugPrint('🚨 导入失败: $e');
      rethrow;
    }
  }


  Map<String, dynamic> _noteToMap(Note n) => {
    'id': n.id, 'title': n.title, 'content': n.content,
    'createdAt': n.createdAt.toIso8601String(), 'updatedAt': n.updatedAt.toIso8601String(),
    'tagIds': n.tagIds, 'categoryId': n.categoryId, 'version': n.version,
    'lastModifiedBy': n.lastModifiedBy, 'isPinned': n.isPinned, 'isDeleted': n.isDeleted,
  };
  Note _mapToNote(Map<String, dynamic> m) => Note(
    id: m['id'], title: m['title'], content: m['content'],
    createdAt: DateTime.parse(m['createdAt']), updatedAt: DateTime.parse(m['updatedAt']),
    tagIds: List<String>.from(m['tagIds'] ?? []), categoryId: m['categoryId'],
    version: m['version'] ?? 1, lastModifiedBy: m['lastModifiedBy'],
    isPinned: m['isPinned'] ?? false, isDeleted: m['isDeleted'] ?? false,
  );

  Map<String, dynamic> _todoToMap(Todo t) => {
    'id': t.id, 'title': t.title, 'isCompleted': t.isCompleted,
    'createdAt': t.createdAt.toIso8601String(), 'updatedAt': t.updatedAt.toIso8601String(),
    'description': t.description, 'dueDate': t.dueDate?.toIso8601String(),
    'sortOrder': t.sortOrder, 'categoryId': t.categoryId, 'version': t.version,
    'lastModifiedBy': t.lastModifiedBy, 'isDeleted': t.isDeleted,
    'subTasks': t.subTasks.map((st) => st.toMap()).toList(),
  };
  Todo _mapToTodo(Map<String, dynamic> m) => Todo(
    id: m['id'], title: m['title'], isCompleted: m['isCompleted'],
    createdAt: DateTime.parse(m['createdAt']), updatedAt: DateTime.parse(m['updatedAt']),
    description: m['description'] ?? '', dueDate: m['dueDate'] != null ? DateTime.parse(m['dueDate']) : null,
    sortOrder: m['sortOrder'] ?? 0.0, categoryId: m['categoryId'], version: m['version'] ?? 1,
    lastModifiedBy: m['lastModifiedBy'], isDeleted: m['isDeleted'] ?? false,
    subTasks: (m['subTasks'] as List?)?.map((e) => SubTask.fromMap(Map<String, dynamic>.from(e))).toList() ?? [],
  );

  Map<String, dynamic> _categoryToMap(Category c) => {
    'id': c.id, 'name': c.name, 'color': c.color, 'icon': c.icon,
    'sortOrder': c.sortOrder, 'isDeleted': c.isDeleted,
    'createdAt': c.createdAt.toIso8601String(), 'updatedAt': c.updatedAt.toIso8601String(),
  };
  Category _mapToCategory(Map<String, dynamic> m) => Category(
    id: m['id'], name: m['name'], color: m['color'], icon: m['icon'],
    sortOrder: m['sortOrder'] ?? 0.0, isDeleted: m['isDeleted'] ?? false,
    createdAt: DateTime.parse(m['createdAt']), updatedAt: DateTime.parse(m['updatedAt']),
  );

  Map<String, dynamic> _tagToMap(Tag t) => {
    'id': t.id, 'name': t.name, 'color': t.color, 'isDeleted': t.isDeleted,
    'createdAt': t.createdAt.toIso8601String(),
  };
  Tag _mapToTag(Map<String, dynamic> m) => Tag(
    id: m['id'], name: m['name'], color: m['color'], isDeleted: m['isDeleted'] ?? false,
    createdAt: DateTime.parse(m['createdAt']),
  );
}