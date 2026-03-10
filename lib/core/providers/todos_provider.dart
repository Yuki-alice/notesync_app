import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/repositories/todo_repository.dart';
import '../../models/todo.dart';
import '../../core/services/supabase_sync_service.dart';

// 🟢 这里同样可以加上 SyncState 状态，供未来 UI 显示同步云朵使用
enum TodoSyncState { idle, syncing, success, error,unauthenticated }

class TodosProvider with ChangeNotifier, WidgetsBindingObserver {
  final TodoRepository _repository;
  final Uuid _uuid = const Uuid();
  late final SupabaseSyncService _syncService;

  List<Todo> _todos = [];
  List<Todo> _filteredTodos = [];
  String _searchQuery = '';

  Timer? _debounceTimer;
  Timer? _syncTimer; // 🟢 防抖同步定时器

  TodoSyncState _syncState = TodoSyncState.idle;
  TodoSyncState get syncState => _syncState;

  TodosProvider(this._repository) {
    // 🟢 注册应用生命周期监听 (切回前台时自动同步)
    WidgetsBinding.instance.addObserver(this);

    // 🟢 实例化同步服务 (这里我们传入 null 作为 NoteRepo，只传 TodoRepo)
    _syncService = SupabaseSyncService(null, _repository);

    loadTodos();
    syncWithCloud(); // 应用启动时主动同步一次
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      syncWithCloud();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  // =================================================================
  // ☁️ 云端同步逻辑
  // =================================================================

  void _setSyncState(TodoSyncState state) {
    _syncState = state;
    notifyListeners();
  }

  /// 🟢 主动触发同步 (支持下拉刷新等场景)
  Future<void> syncWithCloud() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      _setSyncState(TodoSyncState.unauthenticated);
      return;
    }
    if (_syncState == TodoSyncState.syncing) return;
    _setSyncState(TodoSyncState.syncing);

    try {
      await _syncService.syncTodos(
          onSyncComplete: () {
            loadTodos(); // 远端数据合并完后，重新加载并刷新 UI
          }
      );

      _setSyncState(TodoSyncState.success);
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (_syncState == TodoSyncState.success) _setSyncState(TodoSyncState.idle);
      });
    } catch (e) {
      _setSyncState(TodoSyncState.error);
      Future.delayed(const Duration(seconds: 3), () {
        if (_syncState == TodoSyncState.error) _setSyncState(TodoSyncState.idle);
      });
    }
  }

  /// 🟢 后台防抖同步 (增删改查时默默调用)
  void _triggerBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 3), () {
      syncWithCloud();
    });
  }

  // =================================================================
  // 📚 数据获取与排序逻辑
  // =================================================================

  List<Todo> get todos => _todos.where((t) => !t.isDeleted).toList();
  List<Todo> get trashTodos => _todos.where((t) => t.isDeleted).toList();
  List<Todo> get filteredTodos => _filteredTodos;
  String get searchQuery => _searchQuery;

  List<Todo> get activeTodos {
    final list = _todos.where((t) => !t.isCompleted && !t.isDeleted).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  void loadTodos() {
    _todos = _repository.getAllTodos();
    _applyFilters();
  }

  void _applyFilters() {
    var result = _todos.where((t) => !t.isDeleted).toList();

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((t) {
        return t.title.toLowerCase().contains(query) ||
            t.description.toLowerCase().contains(query);
      }).toList();
    }

    result.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      if (a.isCompleted) {
        return b.updatedAt.compareTo(a.updatedAt);
      } else {
        return a.sortOrder.compareTo(b.sortOrder);
      }
    });

    _filteredTodos = result;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _applyFilters();
    });
  }

  // =================================================================
  // ✏️ 增删改查逻辑 (全部接入了触发器)
  // =================================================================

  Future<void> addTodo({
    required String title,
    String? description,
    DateTime? dueDate,
  }) async {
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
      updatedAt: DateTime.now(), // 🟢 保证时间戳是最新的
    );

    await _repository.addTodo(todo);
    loadTodos();
    _triggerBackgroundSync(); // 🟢 触发同步
  }

  Future<void> updateTodo(Todo todo) async {
    final updatedTodo = todo.copyWith(updatedAt: DateTime.now());
    await _repository.updateTodo(updatedTodo);
    loadTodos();
    _triggerBackgroundSync(); // 🟢 触发同步
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
      _triggerBackgroundSync(); // 🟢 触发同步
    }
  }

  Future<void> reorderTodos(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;

    final processingList = activeTodos;
    if (oldIndex < 0 || oldIndex >= processingList.length || newIndex < 0 || newIndex > processingList.length) return;

    final item = processingList.removeAt(oldIndex);
    processingList.insert(newIndex, item);

    List<Future> dbTasks = [];
    bool hasChanges = false;
    for (int i = 0; i < processingList.length; i++) {
      final todo = processingList[i];
      final newOrder = i * 1000.0;

      if (todo.sortOrder != newOrder) {
        hasChanges = true;
        // 🟢 拖拽改变顺序，也需要更新 updatedAt，通知云端这是最新的排序状态
        final updatedTodo = todo.copyWith(sortOrder: newOrder, updatedAt: DateTime.now());

        final indexInMain = _todos.indexWhere((t) => t.id == todo.id);
        if (indexInMain != -1) _todos[indexInMain] = updatedTodo;
        dbTasks.add(_repository.updateTodo(updatedTodo));
      }
    }

    _applyFilters();
    await Future.wait(dbTasks);

    if (hasChanges) {
      _triggerBackgroundSync(); // 🟢 触发同步
    }
  }

  Future<void> deleteTodo(String id) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index != -1) {
      final todo = _todos[index];
      final deletedTodo = todo.copyWith(isDeleted: true, updatedAt: DateTime.now());
      await _repository.updateTodo(deletedTodo);
      loadTodos();
      _triggerBackgroundSync(); // 🟢 触发同步
    }
  }

  Future<void> deleteTodoForever(String id) async {
    await _repository.deleteTodo(id);
    loadTodos();
    _triggerBackgroundSync(); // 🟢 彻底删除也需要触发同步
  }

  Future<void> restoreTodo(String id) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index != -1) {
      final todo = _todos[index];
      final restoredTodo = todo.copyWith(isDeleted: false, updatedAt: DateTime.now());
      await _repository.updateTodo(restoredTodo);
      loadTodos();
      _triggerBackgroundSync(); // 🟢 触发同步
    }
  }

  Future<void> emptyTrash() async {
    final trash = trashTodos;
    for (var todo in trash) {
      await _repository.deleteTodo(todo.id);
    }
    loadTodos();
    _triggerBackgroundSync(); // 🟢 触发同步
  }

  Future<void> clearCompleted() async {
    final completed = _todos.where((t) => t.isCompleted && !t.isDeleted).toList();
    for (var todo in completed) {
      final deletedTodo = todo.copyWith(isDeleted: true, updatedAt: DateTime.now());
      await _repository.updateTodo(deletedTodo);
    }
    loadTodos();
    _triggerBackgroundSync(); // 🟢 触发同步
  }
}