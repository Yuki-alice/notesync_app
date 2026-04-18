import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' hide Category;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';


import '../repositories/category_repository.dart';
import '../repositories/note_repository.dart';
import '../repositories/tag_repository.dart';
import '../repositories/todo_repository.dart';
import '../services/privacy_service.dart';

import '../../models/note.dart';
import '../../models/todo.dart';
import '../../models/category.dart';
import '../../models/tag.dart';

// 🌟 100% 还原你精心设计的全量日志模块
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

  // 🌟 优化：防止短时间内重复同步的锁机制
  static bool _isPrivateImageSyncing = false;
  static DateTime? _lastPrivateImageSyncTime;
  static const Duration _minSyncInterval = Duration(seconds: 10);

  // =========================================================================
  // 🌟 1. 本地删除动作记录 (废纸篓同步机制)
  // =========================================================================
  Future<void> recordDeletedTodoId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final deletedIds = prefs.getStringList(_deletedTodosKey) ?? [];
    if (!deletedIds.contains(id)) {
      deletedIds.add(id);
      await prefs.setStringList(_deletedTodosKey, deletedIds);
      _SyncLogger.info('TODO', '记录本地待删除 Todo ID: $id');
    }
  }

  Future<void> recordDeletedNoteId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final deletedIds = prefs.getStringList(_deletedNotesKey) ?? [];
    if (!deletedIds.contains(id)) {
      deletedIds.add(id);
      await prefs.setStringList(_deletedNotesKey, deletedIds);
      _SyncLogger.info('NOTE', '记录本地待删除 Note ID: $id');
    }
  }

  Future<void> recordDeletedCategory(String categoryId) async {
    final prefs = await SharedPreferences.getInstance();
    final deletedCats = prefs.getStringList(_deletedCategoriesKey) ?? [];
    if (!deletedCats.contains(categoryId)) {
      deletedCats.add(categoryId);
      await prefs.setStringList(_deletedCategoriesKey, deletedCats);
      _SyncLogger.info('CATE', '记录本地待删除分类: $categoryId');
    }
  }

  // =========================================================================
  // 🌟 2. 笔记 & 字典 同步全链路 (V2.0 增量版本)
  // =========================================================================
  Future<void> syncNotes({Function()? onTextSyncComplete}) async {
    if (_noteRepo == null) return;
    if (_supabase.auth.currentUser == null) {
      _SyncLogger.warn('NOTE', '未登录，中止同步');
      return;
    }

    _SyncLogger.info('NOTE', '====== 🚀 启动 V2.0 笔记同步管线 ======');
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = _supabase.auth.currentUser!.id;

      // 1. 优先同步分类和标签字典 (基建数据先到位)
      await _syncCategoriesAndTags(currentUserId, prefs);

      // 2. 清理笔记废纸篓
      await _processLocalDeletions(prefs, 'notes', _deletedNotesKey);

      final lastSyncStr = prefs.getString(_lastNoteSyncKey);
      final lastSyncTime = lastSyncStr != null ? DateTime.parse(lastSyncStr) : null;
      _SyncLogger.info('NOTE', '上次同步时间: ${lastSyncTime?.toLocal() ?? "从未同步"}');

      // 3. 笔记主表拉取比对 (基于更新时间兜底，兼容版本号)
      final cloudMetadata = await _fetchCloudMetadata('notes', currentUserId);
      final localMetaMap = _noteRepo.getAllNotesMetadata();

      final plan = _reconcileData(
        localMetaMap: localMetaMap,
        cloudMetadata: cloudMetadata,
        lastSyncTime: lastSyncTime,
      );

      List<Note> pulledNotes = [];
      if (plan.toPull.isNotEmpty) {
        pulledNotes = await _pullNotes(plan.toPull, currentUserId, localMetaMap.keys.toSet());
      }

      List<Note> pushedNotes = [];
      if (plan.toPush.isNotEmpty) {
        pushedNotes = await _pushNotes(plan.toPush, currentUserId);
      }

      for (var id in plan.toDeleteLocally) {
        await _noteRepo.deleteNote(id);
        _SyncLogger.info('NOTE', '👻 成功抹除本地幽灵笔记: $id');
      }

      await prefs.setString(_lastNoteSyncKey, DateTime.now().toUtc().toIso8601String());
      if (onTextSyncComplete != null) onTextSyncComplete();

      // 4. 图片资源分离同步
      try {
        final allNotes = _noteRepo.getAllNotes();

        // 🌟 上传所有笔记的图片（不只是被推送的），确保隐私笔记图片也能上传
        await _uploadImages(allNotes);

        // 🌟 核弹级更新：无论有没有拉取新笔记，强行扫描所有本地存活笔记，缺失的图片全部从云端下回来！
        await _downloadImages(allNotes);

        // 🌟 修复后的云端垃圾回收
        await _cleanUpCloudImages(allNotes);

      } catch (e) {
        _SyncLogger.error('IMAGE', '图片同步或清理管线异常', e);
      }

      _SyncLogger.info('NOTE', '====== ✅ 笔记同步管线完美收官 ======');
    } catch (e, stack) {
      _SyncLogger.error('NOTE', '同步管线崩溃', e);
    }
  }

  // =========================================================================
  // 🌟 隐私图片专用同步 - 在解锁隐私空间时调用
  // =========================================================================
  Future<void> syncPrivateImagesOnly() async {
    if (_noteRepo == null) return;
    if (_supabase.auth.currentUser == null) {
      _SyncLogger.warn('IMAGE', '未登录，中止隐私图片同步');
      return;
    }

    // 🌟 优化：防止重复同步
    if (_isPrivateImageSyncing) {
      _SyncLogger.info('IMAGE', '隐私图片同步正在进行中，跳过重复调用');
      return;
    }

    // 🌟 优化：检查同步间隔
    if (_lastPrivateImageSyncTime != null) {
      final timeSinceLastSync = DateTime.now().difference(_lastPrivateImageSyncTime!);
      if (timeSinceLastSync < _minSyncInterval) {
        _SyncLogger.info('IMAGE', '距离上次同步仅 ${timeSinceLastSync.inSeconds} 秒，跳过本次同步');
        return;
      }
    }

    final privacy = PrivacyService();
    if (!privacy.isUnlocked) {
      _SyncLogger.warn('IMAGE', '隐私空间未解锁，跳过隐私图片同步');
      return;
    }

    _isPrivateImageSyncing = true;
    _lastPrivateImageSyncTime = DateTime.now();

    _SyncLogger.info('IMAGE', '====== 🔐 启动隐私图片专用同步 ======');
    try {
      // 只获取隐私笔记
      final allNotes = _noteRepo.getAllNotes();
      final privateNotes = allNotes.where((n) => n.isPrivate && !n.isDeleted).toList();

      if (privateNotes.isEmpty) {
        _SyncLogger.info('IMAGE', '没有隐私笔记需要同步图片');
        return;
      }

      _SyncLogger.info('IMAGE', '发现 ${privateNotes.length} 条隐私笔记，开始同步图片');

      // 1. 先下载缺失的隐私图片（从云端拉取）
      await _downloadImages(privateNotes);

      // 2. 再上传本地隐私图片到云端
      await _uploadImages(privateNotes);

      _SyncLogger.info('IMAGE', '====== ✅ 隐私图片同步完成 ======');
    } catch (e) {
      _SyncLogger.error('IMAGE', '隐私图片同步失败', e);
    } finally {
      // 🌟 优化：释放同步锁
      _isPrivateImageSyncing = false;
    }
  }

  // =========================================================================
  // 🌟 Auto-Heal 附件处理引擎与云端 GC
  // =========================================================================
  Future<void> _uploadImages(List<Note> pushedNotes) async {
    final storage = _supabase.storage.from(_imageBucket);
    final appDir = await getApplicationDocumentsDirectory();

    // 🌟 收集需要上传的图片，标记是否属于隐私笔记
    final Map<String, bool> fileNameToIsPrivate = {};
    for (var note in pushedNotes) {
      // 优先使用 imagePaths 字段（如果存在）
      if (note.imagePaths.isNotEmpty) {
        for (var path in note.imagePaths) {
          fileNameToIsPrivate[path.replaceAll('\\', '/').split('/').last] = note.isPrivate;
        }
      } else {
        // 从内容中提取图片路径（兼容旧数据）
        // 🌟 隐私笔记需要解密后才能提取图片路径
        String content = note.content;
        if (note.isPrivate && content.startsWith('AES_V1::')) {
          content = PrivacyService().decryptText(content);
          // 如果解密失败，跳过此笔记的图片上传
          if (content.contains('🔒') || content.contains('❌')) {
            _SyncLogger.warn('IMAGE', '隐私笔记 ${note.id} 解密失败，跳过图片上传');
            continue;
          }
        }
        final paths = Note.extractAllImagePaths(content);
        for (var path in paths) {
          fileNameToIsPrivate[path.replaceAll('\\', '/').split('/').last] = note.isPrivate;
        }
      }
    }

    if (fileNameToIsPrivate.isEmpty) {
      _SyncLogger.info('IMAGE', '没有需要上传的图片');
      return;
    }

    _SyncLogger.info('IMAGE', '准备上传 ${fileNameToIsPrivate.length} 张图片，其中隐私图片: ${fileNameToIsPrivate.values.where((v) => v).length} 张');

    final privacy = PrivacyService();
    _SyncLogger.info('IMAGE', 'PrivacyService 状态: isUnlocked=${privacy.isUnlocked}');

    // 🌟 优化：先获取云端已有文件列表，避免重复上传
    final cloudFiles = await _getCloudFileList();
    _SyncLogger.info('IMAGE', '云端已有 ${cloudFiles.length} 个文件');

    int skippedCount = 0;
    int uploadedCount = 0;

    List<Future<void>> uploadTasks = fileNameToIsPrivate.entries.map((entry) async {
      final fileName = entry.key;
      final isPrivate = entry.value;
      final cloudFileName = isPrivate ? '$fileName.enc' : fileName;

      try {
        final localFile = File(p.join(appDir.path, 'note_images', fileName));
        if (await localFile.exists()) {
          // 🌟 优化：检查云端是否已有该文件
          if (cloudFiles.contains(cloudFileName)) {
            skippedCount++;
            return; // 跳过已存在的文件
          }

          if (isPrivate && privacy.isUnlocked) {
            // 🌟 隐私笔记图片：读取、加密、写入临时文件、上传
            // 检查云端是否已有普通版本（笔记从普通变为私密时）
            if (cloudFiles.contains(fileName)) {
              _SyncLogger.info('IMAGE', '检测到云端有普通版本，删除后上传加密版本: $fileName');
              try {
                await storage.remove([fileName]);
                _SyncLogger.info('IMAGE', '已删除云端普通版本: $fileName');
              } catch (e) {
                _SyncLogger.warn('IMAGE', '删除云端普通版本失败: $e');
              }
            }
            _SyncLogger.info('IMAGE', '正在加密上传隐私图片: $fileName');
            final bytes = await localFile.readAsBytes();
            final encryptedBytes = privacy.encryptFileBytes(bytes);
            // 加密后的文件名添加 .enc 后缀
            final encryptedFileName = '$fileName.enc';
            // 写入临时文件（使用临时目录避免污染主目录）
            final tempDir = Directory(p.join(appDir.path, 'note_images', '.temp'));
            if (!await tempDir.exists()) {
              await tempDir.create(recursive: true);
            }
            final tempFile = File(p.join(tempDir.path, encryptedFileName));
            await tempFile.writeAsBytes(encryptedBytes, flush: true);
            await storage.upload(
              encryptedFileName,
              tempFile,
              fileOptions: const FileOptions(upsert: true, contentType: 'application/octet-stream'),
            );
            // 删除临时文件
            await tempFile.delete();
            uploadedCount++;
            _SyncLogger.info('IMAGE', '隐私图片上传成功: $encryptedFileName');
          } else if (isPrivate && !privacy.isUnlocked) {
            _SyncLogger.warn('IMAGE', '隐私图片 $fileName 跳过上传：PrivacyService 未解锁');
          } else {
            // 🌟 普通笔记图片：直接上传
            // 检查云端是否已有加密版本（笔记从私密变为普通时）
            final encryptedFileName = '$fileName.enc';
            if (cloudFiles.contains(encryptedFileName)) {
              _SyncLogger.info('IMAGE', '检测到云端有加密版本，删除后上传普通版本: $fileName');
              try {
                await storage.remove([encryptedFileName]);
                _SyncLogger.info('IMAGE', '已删除云端加密版本: $encryptedFileName');
              } catch (e) {
                _SyncLogger.warn('IMAGE', '删除云端加密版本失败: $e');
              }
            }
            _SyncLogger.info('IMAGE', '正在上传普通图片: $fileName');
            await storage.upload(fileName, localFile, fileOptions: const FileOptions(upsert: true));
            uploadedCount++;
            _SyncLogger.info('IMAGE', '普通图片上传成功: $fileName');
          }
        } else {
          _SyncLogger.warn('IMAGE', '本地图片不存在: ${localFile.path}');
        }
      } catch (e) {
        _SyncLogger.warn('IMAGE', '上传图片跳过 $fileName: $e');
      }
    }).toList();

    await Future.wait(uploadTasks);
    _SyncLogger.info('IMAGE', '图片附件上传完成: 上传 $uploadedCount 张, 跳过 $skippedCount 张');
  }

  // 🌟 优化：获取云端文件列表
  Future<Set<String>> _getCloudFileList() async {
    try {
      final storage = _supabase.storage.from(_imageBucket);
      final files = await storage.list(searchOptions: const SearchOptions(limit: 5000));
      return files.map((f) => f.name).toSet();
    } catch (e) {
      _SyncLogger.warn('IMAGE', '获取云端文件列表失败: $e');
      return {};
    }
  }

  Future<void> _downloadImages(List<Note> allNotes) async {
    final storage = _supabase.storage.from(_imageBucket);
    final appDir = await getApplicationDocumentsDirectory();

    // 🌟 收集需要下载的图片，标记是否属于隐私笔记
    final Map<String, bool> fileNameToIsPrivate = {};
    for (var note in allNotes) {
      if (note.isDeleted) continue;
      // 🌟 优先使用 imagePaths 字段（如果存在）
      if (note.imagePaths.isNotEmpty) {
        for (var path in note.imagePaths) {
          fileNameToIsPrivate[path.replaceAll('\\', '/').split('/').last] = note.isPrivate;
        }
      } else {
        // 从内容中提取图片路径（兼容旧数据）
        // 🌟 隐私笔记需要解密后才能提取图片路径
        String content = note.content;
        if (note.isPrivate && content.startsWith('AES_V1::')) {
          content = PrivacyService().decryptText(content);
          // 如果解密失败，跳过此笔记的图片下载
          if (content.contains('🔒') || content.contains('❌')) {
            continue;
          }
        }
        final paths = Note.extractAllImagePaths(content);
        for (var path in paths) {
          fileNameToIsPrivate[path.replaceAll('\\', '/').split('/').last] = note.isPrivate;
        }
      }
    }

    if (fileNameToIsPrivate.isEmpty) return;

    int recoveredCount = 0;
    // 🌟 优化：加密/解密是CPU密集型操作，减少并发数避免卡顿
    // 普通图片用 5 个并发，隐私图片用 2 个并发
    final hasPrivateImages = fileNameToIsPrivate.values.any((v) => v);
    final int maxConcurrent = hasPrivateImages ? 2 : 5;
    final fileList = fileNameToIsPrivate.keys.toList();
    final privacy = PrivacyService();

    for (int i = 0; i < fileList.length; i += maxConcurrent) {
      final end = (i + maxConcurrent < fileList.length) ? i + maxConcurrent : fileList.length;
      final chunk = fileList.sublist(i, end);

      final tasks = chunk.map((fileName) async {
        try {
          final localFile = File(p.join(appDir.path, 'note_images', fileName));
          // 🌟 Auto-Heal: 如果本地文件被误删了，立刻强行从云端拉取！
          if (!await localFile.exists()) {
            final isPrivate = fileNameToIsPrivate[fileName] ?? false;
            
            if (isPrivate && privacy.isUnlocked) {
              // 🌟 隐私笔记图片：下载加密版本，解密后保存
              final encryptedFileName = '$fileName.enc';
              _SyncLogger.info('IMAGE', '正在下载隐私图片: $encryptedFileName');
              final encryptedBytes = await storage.download(encryptedFileName);
              final decryptedBytes = privacy.decryptFileBytes(encryptedBytes);
              await localFile.parent.create(recursive: true);
              await localFile.writeAsBytes(decryptedBytes);
              _SyncLogger.info('IMAGE', '隐私图片下载成功: $fileName');
              recoveredCount++;
            } else if (isPrivate && !privacy.isUnlocked) {
              _SyncLogger.warn('IMAGE', '隐私图片 $fileName 跳过下载：PrivacyService 未解锁');
            } else {
              // 普通笔记图片：直接下载
              _SyncLogger.info('IMAGE', '正在下载普通图片: $fileName');
              final bytes = await storage.download(fileName);
              await localFile.parent.create(recursive: true);
              await localFile.writeAsBytes(bytes);
              _SyncLogger.info('IMAGE', '普通图片下载成功: $fileName');
              recoveredCount++;
            }
          }
        } catch (e) {
          _SyncLogger.warn('IMAGE', '下载图片失败 $fileName: $e');
        }
      });
      await Future.wait(tasks);
    }

    if (recoveredCount > 0) {
      _SyncLogger.info('IMAGE', '✨ 自动修复引擎：成功从云端找回 $recoveredCount 张本地丢失的图片');
    }
  }

  Future<void> _cleanUpCloudImages(List<Note> allNotes) async {
    try {
      final Set<String> usedImageNames = {};
      for (var note in allNotes) {
        if (note.isDeleted) continue;
        // 🌟 优先使用 imagePaths 字段（如果存在）
        if (note.imagePaths.isNotEmpty) {
          for (var path in note.imagePaths) {
            usedImageNames.add(path.replaceAll('\\', '/').split('/').last); // 免疫反斜杠
          }
        } else {
          // 从内容中提取图片路径（兼容旧数据）
          // 🌟 隐私笔记需要解密后才能提取图片路径
          String content = note.content;
          if (note.isPrivate && content.startsWith('AES_V1::')) {
            content = PrivacyService().decryptText(content);
            // 如果解密失败，跳过此笔记
            if (content.contains('🔒') || content.contains('❌')) {
              continue;
            }
          }
          final paths = Note.extractAllImagePaths(content);
          for (var path in paths) {
            usedImageNames.add(path.replaceAll('\\', '/').split('/').last);
          }
        }
      }

      final storage = _supabase.storage.from(_imageBucket);
      final List<FileObject> cloudFiles = await storage.list(searchOptions: const SearchOptions(limit: 5000));

      final List<String> orphanedFiles = [];
      for (var file in cloudFiles) {
        if (file.name == '.emptyFolderPlaceholder' || file.name.startsWith('.')) continue;

        // 🌟 检查原始文件名和加密后的文件名
        final isUsed = usedImageNames.contains(file.name) ||
                       usedImageNames.any((name) => file.name == '$name.enc');
        if (!isUsed) {
          orphanedFiles.add(file.name);
        }
      }

      if (orphanedFiles.isNotEmpty) {
        await storage.remove(orphanedFiles);
        _SyncLogger.info('CLOUD-GC', '🧹 成功绞杀云端僵尸图片: ${orphanedFiles.length} 张');
      }
    } catch (e) {
      _SyncLogger.error('CLOUD-GC', '云端图片垃圾回收失败', e);
    }
  }

  // =========================================================================
  // 🌟 V2.1: 关系型字典双向增量同步 (彻底解决相互覆盖)
  // =========================================================================
  Future<void> _syncCategoriesAndTags(String userId, SharedPreferences prefs) async {
    if (_categoryRepo == null || _tagRepo == null) return;

    // ----- 1. 处理分类黑名单 (物理删除) -----
    final deletedCats = prefs.getStringList(_deletedCategoriesKey) ?? [];
    if (deletedCats.isNotEmpty) {
      await _supabase.from('categories').delete().inFilter('id', deletedCats);
      await prefs.setStringList(_deletedCategoriesKey, []);
      _SyncLogger.info('CATE', '成功清空本地分类黑名单');
    }

    // ----- 2. 分类双向增量同步 (基于 updatedAt 时间戳) -----
    final localCats = _categoryRepo.getAllCategories();
    final cloudCatsData = await _supabase.from('categories').select().eq('user_id', userId);

    final localCatsMap = { for (var c in localCats) c.id: c };
    final cloudCatsMap = { for (var map in cloudCatsData) map['id'] as String: map };

    final catsToPush = <Map<String, dynamic>>[];

    // 工具函数：转成 Supabase 支持的 Map
    Map<String, dynamic> catToPayload(Category c) => {
      'id': c.id, 'user_id': userId, 'name': c.name, 'color': c.color, 'icon': c.icon,
      'sort_order': c.sortOrder, 'is_deleted': c.isDeleted,
      'created_at': c.createdAt.toUtc().toIso8601String(),
      'updated_at': c.updatedAt.toUtc().toIso8601String(),
    };

    // (1) 遍历本地，决定谁有资格推送给云端
    for (var localCat in localCats) {
      final cloudData = cloudCatsMap[localCat.id];
      if (cloudData == null) {
        // 云端完全没有，属于本地新建，立刻推送！
        catsToPush.add(catToPayload(localCat));
      } else {
        // 云端也有，看谁的时间更新！(本地更新过，才推送)
        final cloudTime = DateTime.parse(cloudData['updated_at']).toLocal();
        if (localCat.updatedAt.difference(cloudTime).inSeconds > 2) {
          catsToPush.add(catToPayload(localCat));
        }
      }
    }

    // (2) 遍历云端，决定谁应该被拉回本地
    bool localCatChanged = false;
    for (var cloudData in cloudCatsData) {
      final cloudId = cloudData['id'] as String;
      final localCat = localCatsMap[cloudId];
      final cloudTime = DateTime.parse(cloudData['updated_at']).toLocal();

      final cloudCatModel = Category(
        id: cloudId, name: cloudData['name'], color: cloudData['color'], icon: cloudData['icon'],
        sortOrder: (cloudData['sort_order'] as num?)?.toDouble() ?? 0.0,
        isDeleted: cloudData['is_deleted'] ?? false,
        createdAt: DateTime.parse(cloudData['created_at']).toLocal(),
        updatedAt: cloudTime,
      );

      if (localCat == null) {
        // 本地没有，属于云端新建的，拉取并写入！
        await _categoryRepo!.addCategory(cloudCatModel);
        localCatChanged = true;
      } else {
        // 本地也有，看云端是否更新！(云端时间比本地新，才覆盖本地)
        if (cloudTime.difference(localCat.updatedAt).inSeconds > 2) {
          await _categoryRepo!.updateCategory(cloudCatModel);
          localCatChanged = true;
        }
      }
    }

    // 执行分类推送
    if (catsToPush.isNotEmpty) {
      await _supabase.from('categories').upsert(catsToPush);
      _SyncLogger.info('CATE', '推送 ${catsToPush.length} 个分类更新到云端');
    }
    if (localCatChanged) {
      _SyncLogger.info('CATE', '从云端拉取并更新了本地分类');
    }

    // ----- 3. 标签双向合并同步 (标签通常不修改名字，只需比对存在性) -----
    final localTags = _tagRepo!.getAllTags();
    final cloudTagsData = await _supabase.from('tags').select().eq('user_id', userId);

    final localTagsMap = { for (var t in localTags) t.id: t };
    final cloudTagsMap = { for (var map in cloudTagsData) map['id'] as String: map };

    final tagsToPush = <Map<String, dynamic>>[];

    for (var localTag in localTags) {
      if (!cloudTagsMap.containsKey(localTag.id)) {
        tagsToPush.add({
          'id': localTag.id, 'user_id': userId, 'name': localTag.name, 'color': localTag.color,
          'is_deleted': localTag.isDeleted,
          'created_at': localTag.createdAt.toUtc().toIso8601String(),
        });
      }
    }

    bool localTagChanged = false;
    for (var cloudData in cloudTagsData) {
      final cloudId = cloudData['id'] as String;
      if (!localTagsMap.containsKey(cloudId)) {
        await _tagRepo!.addTag(Tag(
          id: cloudId, name: cloudData['name'], color: cloudData['color'],
          isDeleted: cloudData['is_deleted'] ?? false,
          createdAt: DateTime.parse(cloudData['created_at']).toLocal(),
        ));
        localTagChanged = true;
      }
    }

    if (tagsToPush.isNotEmpty) {
      await _supabase.from('tags').upsert(tagsToPush);
      _SyncLogger.info('TAG', '推送 ${tagsToPush.length} 个新标签到云端');
    }
    if (localTagChanged) {
      _SyncLogger.info('TAG', '从云端拉取了新标签');
    }
  }

  // =========================================================================
  // 🌟 V2: 笔记拉取与多对多关联 (含强力容错修复)
  // =========================================================================
  Future<List<Note>> _pullNotes(List<String> idsToFetch, String userId, Set<String> existingLocalIds) async {
    List<Note> pulled = [];
    _SyncLogger.info('PULL', '准备从云端拉取 ${idsToFetch.length} 条笔记内容...');

    for (var i = 0; i < idsToFetch.length; i += 50) {
      final chunk = idsToFetch.sublist(i, i + 50 > idsToFetch.length ? idsToFetch.length : i + 50);

      List<dynamic> cloudUpdates = [];
      try {
        // 尝试执行级联查询 (带有标签关联)
        final res = await _supabase.from('notes')
            .select('*, note_tags(tag_id)')
            .inFilter('id', chunk)
            .eq('user_id', userId)
            .timeout(const Duration(seconds: 15));
        cloudUpdates = res as List<dynamic>;
      } catch (e) {
        _SyncLogger.warn('PULL', '包含 note_tags 的高级查询失败，自动退回基础单表查询: $e');
        try {
          // 防御性回退：如果不允许查 note_tags（RLS未开或表结构异常），则只查 notes 主表
          final res = await _supabase.from('notes')
              .select('*')
              .inFilter('id', chunk)
              .eq('user_id', userId)
              .timeout(const Duration(seconds: 15));
          cloudUpdates = res as List<dynamic>;
        } catch (innerError) {
          _SyncLogger.error('PULL', '基础查询也失败了，跳过本批次', innerError);
          continue;
        }
      }

      for (var map in cloudUpdates) {
        try {
          // 容错提取 tags：如果回退到了基础查询，这里会是 null
          final rawTags = map['note_tags'] as List<dynamic>?;
          final List<String> tagIds = rawTags != null ? rawTags.map((t) => t['tag_id'].toString()).toList() : [];

          final updatedNote = Note(
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
          );

          // 🌟 使用 saveNoteFromSync 保留云端 updatedAt 时间戳
          await _noteRepo!.saveNoteFromSync(updatedNote);
          pulled.add(updatedNote);
        } catch (e) {
          _SyncLogger.error('PULL', '解析单条笔记失败 [id: ${map['id']}]', e);
        }
      }
    }
    _SyncLogger.info('PULL', '成功拉取 ${pulled.length} 条 Note 内容及关系');
    return pulled;
  }

  // =========================================================================
  // 🌟 V2: 笔记推送与关系插入 (含防御降级)
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
        await _supabase.from('notes').upsert(payloads).timeout(const Duration(seconds: 15));
      } catch (e) {
        // 🌟 降级策略：如果包含 is_private 字段失败，尝试不包含
        _SyncLogger.warn('PUSH', '包含 is_private 推送失败，尝试降级推送: $e');
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
          await _supabase.from('notes').upsert(legacyPayloads).timeout(const Duration(seconds: 15));
          _SyncLogger.info('PUSH', '降级推送成功（不含 is_private）');
        } catch (legacyError) {
          _SyncLogger.error('PUSH', '笔记主表推送失败（降级也失败），已中止', legacyError);
          return [];
        }
      }

      // 隔离标签关系的推送，避免拖累笔记主表
      for (var note in pushedNotes) {
        try {
          await _supabase.from('note_tags').delete().eq('note_id', note.id);
          if (note.tagIds.isNotEmpty) {
            final tagPayloads = note.tagIds.map((tagId) => {'note_id': note.id, 'tag_id': tagId}).toList();
            await _supabase.from('note_tags').insert(tagPayloads);
          }
        } catch (e) {
          _SyncLogger.warn('PUSH', '为笔记 [${note.title}] 绑定标签失败 (请检查 RLS 权限)');
        }
      }
      _SyncLogger.info('PUSH', '成功推送 ${payloads.length} 条 Note 至云端');
    }
    return pushedNotes;
  }

  // =========================================================================
  // 🌟 3. 待办同步全链路 (完整保留)
  // =========================================================================
  Future<void> syncTodos({Function()? onSyncComplete}) async {
    if (_todoRepo == null || _supabase.auth.currentUser == null) return;

    _SyncLogger.info('TODO', '====== 🚀 启动待办同步管线 ======');
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = _supabase.auth.currentUser!.id;

      await _processLocalDeletions(prefs, 'todos', _deletedTodosKey);

      final lastSyncStr = prefs.getString(_lastTodoSyncKey);
      final lastSyncTime = lastSyncStr != null ? DateTime.parse(lastSyncStr) : null;

      final cloudMetadata = await _fetchCloudMetadata('todos', currentUserId);
      final localMetaMap = await _todoRepo!.getAllTodosMetadata();

      final plan = _reconcileData(
        localMetaMap: localMetaMap,
        cloudMetadata: cloudMetadata,
        lastSyncTime: lastSyncTime,
      );

      if (plan.toPull.isNotEmpty) await _pullTodos(plan.toPull, currentUserId, localMetaMap.keys.toSet());
      if (plan.toPush.isNotEmpty) await _pushTodos(plan.toPush, currentUserId);

      for (var id in plan.toDeleteLocally) {
        await _todoRepo!.deleteTodo(id);
        _SyncLogger.info('TODO', '👻 成功抹除本地幽灵待办: $id');
      }

      await prefs.setString(_lastTodoSyncKey, DateTime.now().toUtc().toIso8601String());
      if (onSyncComplete != null) onSyncComplete();

      _SyncLogger.info('TODO', '====== ✅ 待办同步管线完美收官 ======');
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
    _SyncLogger.info('PULL', '成功拉取 $pullCount 条 Todo 内容');
  }

  Future<void> _pushTodos(List<String> idsToPush, String userId) async {
    List<Map<String, dynamic>> payloads = [];
    for (var id in idsToPush) {
      final fullTodo = await _todoRepo!.getTodoById(id);
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
          'user_id': userId,
          'sub_tasks': fullTodo.subTasks.map((st) => st.toMap()).toList(),
        });
      }
    }
    if (payloads.isNotEmpty) {
      await _supabase.from('todos').upsert(payloads).timeout(const Duration(seconds: 15));
      _SyncLogger.info('PUSH', '成功推送 ${payloads.length} 条 Todo 至云端');
    }
  }


  // =========================================================================
  // 🌟 核心对比算法
  // =========================================================================
  _SyncPlan _reconcileData({
    required Map<String, DateTime> localMetaMap,
    required Map<String, DateTime> cloudMetadata,
    required DateTime? lastSyncTime,
  }) {
    final toPull = <String>[];
    final toPush = <String>[];
    final toDeleteLocally = <String>[];

    for (var cloudMeta in cloudMetadata.entries) {
      final cloudId = cloudMeta.key;
      final cloudTime = cloudMeta.value;
      final localTime = localMetaMap[cloudId];

      if (localTime == null) {
        toPull.add(cloudId);
      } else {
        if (cloudTime.difference(localTime).inSeconds.abs() <= _timeBuffer.inSeconds) continue;

        if (cloudTime.isAfter(localTime)) {
          toPull.add(cloudId);
        } else {
          toPush.add(cloudId);
        }
      }
    }

    for (var localMeta in localMetaMap.entries) {
      final localId = localMeta.key;
      final localTime = localMeta.value;

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

  Future<Map<String, DateTime>> _fetchCloudMetadata(String table, String userId) async {
    try {
      final response = await _supabase.from(table).select('id, updated_at').eq('user_id', userId).timeout(const Duration(seconds: 15));
      final data = response as List<dynamic>;
      _SyncLogger.info('META', '从云端 [$table] 发现 ${data.length} 条记录');
      return {for (var item in data) item['id'].toString(): DateTime.parse(item['updated_at'].toString()).toLocal()};
    } catch (e) {
      _SyncLogger.error('META', '拉取 [$table] 元数据超时或失败', e);
      return {};
    }
  }

  Future<void> _processLocalDeletions(SharedPreferences prefs, String table, String key) async {
    final deletedIds = prefs.getStringList(key) ?? [];
    if (deletedIds.isEmpty) return;
    try {
      await _supabase.from(table).delete().inFilter('id', deletedIds).timeout(const Duration(seconds: 15));
      await prefs.setStringList(key, []);
      _SyncLogger.info('TRASH', '成功清空 [$table] 云端废纸篓: ${deletedIds.length} 条');
    } catch (e) {
      _SyncLogger.error('TRASH', '清理 [$table] 废纸篓失败', e);
    }
  }
}

class _SyncPlan {
  final List<String> toPull;
  final List<String> toPush;
  final List<String> toDeleteLocally;

  _SyncPlan({required this.toPull, required this.toPush, required this.toDeleteLocally});
}