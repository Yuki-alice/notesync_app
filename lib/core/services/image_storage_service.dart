import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

class ImageStorageService {
  final Uuid _uuid = const Uuid();

  // 获取应用文档目录下的 'images' 子目录
  Future<Directory> _getImagesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(path.join(appDir.path, 'note_images'));

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  // 保存图片文件到本地沙盒，返回本地路径
  Future<String> saveImage(File imageFile) async {
    final imagesDir = await _getImagesDirectory();
    // 生成唯一文件名，保留原扩展名
    final extension = path.extension(imageFile.path);
    final fileName = '${_uuid.v4()}$extension';
    final savedPath = path.join(imagesDir.path, fileName);

    // 复制文件
    await imageFile.copy(savedPath);
    return savedPath;
  }

  // 删除本地图片
  Future<void> deleteImage(String localPath) async {
    final file = File(localPath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}