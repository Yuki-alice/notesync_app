import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../../models/todo.dart';
import '../services/performance/perf.dart';

class TodoRepository {
  final Isar _isar;

  TodoRepository(this._isar);

  Future<void> init() async {}

  Todo? getTodoById(String id) {
    return Perf.traceSync('repo.todo.getById', () {
      return _isar.todos.where().idEqualTo(id).findFirstSync();
    }, metadata: {'id': id});
  }

  Map<String, DateTime> getAllTodosMetadata() {
    return Perf.traceSync('repo.todo.getAllMetadata', () {
      final todos = _isar.todos.where().findAllSync();
      return {for (var todo in todos) todo.id: todo.updatedAt};
    });
  }

  List<Todo> getAllTodos() {
    return Perf.traceSync('repo.todo.getAll', () {
      try {
        final todos = _isar.todos.where().findAllSync();
        todos.sort((a, b) {
          if (a.isCompleted == b.isCompleted) {
            return b.createdAt.compareTo(a.createdAt);
          }
          return a.isCompleted ? 1 : -1;
        });
        return todos;
      } catch (e) {
        debugPrint('Repo Error (getAllTodos): $e');
        return [];
      }
    });
  }

  Future<void> addTodo(Todo todo) async {
    await Perf.trace('repo.todo.add', () => _isar.writeTxn(() async {
      await _isar.todos.put(todo);
    }));
  }

  Future<void> updateTodo(Todo todo) async {
    await Perf.trace('repo.todo.update', () => _isar.writeTxn(() async {
      todo.version += 1;
      todo.updatedAt = DateTime.now();
      await _isar.todos.put(todo);
    }));
  }

  /// 🌟 同步专用：批量保存待办（保留云端时间戳）
  Future<void> saveTodosFromSync(List<Todo> todos) async {
    if (todos.isEmpty) return;
    await Perf.trace('repo.todo.saveTodosFromSync', () async {
      // 🌟 优化：分批写入，每批 50 条，避免阻塞主线程
      const batchSize = 50;
      final totalBatches = (todos.length / batchSize).ceil();
      for (var i = 0; i < todos.length; i += batchSize) {
        final end = i + batchSize > todos.length ? todos.length : i + batchSize;
        final batch = todos.sublist(i, end);
        final batchIndex = (i / batchSize).floor() + 1;

        await _isar.writeTxn(() async {
          await _isar.todos.putAll(batch);
        });
        debugPrint('[SYNC] 待办批次写入完成: $batchIndex/$totalBatches (${batch.length} 条)');

        // 让出主线程，避免阻塞 UI
        await Future.delayed(Duration.zero);
      }
    });
  }

  Future<void> deleteTodo(String id) async {
    await Perf.trace('repo.todo.delete', () => _isar.writeTxn(() async {
      await _isar.todos.where().idEqualTo(id).deleteAll();
    }));
  }

  Future<List<Todo>> searchTodos(String query, String? categoryId) async {
    return await Perf.trace('repo.todo.search', () async {
      var q = _isar.todos.filter().isDeletedEqualTo(false);

      if (categoryId != null && categoryId.isNotEmpty) {
        q = q.categoryIdEqualTo(categoryId);
      }

      if (query.trim().isNotEmpty) {
        q = q.group((q) => q.titleContains(query, caseSensitive: false)
            .or()
            .descriptionContains(query, caseSensitive: false)
            .or()
            .subTasksElement((subQ) => subQ.titleContains(query, caseSensitive: false)));
      }

      return await q.sortByIsCompleted().thenByCreatedAtDesc().findAll();
    }, metadata: {'query': query, 'categoryId': categoryId});
  }

  // 🌟 暴露给 Provider 用的响应式流
  Stream<void> watchTodosChanged() {
    return _isar.todos.watchLazy(fireImmediately: true);
  }
}