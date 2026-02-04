import 'package:hive_flutter/hive_flutter.dart';
import '../../models/note.dart';
import '../../models/todo.dart';

class SimpleDatabaseService {
  static const String noteBoxName = 'notes';
  static const String todoBoxName = 'todos';

  late Box<Note> _noteBox;
  late Box<Todo> _todoBox;

  Box<Note> get noteBox => _noteBox;
  Box<Todo> get todoBox => _todoBox;

  /// 初始化数据库
  /// 包含 Hive 初始化、Adapter 注册和 Box 打开
  Future<void> init() async {
    await Hive.initFlutter();

    // 注册 Adapters (防止重复注册)
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(NoteAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TodoAdapter());
    }

    // 安全打开 Box (带容错机制)
    _noteBox = await _openBoxWithFallback<Note>(noteBoxName);
    _todoBox = await _openBoxWithFallback<Todo>(todoBoxName);
  }

  /// 尝试打开 Box，如果失败（如数据损坏），则删除旧数据并重新创建
  Future<Box<T>> _openBoxWithFallback<T>(String boxName) async {
    try {
      return await Hive.openBox<T>(boxName);
    } catch (e) {
      // 🛑 严重错误：数据可能已损坏
      print('Database Error ($boxName): $e. Attempting recovery...');
      try {
        // 尝试删除本地文件
        await Hive.deleteBoxFromDisk(boxName);
        // 重试打开
        return await Hive.openBox<T>(boxName);
      } catch (e2) {
        // 二次失败，抛出致命异常
        throw Exception('Critical Database Failure: Unable to recover box $boxName. $e2');
      }
    }
  }
}