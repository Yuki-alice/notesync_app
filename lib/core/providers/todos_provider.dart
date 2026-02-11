import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/repositories/todo_repository.dart';
import '../../models/todo.dart';

class TodosProvider with ChangeNotifier {
  final TodoRepository _repository;
  final Uuid _uuid = const Uuid();

  // 原始数据
  List<Todo> _todos = [];

  // 缓存的过滤后数据（用于主页显示）
  List<Todo> _filteredTodos = [];

  // 搜索关键词
  String _searchQuery = '';
  Timer? _debounceTimer;

  TodosProvider(this._repository) {
    loadTodos();
  }

  // --- Getters ---

  // 1. 主页数据：排除已删除的
  List<Todo> get todos => _todos.where((t) => !t.isDeleted).toList();

  // 2. 回收站数据：只取已删除的
  List<Todo> get trashTodos => _todos.where((t) => t.isDeleted).toList();

  // 3. UI层实际使用的数据（经过搜索和排序处理）
  List<Todo> get filteredTodos => _filteredTodos;

  String get searchQuery => _searchQuery;

  // 4. 未完成任务列表（用于计算排序权重）
  List<Todo> get activeTodos {
    final list = _todos.where((t) => !t.isCompleted && !t.isDeleted).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  // --- 核心逻辑 ---

  void loadTodos() {
    _todos = _repository.getAllTodos();
    _applyFilters();
  }

  /// 核心筛选与排序逻辑
  void _applyFilters() {
    // 基础源数据：排除已删除的（回收站的单独管理）
    var result = _todos.where((t) => !t.isDeleted).toList();

    // 1. 搜索过滤
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((t) {
        return t.title.toLowerCase().contains(query) ||
            t.description.toLowerCase().contains(query);
      }).toList();
    }

    // 2. 排序逻辑
    result.sort((a, b) {
      // 规则1: 未完成在前，已完成在后
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      // 规则2: 内部排序
      if (a.isCompleted) {
        // 已完成：按完成时间倒序（最近完成的在上面）
        return b.updatedAt.compareTo(a.updatedAt);
      } else {
        // 未完成：按自定义顺序 sortOrder（支持拖拽）
        return a.sortOrder.compareTo(b.sortOrder);
      }
    });

    _filteredTodos = result;
    notifyListeners();
  }

  /// 设置搜索词（带防抖）
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _applyFilters();
    });
  }

  // --- 增删改查 (CRUD) ---

  Future<void> addTodo({
    required String title,
    String? description,
    DateTime? dueDate,
  }) async {
    // 计算排序权重：默认放在最上面
    double newSortOrder = 0.0;
    if (activeTodos.isNotEmpty) {
      newSortOrder = activeTodos.first.sortOrder - 100.0;
    }

    final todo = Todo(
      id: _uuid.v4(),
      title: title,
      description: description ?? '',
      isCompleted: false,
      dueDate: dueDate,
      sortOrder: newSortOrder,
      isDeleted: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await _repository.addTodo(todo);
    loadTodos();
  }

  Future<void> updateTodo(Todo todo) async {
    final updatedTodo = todo.copyWith(updatedAt: DateTime.now());
    await _repository.updateTodo(updatedTodo);
    loadTodos();
  }

  Future<void> toggleTodoStatus(String id) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index != -1) {
      final todo = _todos[index];
      final newStatus = !todo.isCompleted;

      final updatedTodo = todo.copyWith(
        isCompleted: newStatus,
        updatedAt: DateTime.now(),
      );

      await _repository.updateTodo(updatedTodo);
      loadTodos();
    }
  }

  /// 拖拽排序（包含防抖动优化）
  Future<void> reorderTodos(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    // 获取操作副本
    final processingList = activeTodos;
    if (oldIndex < 0 || oldIndex >= processingList.length || newIndex < 0 || newIndex > processingList.length) return;

    // 1. 内存移动
    final item = processingList.removeAt(oldIndex);
    processingList.insert(newIndex, item);

    // 2. 重新计算权重并立即更新内存数据
    List<Future> dbTasks = [];
    for (int i = 0; i < processingList.length; i++) {
      final todo = processingList[i];
      final newOrder = i * 1000.0;

      if (todo.sortOrder != newOrder) {
        final updatedTodo = todo.copyWith(sortOrder: newOrder);

        // 更新内存主列表
        final indexInMain = _todos.indexWhere((t) => t.id == todo.id);
        if (indexInMain != -1) {
          _todos[indexInMain] = updatedTodo;
        }

        // 记录数据库任务
        dbTasks.add(_repository.updateTodo(updatedTodo));
      }
    }

    // 3. 立即刷新 UI (Optimistic Update)
    _applyFilters();

    // 4. 后台写入数据库
    await Future.wait(dbTasks);
  }

  // --- 回收站逻辑 ---

  /// 软删除：移入回收站
  Future<void> deleteTodo(String id) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index != -1) {
      final todo = _todos[index];
      final deletedTodo = todo.copyWith(isDeleted: true, updatedAt: DateTime.now());
      await _repository.updateTodo(deletedTodo);
      loadTodos();
    }
  }

  /// 彻底删除：从数据库移除
  Future<void> deleteTodoForever(String id) async {
    await _repository.deleteTodo(id);
    loadTodos();
  }

  /// 还原：从回收站恢复
  Future<void> restoreTodo(String id) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index != -1) {
      final todo = _todos[index];
      final restoredTodo = todo.copyWith(isDeleted: false, updatedAt: DateTime.now());
      await _repository.updateTodo(restoredTodo);
      loadTodos();
    }
  }

  /// 清空回收站
  Future<void> emptyTrash() async {
    final trash = trashTodos;
    for (var todo in trash) {
      await _repository.deleteTodo(todo.id);
    }
    loadTodos();
  }

  /// 清除已完成任务 -> 移入回收站
  Future<void> clearCompleted() async {
    final completed = _todos.where((t) => t.isCompleted && !t.isDeleted).toList();
    for (var todo in completed) {
      final deletedTodo = todo.copyWith(isDeleted: true, updatedAt: DateTime.now());
      await _repository.updateTodo(deletedTodo);
    }
    loadTodos();
  }
}