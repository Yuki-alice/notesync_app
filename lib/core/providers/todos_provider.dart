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

  // 🔴 修改：主列表只返回未删除的待办
  List<Todo> get todos => _todos.where((t) => !t.isDeleted).toList();

  // 🔴 新增：回收站列表
  List<Todo> get trashTodos => _todos.where((t) => t.isDeleted).toList();

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
    // 注意：只计算未删除的 todos 的 sortOrder
    final activeTodos = _todos.where((t) => !t.isDeleted);
    final minSortOrder = activeTodos.isEmpty ? 0.0 : activeTodos.map((e) => e.sortOrder).reduce(min);

    final todo = Todo(
      id: _uuid.v4(),
      title: title,
      description: description,
      dueDate: dueDate,
      isCompleted: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      sortOrder: minSortOrder - 1.0,
      isDeleted: false, // 默认 false
    );

    await _repository.addTodo(todo);
    loadTodos();
  }

  Future<void> updateTodo(Todo todo) async {
    final updatedTodo = todo.copyWith(updatedAt: DateTime.now());
    await _repository.updateTodo(updatedTodo);
    loadTodos();
  }

  // 🔴 修改：软删除
  Future<void> deleteTodo(String id) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index != -1) {
      final todo = _todos[index];
      await _repository.updateTodo(todo.copyWith(isDeleted: true));
      loadTodos();
    }
  }

  // 🔴 新增：还原待办
  Future<void> restoreTodo(String id) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index != -1) {
      final todo = _todos[index];
      await _repository.updateTodo(todo.copyWith(isDeleted: false));
      loadTodos();
    }
  }

  // 🔴 新增：永久删除
  Future<void> deleteTodoForever(String id) async {
    await _repository.deleteTodo(id);
    loadTodos();
  }

  // 🔴 新增：清空回收站
  Future<void> emptyTrash() async {
    final trash = List<Todo>.from(trashTodos);
    for (var todo in trash) {
      await _repository.deleteTodo(todo.id);
    }
    loadTodos();
  }

  Future<void> toggleTodoStatus(String id) async {
    await _repository.toggleTodoStatus(id);
    loadTodos();
  }

  // 拖拽排序逻辑
  Future<void> reorderTodos(int oldIndex, int newIndex) async {
    // 🔴 关键：只获取未删除且未完成的列表进行重排序计算
    final incompleteTodos = _todos.where((t) => !t.isCompleted && !t.isDeleted).toList();

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
    return _repository.searchTodos(query).where((t) => !t.isDeleted).toList();
  }
}