import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../models/note.dart';

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
    // 检查原始图片大小，超过 10MB 拒绝保存
    final originalSize = await imageFile.length();
    if (originalSize > 10 * 1024 * 1024) {
      throw Exception('图片过大（${(originalSize / 1024 / 1024).toStringAsFixed(1)}MB），单张图片不能超过 10MB');
    }

    final dir = await _baseDir;
    final ext = p.extension(imageFile.path).toLowerCase();
    final fileName = '${const Uuid().v4()}$ext';
    final targetPath = p.join(dir.path, fileName);

    // 判断是否是移动端 (Android / iOS / macOS 官方支持压缩)
    final isMobileOrMac = Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
    final isWindowsOrLinux = Platform.isWindows || Platform.isLinux;
    final isCompressibleFormat = ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp';

    if (isCompressibleFormat) {
      if (isMobileOrMac) {
        // 🟢 移动端使用 flutter_image_compress
        await _compressWithFlutterImageCompress(imageFile, targetPath);
      } else if (isWindowsOrLinux) {
        // 🟢 Windows/Linux 使用 image 库
        await _compressWithImageLibrary(imageFile, targetPath, ext);
      } else {
        // 其他平台原样拷贝
        await imageFile.copy(targetPath);
      }
    } else {
      // 🟢 不支持压缩的格式（如 gif），直接原样拷贝
      if (kDebugMode) {
        print('💻 格式不支持压缩，原样保存');
      }
      await imageFile.copy(targetPath);
    }

    return '$_imageDirName/$fileName';
  }

  /// 🗜️ 使用 flutter_image_compress 压缩（移动端）
  Future<void> _compressWithFlutterImageCompress(File imageFile, String targetPath) async {
    if (kDebugMode) {
      print('🗜️ 开始压缩图片: ${imageFile.lengthSync() / 1024} KB');
    }

    try {
      // quality 70 + 1280px 对笔记插图足够清晰，体积约 200-500KB
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1280,
        minHeight: 720,
      );

      if (result != null) {
        final compressedFile = File(result.path);
        if (kDebugMode) {
          print('✅ 压缩完成: ${compressedFile.lengthSync() / 1024} KB');
        }
      } else {
        await imageFile.copy(targetPath);
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ 压缩失败，回退到原图: $e');
      }
      await imageFile.copy(targetPath);
    }
  }

  /// 🗜️ 使用 image 库压缩（Windows/Linux）
  Future<void> _compressWithImageLibrary(File imageFile, String targetPath, String ext) async {
    if (kDebugMode) {
      print('🗜️ [Windows/Linux] 开始压缩图片: ${imageFile.lengthSync() / 1024} KB');
    }

    try {
      // 读取图片
      final bytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);

      if (originalImage == null) {
        if (kDebugMode) {
          print('⚠️ 无法解码图片，回退到原图');
        }
        await imageFile.copy(targetPath);
        return;
      }

      // 计算新尺寸（保持比例，最大边不超过 1280）
      int newWidth = originalImage.width;
      int newHeight = originalImage.height;
      const maxDimension = 1280;

      if (newWidth > maxDimension || newHeight > maxDimension) {
        if (newWidth > newHeight) {
          newHeight = (newHeight * maxDimension / newWidth).round();
          newWidth = maxDimension;
        } else {
          newWidth = (newWidth * maxDimension / newHeight).round();
          newHeight = maxDimension;
        }
      }

      // 调整大小，cubic 插值比 linear 更清晰
      final resizedImage = img.copyResize(
        originalImage,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.cubic,
      );

      // 编码并保存
      Uint8List? encodedBytes;
      if (ext == '.png') {
        encodedBytes = img.encodePng(resizedImage, level: 6); // 压缩级别 0-9
      } else {
        // jpg/jpeg/webp 都使用 jpeg 编码（image 库不支持 webp 编码）
        // quality 70 对笔记插图足够清晰，体积约 200-500KB
        encodedBytes = img.encodeJpg(resizedImage, quality: 70);
      }

      if (encodedBytes != null) {
        await File(targetPath).writeAsBytes(encodedBytes);
        final compressedSize = await File(targetPath).length();
        if (kDebugMode) {
          print('✅ [Windows/Linux] 压缩完成: ${compressedSize / 1024} KB (${newWidth}x${newHeight})');
        }
      } else {
        await imageFile.copy(targetPath);
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [Windows/Linux] 压缩失败，回退到原图: $e');
      }
      await imageFile.copy(targetPath);
    }
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