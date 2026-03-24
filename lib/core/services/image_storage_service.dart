import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/note.dart';

class ImageStorageService {
  static const String _imageDirName = 'note_images';

  Future<Directory> get _baseDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, _imageDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> saveImage(File imageFile) async {
    final dir = await _baseDir;
    final ext = p.extension(imageFile.path).toLowerCase();
    final fileName = '${const Uuid().v4()}$ext';
    final targetPath = p.join(dir.path, fileName);

    // 判断是否是移动端 (Android / iOS / macOS 官方支持压缩)
    final isMobileOrMac = Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

    if (isMobileOrMac && (ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp')) {
      if (kDebugMode) {
        print('🗜️ 开始压缩图片: ${imageFile.lengthSync() / 1024} KB');
      }

      try {
        final result = await FlutterImageCompress.compressAndGetFile(
          imageFile.absolute.path,
          targetPath,
          quality: 80,
          minWidth: 1920,
          minHeight: 1080,
        );

        if (result != null) {
          final compressedFile = File(result.path);
          if (kDebugMode) {
            print('✅ 压缩完成: ${compressedFile.lengthSync() / 1024} KB');
          }
        } else {
          // 压缩意外返回 null，回退到原样拷贝
          await imageFile.copy(targetPath);
        }
      } catch (e) {
        // 如果压缩过程出现任何未知的底层异常，也必须保证业务不中断，回退到拷贝
        if (kDebugMode) {
          print('⚠️ 压缩失败，回退到原图: $e');
        }
        await imageFile.copy(targetPath);
      }
    } else {
      // 🟢 Windows/Linux 桌面端，或者不支持压缩的格式（如 gif），直接原样拷贝！
      if (kDebugMode) {
        print('💻 当前平台或格式不执行压缩，原样保存');
      }
      await imageFile.copy(targetPath);
    }

    return '$_imageDirName/$fileName';
  }

  Future<File?> getLocalFile(String path) async {
    try {
      final file = File(path);
      if (file.isAbsolute) {
        if (await file.exists()) return file;
      }

      final appDir = await getApplicationDocumentsDirectory();

      // 🌟 免疫反斜杠：统理解析出纯粹的文件名
      final normalizedPath = path.replaceAll('\\', '/');
      final fileName = normalizedPath.split('/').last;

      final fullPath = p.join(appDir.path, _imageDirName, fileName);
      final localFile = File(fullPath);
      if (await localFile.exists()) return localFile;
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error resolving image path: $e');
      }
      return null;
    }
  }

  /// 删除本地图片
  Future<void> deleteImage(String path) async {
    final file = await getLocalFile(path);
    if (file != null && await file.exists()) {
      await file.delete();
    }
  }

  Future<void> cleanUpUnusedImages(List<Note> allNotes) async {
    try {
      final dir = await _baseDir;
      if (!await dir.exists()) return;

      // 🌟 1. 收集所有存活笔记中引用的【纯图片文件名】
      final Set<String> usedFileNames = {};

      for (var note in allNotes) {
        // 🚨 核心逻辑修复：如果笔记在废纸篓里 (isDeleted)，它的图片也必须被判定为垃圾！
        if (!note.isRichText || note.isDeleted) continue;

        try {
          final paths = Note.extractAllImagePaths(note.content);
          for (var path in paths) {
            // 🚨 核心逻辑修复：无论 Markdown 里存的是什么鬼路径，统一提纯为只有 "UUID.png" 的格式
            usedFileNames.add(path.replaceAll('\\', '/').split('/').last);
          }
        } catch (e) {
          continue;
        }
      }

      // 🌟 2. 遍历本地文件夹，利用纯文件名进行最精确的对比绞杀
      final entities = dir.listSync();
      for (var entity in entities) {
        if (entity is File) {
          final fileName = p.basename(entity.path);

          // 如果本地磁盘里的这个文件名，不在上面的使用列表中，直接处决！
          if (!usedFileNames.contains(fileName)) {
            if (kDebugMode) {
              print('🗑️ GC: 删除无用图片 -> $_imageDirName/$fileName');
            }
            await entity.delete();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Image GC Error: $e');
      }
    }
  }
}