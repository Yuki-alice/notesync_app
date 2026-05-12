// 图片上传下载与隐私图片同步
// 负责笔记图片资源的全链路同步，包括：
// - 普通图片和隐私图片（加密）的上传与下载
// - Auto-Heal 自动修复（本地丢失图片从云端找回）
// - 云端僵尸图片垃圾回收
// - attachments 表同步（迁移已有数据）
// - 隐私图片专用同步（解锁隐私空间时触发）

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/note_repository.dart';
import '../security/privacy_service.dart';
import '../storage/storage_quota_service.dart';
import '../../../models/user_quota.dart';
import '../../../models/note.dart';

import '../../constants/sync_constants.dart';
import 'sync_models.dart';

class SupabaseImageSync {
  final SupabaseClient _supabase;
  final NoteRepository? _noteRepo;

  SupabaseImageSync(this._supabase, this._noteRepo);

  // 隐私图片同步锁
  static bool _isPrivateImageSyncing = false;
  static DateTime? _lastPrivateImageSyncTime;
  static const Duration _minSyncInterval = Duration(seconds: 10);

  // 🌟 优化：attachments 表同步标志位，只执行一次
  static bool _hasSyncedAttachmentsTable = false;

  // =========================================================================
  // 隐私图片专用同步 - 在解锁隐私空间时调用
  // =========================================================================
  Future<void> syncPrivateImagesOnly() async {
    if (_noteRepo == null) return;
    if (_supabase.auth.currentUser == null) {
      SyncLogger.warn('IMAGE', '未登录，中止隐私图片同步');
      return;
    }

    // 🌟 优化：防止重复同步
    if (_isPrivateImageSyncing) {
      SyncLogger.info('IMAGE', '隐私图片同步正在进行中，跳过重复调用');
      return;
    }

    // 🌟 优化：检查同步间隔
    if (_lastPrivateImageSyncTime != null) {
      final timeSinceLastSync = DateTime.now().difference(_lastPrivateImageSyncTime!);
      if (timeSinceLastSync < _minSyncInterval) {
        SyncLogger.info('IMAGE', '距离上次同步仅 ${timeSinceLastSync.inSeconds} 秒，跳过本次同步');
        return;
      }
    }

    final privacy = PrivacyService();
    if (!privacy.isUnlocked) {
      SyncLogger.warn('IMAGE', '隐私空间未解锁，跳过隐私图片同步');
      return;
    }

    _isPrivateImageSyncing = true;
    _lastPrivateImageSyncTime = DateTime.now();

    SyncLogger.info('IMAGE', '====== 🔐 启动隐私图片专用同步 ======');
    try {
      // 只获取隐私笔记
      final allNotes = _noteRepo.getAllNotes();
      final privateNotes = allNotes.where((n) => n.isPrivate && !n.isDeleted).toList();

      if (privateNotes.isEmpty) {
        SyncLogger.info('IMAGE', '没有隐私笔记需要同步图片');
        return;
      }

      SyncLogger.info('IMAGE', '发现 ${privateNotes.length} 条隐私笔记，开始同步图片');

      // 1. 先下载缺失的隐私图片（从云端拉取）
      await downloadImages(privateNotes);

      // 2. 再上传本地隐私图片到云端
      await uploadImages(privateNotes);

      SyncLogger.info('IMAGE', '====== ✅ 隐私图片同步完成 ======');
    } catch (e) {
      SyncLogger.error('IMAGE', '隐私图片同步失败', e);
    } finally {
      // 🌟 优化：释放同步锁
      _isPrivateImageSyncing = false;
    }
  }

