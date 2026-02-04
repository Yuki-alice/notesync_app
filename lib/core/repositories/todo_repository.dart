import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../models/todo.dart';

class TodoRepository {
  final Box<Todo> _box;

  TodoRepository(this._box);

  Future<void> init() async {}

  List<Todo> getAllTodos() {
    try {
      final todos = _box.values.toList();
      todos.sort((a, b) {
        if (a.isCompleted == b.isCompleted) {
          // 同状态下，后创建的在前面 (或者按 needsAction 排)
          return b.createdAt.compareTo(a.createdAt);
        }
        // 未完成(false) 排在 完成(true) 前面
        return a.isCompleted ? 1 : -1;
      });
      return todos;
    } catch (e) {
      debugPrint('Repo Error (getAllTodos): $e');
      return [];
    }
  }

  Future<void> addTodo(Todo todo) async {
    try {
      await _box.put(todo.id, todo);
    } catch (e) {
      debugPrint('Repo Error (addTodo): $e');
      rethrow;
    }
  }

  Future<void> updateTodo(Todo todo) async {
    try {
      await _box.put(todo.id, todo);
    } catch (e) {
      debugPrint('Repo Error (updateTodo): $e');
      rethrow;
    }
  }

  Future<void> deleteTodo(String id) async {
    try {
      await _box.delete(id);
    } catch (e) {
      debugPrint('Repo Error (deleteTodo): $e');
      rethrow;
    }
  }

  Future<void> toggleTodoStatus(String id) async {
    try {
      final todo = _box.get(id);
      if (todo != null) {
        final updatedTodo = todo.copyWith(
          isCompleted: !todo.isCompleted,
          updatedAt: DateTime.now(),
        );
        await _box.put(id, updatedTodo);
      }
    } catch (e) {
      debugPrint('Repo Error (toggleTodoStatus): $e');
      rethrow;
    }
  }

  List<Todo> searchTodos(String query) {
    if (query.isEmpty) return getAllTodos();
    try {
      final lowercaseQuery = query.toLowerCase();
      return _box.values
          .where((todo) => todo.title.toLowerCase().contains(lowercaseQuery))
          .toList();
    } catch (e) {
      debugPrint('Repo Error (searchTodos): $e');
      return [];
    }
  }
}