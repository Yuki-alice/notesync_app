import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import '../../core/repositories/todo_repository.dart';
import '../../models/todo.dart';

class TodosProvider with ChangeNotifier {
  final TodoRepository _repository;
  List<Todo> _todos = [];
  final Uuid _uuid = const Uuid();

  String _searchQuery = ''; // 🔴 新增：搜索关键词

  TodosProvider(this._repository) {
    loadTodos();
  }

  // 原始列表 (未删除)
  List<Todo> get todos => _todos.where((t) => !t.isDeleted).toList();

  // 回收站列表
  List<Todo> get trashTodos => _todos.where((t) => t.isDeleted).toList();

  String get searchQuery => _searchQuery;

  // 🔴 新增：筛选后的列表 (用于 UI 显示)
  List<Todo> get filteredTodos {
    var result = todos;

    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((t) =>
      t.title.toLowerCase().contains(query) ||
          t.description.toLowerCase().contains(query)
      ).toList();
    }

    // 排序逻辑：未完成在前，已完成在后；同状态下按 sortOrder 排
    result.sort((a, b) {
      if (a.isCompleted == b.isCompleted) {
        return a.sortOrder.compareTo(b.sortOrder);
      }
      return a.isCompleted ? 1 : -1;
    });

    return result;
  }

  void loadTodos() {
    _todos = _repository.getAllTodos();
    notifyListeners();
  }

  // 🔴 新增：设置搜索词
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> addTodo({
    required String title,
    String description = '',
    DateTime? dueDate,
  }) async {
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
      isDeleted: false,
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
    final index = _todos.indexWhere((t) => t.id == id);
    if (index != -1) {
      final todo = _todos[index];
      await _repository.updateTodo(todo.copyWith(isDeleted: true));
      loadTodos();
    }
  }

  Future<void> restoreTodo(String id) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index != -1) {
      final todo = _todos[index];
      await _repository.updateTodo(todo.copyWith(isDeleted: false));
      loadTodos();
    }
  }

  Future<void> deleteTodoForever(String id) async {
    await _repository.deleteTodo(id);
    loadTodos();
  }

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

  Future<void> reorderTodos(int oldIndex, int newIndex) async {
    // 只对当前显示列表中的未完成项进行排序
    // 注意：如果有搜索词，拖拽排序通常会禁用，或者逻辑会很复杂
    // 这里简单处理，建议在 UI 层有搜索词时禁用拖拽
    final incompleteTodos = filteredTodos.where((t) => !t.isCompleted).toList();

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    if (oldIndex >= incompleteTodos.length || newIndex >= incompleteTodos.length) return;

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
}