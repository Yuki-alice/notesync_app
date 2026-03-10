import 'dart:io';
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
      print('🗜️ 开始压缩图片: ${imageFile.lengthSync() / 1024} KB');

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
          print('✅ 压缩完成: ${compressedFile.lengthSync() / 1024} KB');
        } else {
          // 压缩意外返回 null，回退到原样拷贝
          await imageFile.copy(targetPath);
        }
      } catch (e) {
        // 如果压缩过程出现任何未知的底层异常，也必须保证业务不中断，回退到拷贝
        print('⚠️ 压缩失败，回退到原图: $e');
        await imageFile.copy(targetPath);
      }
    } else {
      // 🟢 Windows/Linux 桌面端，或者不支持压缩的格式（如 gif），直接原样拷贝！
      print('💻 当前平台或格式不执行压缩，原样保存');
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

      final normalizedPath = path.replaceAll('\\', '/');
      final fileName = normalizedPath.split('/').last;

      final fullPath = p.join(appDir.path, _imageDirName, fileName);
      final localFile = File(fullPath);
      if (await localFile.exists()) return localFile;
      return null;
    } catch (e) {
      print('Error resolving image path: $e');
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

      // 1. 收集所有笔记中引用的图片路径
      final Set<String> usedImagePaths = {};

      for (var note in allNotes) {
        if (!note.isRichText) continue;
        try {
          final paths = Note.extractAllImagePaths(note.content);
          usedImagePaths.addAll(paths);
        } catch (e) {
          continue;
        }
      }

      // 2. 遍历本地文件夹，删除不在引用列表中的文件
      final entities = dir.listSync();
      for (var entity in entities) {
        if (entity is File) {
          final fileName = p.basename(entity.path);
          // 构建相对路径格式 (跟存的时候一样)
          final relativePath = p.join(_imageDirName, fileName);

          // 如果该文件既没有被以相对路径引用，也没有被以绝对路径引用，则删除
          if (!usedImagePaths.contains(relativePath) &&
              !usedImagePaths.contains(entity.path)) {
            print('🗑️ GC: 删除无用图片 -> $relativePath');
            await entity.delete();
          }
        }
      }
    } catch (e) {
      print('Image GC Error: $e');
    }
  }
}