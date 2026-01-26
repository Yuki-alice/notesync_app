import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import '../../core/repositories/todo_repository.dart';
import '../../models/todo.dart';

class TodosProvider with ChangeNotifier {
  final TodoRepository _repository;
  List<Todo> _todos = [];
  final Uuid _uuid = const Uuid();

  TodosProvider(this._repository) {
    loadTodos();
  }

  List<Todo> get todos => _todos;

  void loadTodos() {
    _todos = _repository.getAllTodos();
    // 排序逻辑：未完成的按自定义顺序排，已完成的排最后
    _todos.sort((a, b) {
      if (a.isCompleted == b.isCompleted) {
        return a.sortOrder.compareTo(b.sortOrder);
      }
      return a.isCompleted ? 1 : -1;
    });
    notifyListeners();
  }

  Future<void> addTodo({
    required String title,
    String description = '',
    DateTime? dueDate,
  }) async {
    // 获取当前最小的 sortOrder，新添加的排在最前面
    final minSortOrder = _todos.isEmpty ? 0.0 : _todos.map((e) => e.sortOrder).reduce(min);

    final todo = Todo(
      id: _uuid.v4(),
      title: title,
      description: description,
      dueDate: dueDate,
      isCompleted: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      sortOrder: minSortOrder - 1.0,
    );

    await _repository.addTodo(todo);
    loadTodos();
  }

  Future<void> updateTodo(Todo todo) async {
    final updatedTodo = todo.copyWith(updatedAt: DateTime.now());
    await _repository.updateTodo(updatedTodo);
    loadTodos();
  }

  Future<void> deleteTodo(String id) async {
    await _repository.deleteTodo(id);
    loadTodos();
  }

  Future<void> toggleTodoStatus(String id) async {
    await _repository.toggleTodoStatus(id);
    loadTodos();
  }

  // 拖拽排序逻辑 (保留)
  Future<void> reorderTodos(int oldIndex, int newIndex) async {
    final incompleteTodos = _todos.where((t) => !t.isCompleted).toList();

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = incompleteTodos.removeAt(oldIndex);
    incompleteTodos.insert(newIndex, item);

    for (int i = 0; i < incompleteTodos.length; i++) {
      final t = incompleteTodos[i];
      final newOrder = i.toDouble();
      if (t.sortOrder != newOrder) {
        await _repository.updateTodo(t.copyWith(sortOrder: newOrder));
      }
    }
    loadTodos();
  }

  List<Todo> searchTodos(String query) {
    return _repository.searchTodos(query);
  }
}