import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageStorageService {
  static const String _imageDirName = 'note_images';

  /// 获取图片存储的基础目录
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
    final ext = p.extension(imageFile.path);
    final fileName = '${const Uuid().v4()}$ext';

    // 复制文件到应用目录
    await imageFile.copy(p.join(dir.path, fileName));

    // 返回相对路径用于存储
    return p.join(_imageDirName, fileName);
  }

  /// 🟢 [关键方法] 根据相对路径获取完整的本地文件对象
  /// 作用：兼容旧数据的绝对路径，同时解析新数据的相对路径
  Future<File?> getLocalFile(String path) async {
    try {
      final file = File(path);

      // 1. 兼容旧数据：如果是绝对路径且文件存在，直接返回
      // (旧版本的笔记存的是绝对路径)
      if (file.isAbsolute) {
        if (await file.exists()) {
          return file;
        }
        // 如果绝对路径文件不存在，可能是因为迁移了设备，尝试按相对路径再找一次（防御性编程）
      }

      // 2. 处理新数据：拼接应用文档目录
      // (新版本的笔记存的是 note_images/xxx.jpg)
      final appDir = await getApplicationDocumentsDirectory();

      // 使用 path 包来安全拼接路径，避免斜杠问题
      final fullPath = p.join(appDir.path, path);
      final localFile = File(fullPath);

      if (await localFile.exists()) {
        return localFile;
      }

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
}