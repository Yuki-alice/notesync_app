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

  Future<void> toggleTodoStatus(String id) async {
    final todo = getTodoById(id);
    if (todo != null) {
      final updatedTodo = todo.copyWith(
        isCompleted: !todo.isCompleted,
        updatedAt: DateTime.now(),
      );
      await updateTodo(updatedTodo);
    }
  }
}