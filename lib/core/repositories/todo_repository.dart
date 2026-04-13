import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../../models/todo.dart';

class TodoRepository {
  final Isar _isar;

  TodoRepository(this._isar);

  Future<void> init() async {}

  Todo? getTodoById(String id) {
    return _isar.todos.where().idEqualTo(id).findFirstSync();
  }

  Map<String, DateTime> getAllTodosMetadata() {
    final todos = _isar.todos.where().findAllSync();
    return {for (var todo in todos) todo.id: todo.updatedAt};
  }

  List<Todo> getAllTodos() {
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
  }

  Future<void> addTodo(Todo todo) async {
    await _isar.writeTxn(() async {
      await _isar.todos.put(todo);
    });
  }

  Future<void> updateTodo(Todo todo) async {
    await _isar.writeTxn(() async {
      await _isar.todos.put(todo);
    });
  }

  Future<void> deleteTodo(String id) async {
    await _isar.writeTxn(() async {
      await _isar.todos.where().idEqualTo(id).deleteAll();
    });
  }

  Future<List<Todo>> searchTodos(String query, String? categoryId) async {
    var q = _isar.todos.filter().isDeletedEqualTo(false);

    if (categoryId != null && categoryId.isNotEmpty) {
      q = q.categoryIdEqualTo(categoryId);
    }

    if (query.trim().isNotEmpty) {
      q = q.group((q) => q.titleContains(query, caseSensitive: false)
          .or()
          .descriptionContains(query, caseSensitive: false));
    }

    return await q.sortByIsCompleted().thenByCreatedAtDesc().findAll();
  }

  // 🌟 暴露给 Provider 用的响应式流
  Stream<void> watchTodosChanged() {
    return _isar.todos.watchLazy(fireImmediately: true);
  }
}