  // =========================================================================
  // 图片上传 (含配额检查)
  // =========================================================================
  Future<void> uploadImages(List<Note> pushedNotes) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      SyncLogger.warn('IMAGE', '用户未登录，跳过图片上传');
      return;
    }
    final userId = user.id;

    final storage = _supabase.storage.from(imageBucket);
    final appDir = await getApplicationDocumentsDirectory();

    // 🌟 收集需要上传的图片，标记是否属于隐私笔记
    final Map<String, bool> fileNameToIsPrivate = {};
    int totalImageBytes = 0;
    // 缓存图片文件大小，避免同一文件被多篇笔记引用时重复读取文件系统
    final Map<String, int> imageSizeCache = {};

    for (var note in pushedNotes) {
      // 优先使用 imagePaths 字段（如果存在）
      if (note.imagePaths.isNotEmpty) {
        for (var path in note.imagePaths) {
          final fileName = path.replaceAll('\\', '/').split('/').last;
          fileNameToIsPrivate[fileName] = note.isPrivate;
          // 使用缓存计算图片大小
          if (imageSizeCache.containsKey(fileName)) {
            totalImageBytes += imageSizeCache[fileName]!;
          } else {
            final file = File(p.join(appDir.path, 'note_images', fileName));
            if (await file.exists()) {
              final size = await file.length();
              imageSizeCache[fileName] = size;
              totalImageBytes += size;
            }
          }
        }
      } else {
        // 从内容中提取图片路径（兼容旧数据）
        // 🌟 隐私笔记需要解密后才能提取图片路径
        String content = note.content;
        if (note.isPrivate && content.startsWith('AES_V1::')) {
          content = PrivacyService().decryptText(content);
          // 如果解密失败，跳过此笔记的图片上传
          if (content.contains('🔒') || content.contains('❌')) {
            SyncLogger.warn('IMAGE', '隐私笔记 ${note.id} 解密失败，跳过图片上传');
            continue;
          }
        }
        final paths = Note.extractAllImagePaths(content);
        for (var path in paths) {
          final fileName = path.replaceAll('\\', '/').split('/').last;
          fileNameToIsPrivate[fileName] = note.isPrivate;
          // 使用缓存计算图片大小
          if (imageSizeCache.containsKey(fileName)) {
            totalImageBytes += imageSizeCache[fileName]!;
          } else {
            final file = File(p.join(appDir.path, 'note_images', fileName));
            if (await file.exists()) {
              final size = await file.length();
              imageSizeCache[fileName] = size;
              totalImageBytes += size;
            }
          }
        }
      }
    }

    if (fileNameToIsPrivate.isEmpty) {
      SyncLogger.info('IMAGE', '没有需要上传的图片');
      return;
    }

    // 🌟 配额检查：检查图片存储空间
    if (totalImageBytes > 0) {
      final quotaService = StorageQuotaService();
      final quotaCheck = await quotaService.checkStorageQuota(
        requiredBytes: totalImageBytes,
        resourceType: ResourceType.image,
      );

      if (!quotaCheck.canProceed) {
        SyncLogger.warn('QUOTA', '图片存储配额不足，跳过上传: ${quotaCheck.message}');
        // 图片配额不足不抛出异常，只记录日志，避免阻断整个同步流程
        return;
      }

      // 检查图片数量配额
      final imageCountCheck = await quotaService.checkImageCountQuota(
        additionalImages: fileNameToIsPrivate.length,
      );

      if (!imageCountCheck.canProceed) {
        SyncLogger.warn('QUOTA', '图片数量配额不足，跳过上传: ${imageCountCheck.message}');
        return;
      }
    }

    SyncLogger.info('IMAGE', '准备上传 ${fileNameToIsPrivate.length} 张图片，其中隐私图片: ${fileNameToIsPrivate.values.where((v) => v).length} 张');

    final privacy = PrivacyService();
    SyncLogger.info('IMAGE', 'PrivacyService 状态: isUnlocked=${privacy.isUnlocked}');

    // 🌟 优化：批量获取云端已有文件列表（Set 查找 O(1)）
    final cloudFiles = await _getCloudFileList();
    SyncLogger.info('IMAGE', '云端已有 ${cloudFiles.length} 个文件');

    // 🌟 优化：预过滤，跳过云端已存在的文件，避免为每个文件创建异步任务
    final filesToUpload = <MapEntry<String, bool>>[];
    int skippedCount = 0;
    for (final entry in fileNameToIsPrivate.entries) {
      final fileName = entry.key;
      final isPrivate = entry.value;
      final cloudFileName = isPrivate ? '$fileName.enc' : fileName;
      if (cloudFiles.contains(cloudFileName)) {
        skippedCount++;
      } else {
        filesToUpload.add(entry);
      }
    }
    SyncLogger.info('IMAGE', '跳过 $skippedCount 张已存在的图片，需上传 ${filesToUpload.length} 张');

    if (filesToUpload.isEmpty) {
      SyncLogger.info('IMAGE', '图片附件上传完成: 上传 0 张, 跳过 $skippedCount 张');
      return;
    }

    int uploadedCount = 0;

    List<Future<void>> uploadTasks = filesToUpload.map((entry) async {
      final fileName = entry.key;
      final isPrivate = entry.value;

      try {
        final localFile = File(p.join(appDir.path, 'note_images', fileName));
        if (await localFile.exists()) {
          if (isPrivate && privacy.isUnlocked) {
            // 🌟 隐私笔记图片：读取、加密、写入临时文件、上传
            // 检查云端是否已有普通版本（笔记从普通变为私密时）
            if (cloudFiles.contains(fileName)) {
              SyncLogger.info('IMAGE', '检测到云端有普通版本，删除后上传加密版本: $fileName');
              try {
                await storage.remove([fileName]);
                SyncLogger.info('IMAGE', '已删除云端普通版本: $fileName');
              } catch (e) {
                SyncLogger.warn('IMAGE', '删除云端普通版本失败: $e');
              }
            }
            SyncLogger.info('IMAGE', '正在加密上传隐私图片: $fileName');
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
            SyncLogger.info('IMAGE', '隐私图片上传成功: $encryptedFileName');

            // 🌟 记录到 attachments 表
            await _recordAttachment(userId, fileName, encryptedFileName, await localFile.length(), isEncrypted: true);
          } else if (isPrivate && !privacy.isUnlocked) {
            SyncLogger.warn('IMAGE', '隐私图片 $fileName 跳过上传：PrivacyService 未解锁');
          } else {
            // 🌟 普通笔记图片：直接上传
            // 检查云端是否已有加密版本（笔记从私密变为普通时）
            final encryptedFileName = '$fileName.enc';
            if (cloudFiles.contains(encryptedFileName)) {
              SyncLogger.info('IMAGE', '检测到云端有加密版本，删除后上传普通版本: $fileName');
              try {
                await storage.remove([encryptedFileName]);
                SyncLogger.info('IMAGE', '已删除云端加密版本: $encryptedFileName');
                // 删除 attachments 表中的加密记录
                await _deleteAttachmentRecord(userId, fileName);
              } catch (e) {
                SyncLogger.warn('IMAGE', '删除云端加密版本失败: $e');
              }
            }
            SyncLogger.info('IMAGE', '正在上传普通图片: $fileName');
            await storage.upload(fileName, localFile, fileOptions: const FileOptions(upsert: true));
            uploadedCount++;
            SyncLogger.info('IMAGE', '普通图片上传成功: $fileName');

            // 🌟 记录到 attachments 表
            await _recordAttachment(userId, fileName, fileName, await localFile.length(), isEncrypted: false);
          }
        } else {
          SyncLogger.warn('IMAGE', '本地图片不存在: ${localFile.path}');
        }
      } catch (e) {
        SyncLogger.warn('IMAGE', '上传图片跳过 $fileName: $e');
      }
    }).toList();

    await Future.wait(uploadTasks);
    SyncLogger.info('IMAGE', '图片附件上传完成: 上传 $uploadedCount 张, 跳过 $skippedCount 张');
  }

  // =========================================================================
  // 图片下载 (Auto-Heal)
  // =========================================================================
  Future<void> downloadImages(List<Note> allNotes) async {
    final storage = _supabase.storage.from(imageBucket);
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
    final int maxConcurrent = hasPrivateImages
        ? SyncConstants.imageDownloadConcurrencyPrivate
        : SyncConstants.imageDownloadConcurrencyNormal;
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
              SyncLogger.info('IMAGE', '正在下载隐私图片: $encryptedFileName');
              final encryptedBytes = await storage.download(encryptedFileName);
              final decryptedBytes = privacy.decryptFileBytes(encryptedBytes);
              await localFile.parent.create(recursive: true);
              await localFile.writeAsBytes(decryptedBytes);
              SyncLogger.info('IMAGE', '隐私图片下载成功: $fileName');
              recoveredCount++;
            } else if (isPrivate && !privacy.isUnlocked) {
              SyncLogger.warn('IMAGE', '隐私图片 $fileName 跳过下载：PrivacyService 未解锁');
            } else {
              // 普通笔记图片：直接下载
              SyncLogger.info('IMAGE', '正在下载普通图片: $fileName');
              final bytes = await storage.download(fileName);
              await localFile.parent.create(recursive: true);
              await localFile.writeAsBytes(bytes);
              SyncLogger.info('IMAGE', '普通图片下载成功: $fileName');
              recoveredCount++;
            }
          }
        } catch (e) {
          SyncLogger.warn('IMAGE', '下载图片失败 $fileName: $e');
        }
      });
      await Future.wait(tasks);
    }

    if (recoveredCount > 0) {
      SyncLogger.info('IMAGE', '✨ 自动修复引擎：成功从云端找回 $recoveredCount 张本地丢失的图片');
    }
  }

  // =========================================================================
  // 云端图片垃圾回收
  // =========================================================================
  Future<void> cleanUpCloudImages(List<Note> allNotes) async {
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

      final storage = _supabase.storage.from(imageBucket);
      final List<FileObject> cloudFiles = await storage.list(searchOptions: SearchOptions(limit: SyncConstants.cloudFileListLimit));

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
        SyncLogger.info('CLOUD-GC', '🧹 成功绞杀云端僵尸图片: ${orphanedFiles.length} 张');
      }
    } catch (e) {
      SyncLogger.error('CLOUD-GC', '云端图片垃圾回收失败', e);
    }
  }

  // =========================================================================
  // Attachments 表同步（迁移已有云端图片数据）
  // =========================================================================
  Future<void> syncAttachmentsTable(List<Note> allNotes) async {
    // 🌟 优化：只执行一次，避免每次同步都重复迁移
    if (_hasSyncedAttachmentsTable) {
      SyncLogger.info('ATTACHMENT', 'attachments 表已同步，跳过');
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final userId = user.id;

    try {
      SyncLogger.info('ATTACHMENT', '====== 开始同步 attachments 表 ======');

      // 1. 获取云端所有文件列表
      final cloudFiles = await _getCloudFileList();
      if (cloudFiles.isEmpty) {
        SyncLogger.info('ATTACHMENT', '云端没有文件，跳过同步');
        return;
      }

      // 2. 获取已记录在 attachments 表的文件
      final existingAttachments = await _supabase
          .from('attachments')
          .select('file_path')
          .eq('user_id', userId);

      final existingPaths = <String>{};
      if (existingAttachments != null) {
        for (final att in existingAttachments) {
          final path = att['file_path'] as String?;
          if (path != null) {
            existingPaths.add(path.split('/').last); // 提取文件名
          }
        }
      }

      SyncLogger.info('ATTACHMENT', '云端文件: ${cloudFiles.length} 个，已记录: ${existingPaths.length} 个');

      // 3. 找出需要迁移的文件（在云端但不在 attachments 表）
      final filesToMigrate = cloudFiles.where((f) => !existingPaths.contains(f)).toList();
      if (filesToMigrate.isEmpty) {
        SyncLogger.info('ATTACHMENT', '所有文件已同步，无需迁移');
        return;
      }

      SyncLogger.info('ATTACHMENT', '需要迁移 ${filesToMigrate.length} 个文件');

      // 4. 收集所有笔记中的图片映射（用于确定 note_id）
      final Map<String, String> fileToNoteId = {};
      for (final note in allNotes) {
        if (note.isDeleted) continue;

        List<String> imagePaths = [];
        if (note.imagePaths.isNotEmpty) {
          imagePaths = note.imagePaths;
        } else {
          String content = note.content;
          if (note.isPrivate && content.startsWith('AES_V1::')) {
            content = PrivacyService().decryptText(content);
            if (content.contains('🔒') || content.contains('❌')) continue;
          }
          imagePaths = Note.extractAllImagePaths(content);
        }

        for (final path in imagePaths) {
          final fileName = path.replaceAll('\\', '/').split('/').last;
          // 处理加密文件名（去掉 .enc 后缀）
          final baseName = fileName.endsWith('.enc')
              ? fileName.substring(0, fileName.length - 4)
              : fileName;
          fileToNoteId[baseName] = note.id;
          fileToNoteId[fileName] = note.id; // 同时记录带 .enc 的版本
        }
      }

      // 5. 批量迁移文件
      int migratedCount = 0;
      int failedCount = 0;

      for (final fileName in filesToMigrate) {
        try {
          // 获取文件信息
          final isEncrypted = fileName.endsWith('.enc');
          final baseName = isEncrypted
              ? fileName.substring(0, fileName.length - 4)
              : fileName;

          // 尝试获取文件大小（从 Storage API）
          int fileSize = 0;
          try {
            final fileInfo = await _supabase.storage
                .from(imageBucket)
                .info(fileName);
            fileSize = fileInfo.size ?? 0;
          } catch (e) {
            // 如果获取不到大小，使用默认值
            fileSize = 0;
          }

          // 确定文件类型
          final ext = baseName.split('.').last.toLowerCase();
          String fileType = 'image/jpeg';
          if (ext == 'png') fileType = 'image/png';
          else if (ext == 'gif') fileType = 'image/gif';
          else if (ext == 'webp') fileType = 'image/webp';

          // 确定关联的 note_id
          final noteId = fileToNoteId[baseName];

          // 插入 attachments 表
          await _supabase.from('attachments').insert({
            'user_id': userId,
            'note_id': noteId,
            'file_path': '$imageBucket/$fileName',
            'file_size': fileSize,
            'file_type': fileType,
          });

          migratedCount++;
          SyncLogger.info('ATTACHMENT', '已迁移: $fileName (${_formatBytes(fileSize)})');
        } catch (e) {
          failedCount++;
          SyncLogger.warn('ATTACHMENT', '迁移失败 $fileName: $e');
        }
      }

      SyncLogger.info('ATTACHMENT', '====== 迁移完成: 成功 $migratedCount 个, 失败 $failedCount 个 ======');
      _hasSyncedAttachmentsTable = true;
    } catch (e) {
      SyncLogger.error('ATTACHMENT', '同步 attachments 表失败', e);
    }
  }

  // =========================================================================
  // 内部工具方法
  // =========================================================================

  /// 获取云端文件列表
  Future<Set<String>> _getCloudFileList() async {
    try {
      final storage = _supabase.storage.from(imageBucket);
      final files = await storage.list(searchOptions: SearchOptions(limit: SyncConstants.cloudFileListLimit));
      return files.map((f) => f.name).toSet();
    } catch (e) {
      SyncLogger.warn('IMAGE', '获取云端文件列表失败: $e');
      return {};
    }
  }

  /// 记录附件到数据库
  Future<void> _recordAttachment(
    String userId,
    String originalFileName,
    String storageFileName,
    int fileSize, {
    required bool isEncrypted,
    String? noteId,
  }) async {
    try {
      // 提取文件扩展名作为文件类型
      final ext = originalFileName.split('.').last.toLowerCase();
      String fileType = 'image/jpeg';
      if (ext == 'png') fileType = 'image/png';
      else if (ext == 'gif') fileType = 'image/gif';
      else if (ext == 'webp') fileType = 'image/webp';

      await _supabase.from('attachments').insert({
        'user_id': userId,
        'note_id': noteId,
        'file_path': '$imageBucket/$storageFileName',
        'file_size': fileSize,
        'file_type': fileType,
      });

      SyncLogger.info('ATTACHMENT', '记录附件成功: $originalFileName (${_formatBytes(fileSize)})');
    } catch (e) {
      SyncLogger.warn('ATTACHMENT', '记录附件失败 $originalFileName: $e');
    }
  }

  /// 删除附件记录
  Future<void> _deleteAttachmentRecord(String userId, String fileName) async {
    try {
      await _supabase
          .from('attachments')
          .delete()
          .eq('user_id', userId)
          .eq('file_path', '$imageBucket/$fileName');
      SyncLogger.info('ATTACHMENT', '删除附件记录: $fileName');
    } catch (e) {
      SyncLogger.warn('ATTACHMENT', '删除附件记录失败 $fileName: $e');
    }
  }

  /// 格式化字节数
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
  }
}
