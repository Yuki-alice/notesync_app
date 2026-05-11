import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/note.dart';
import '../../models/todo.dart';
import '../../models/category.dart';
import '../../models/tag.dart';

class SimpleDatabaseService {
  late Isar _isar;

  Isar get isar => _isar;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();

    _isar = await Isar.open([
      NoteSchema,
      TodoSchema,
      CategorySchema,
      TagSchema,
    ], directory: dir.path);
  }

  /// 关闭 Isar 数据库连接，释放资源。
  Future<void> close() async {
    if (_isar.isOpen) {
      await _isar.close();
      debugPrint('[SimpleDatabaseService] Isar 数据库连接已关闭');
    } else {
      debugPrint('[SimpleDatabaseService] Isar 数据库未打开，跳过关闭');
    }
  }
}
