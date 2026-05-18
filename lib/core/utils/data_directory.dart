import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 获取应用数据目录。
///
/// 开发模式 ([kDebugMode])：统一使用 AppData，避免 `flutter clean` 丢失数据。
/// 生产模式：优先 portable（exe 同级 `data/`），不可写则回退 AppData。
Future<String> getDataDirectory() async {
  if (kDebugMode) {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, 'Komorebi'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  final exeDir = p.dirname(Platform.resolvedExecutable);
  final portableDir = Directory(p.join(exeDir, 'data'));

  try {
    await portableDir.create(recursive: true);
    final testFile = File(p.join(portableDir.path, '.write_test'));
    await testFile.writeAsString('test');
    await testFile.delete();
    return portableDir.path;
  } catch (_) {
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, 'Komorebi'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }
}

/// 获取笔记图片存储目录。
Future<Directory> getImageDirectory() async {
  final dataDir = await getDataDirectory();
  final dir = Directory(p.join(dataDir, 'note_images'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

/// 获取头像存储目录。
Future<Directory> getAvatarDirectory() async {
  final dataDir = await getDataDirectory();
  final dir = Directory(p.join(dataDir, 'avatars'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}
