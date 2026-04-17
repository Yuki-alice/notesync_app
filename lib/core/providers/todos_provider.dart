import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/repositories/todo_repository.dart';
import '../../models/todo.dart';
import '../../core/services/supabase_sync_service.dart';
import '../../core/services/webdav_sync_service.dart';
import 'package:isar/isar.dart';

enum TodoSyncState { idle, syncing, success, error, unauthenticated }

class TodosProvider with ChangeNotifier, WidgetsBindingObserver {
  final TodoRepository _repository;
  final Uuid _uuid = const Uuid();
  late final SupabaseSyncService _syncService;

  List<Todo> _todos = [];
  List<Todo> _filteredTodos = [];
  String _searchQuery = '';

  Timer? _debounceTimer;
  Timer? _syncTimer;


  DateTime? _dbWatcherSilenceUntil;
  TodoSyncState _syncState = TodoSyncState.idle;
  TodoSyncState get syncState => _syncState;
  StreamSubscription<void>? _dbSubscription;

  TodosProvider(this._repository) {
    WidgetsBinding.instance.addObserver(this);
    _syncService = SupabaseSyncService(null, _repository);
    _dbSubscription = _repository.watchTodosChanged().listen((_) {
      if (_dbWatcherSilenceUntil == null || DateTime.now().isAfter(_dbWatcherSilenceUntil!)) {
        loadTodos();
      }
    });
    loadTodos();
    syncWithCloud();
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
    _dbSubscription?.cancel();
    super.dispose();
  }

  void _setSyncState(TodoSyncState state) {
    _syncState = state;
    notifyListeners();
  }

  Future<bool> _isSyncAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isAutoSyncEnabled') ?? false;
  }

  Future<void> syncWithCloud() async {
    // 1. 检查总闸
    if (!await _isSyncAllowed()) {
      debugPrint('⚠️ [SYNC-TODO] 云端同步已关闭，跳过本次任务');
      return;
    }

    if (_syncState == TodoSyncState.syncing) return;
    _setSyncState(TodoSyncState.syncing);

    try {
      final prefs = await SharedPreferences.getInstance();

      // 🌟 核心修复：读取用户在 UI 上选择的模式，而不是死抠配置字段
      final syncMode = prefs.getString('sync_mode') ?? 'supabase';

      if (syncMode == 'webdav') {
        // =====================================
        // 🚀 路由 A：WebDAV 引擎
        // =====================================
        final webDavService = WebDavSyncService(Isar.getInstance()!);
        await webDavService.syncAll();

      } else {
        // =====================================
        // 🚀 路由 B：Supabase 引擎
        // =====================================
        if (Supabase.instance.client.auth.currentUser == null) {
          _setSyncState(TodoSyncState.unauthenticated);
          return;
        }
        await _syncService.syncTodos(
            onSyncComplete: () {
              loadTodos();
            }
        );
      }

      loadTodos();

      _setSyncState(TodoSyncState.success);
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (_syncState == TodoSyncState.success) _setSyncState(TodoSyncState.idle);
      });

    } catch (e) {
      debugPrint('❌ [SYNC-TODO] 同步引擎遭遇致命错误: $e');
      _setSyncState(TodoSyncState.error);
      Future.delayed(const Duration(seconds: 3), () {
        if (_syncState == TodoSyncState.error) _setSyncState(TodoSyncState.idle);
      });
    }
  }

  void _triggerBackgroundSync() async{
    _syncTimer?.cancel();
    if(!await _isSyncAllowed()) return;
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

  Future<void> loadTodos() async {
    final results = await _repository.searchTodos(_searchQuery, null);
    _todos = results;
    // 🌟 致命修复：必须调用 _applyFilters() 进行内存级排序，绝不能直接赋值
    _applyFilters();
  }

void _applyFilters() {
    var result = _todos.where((t) => !t.isDeleted).toList();

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((t) {
        final matchTitle = t.title.toLowerCase().contains(query);
        final matchDesc = t.description.toLowerCase().contains(query);
        final matchSubTask = t.subTasks.any((sub) => sub.title.toLowerCase().contains(query));

        return matchTitle || matchDesc || matchSubTask;
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


  Future<void> addTodo({
    required String title,
    String? description,
    DateTime? dueDate,
    List<SubTask> subTasks = const [],
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
      updatedAt: DateTime.now(),
      subTasks: subTasks,
    );

    await _repository.addTodo(todo);
    loadTodos();
    _triggerBackgroundSync();
  }

  Future<void> updateTodo(Todo todo) async {
    final updatedTodo = todo.copyWith(updatedAt: DateTime.now());
    await _repository.updateTodo(updatedTodo);
    loadTodos();
    _triggerBackgroundSync();
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
      _triggerBackgroundSync();
    }
  }


  Future<void> reorderTodos(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;

    // 1. 极速提取当前列表的“未完成”项 (因为 UI 只有未完成项才能拖拽)
    final incompleteTodos = _filteredTodos.where((t) => !t.isCompleted).toList();
    if (oldIndex < 0 || oldIndex >= incompleteTodos.length || newIndex < 0 || newIndex > incompleteTodos.length) return;

    // 2. 纯内存极速换位，绝对不触发任何耗时的 Sort 算法
    final item = incompleteTodos.removeAt(oldIndex);
    incompleteTodos.insert(newIndex, item);

    // 3. 立即拼合列表并强制通知 UI 渲染 (第一帧立刻让拖拽卡片安家，绝不闪烁)
    final completedTodos = _filteredTodos.where((t) => t.isCompleted).toList();
    _filteredTodos = [...incompleteTodos, ...completedTodos];
    notifyListeners();

    // 4. 开启 2 秒的数据库监听静默期！
    // 拖拽后的 2 秒内，无视底层 Isar 发出的任何更新广播，切断引发闪烁的源头
    _dbWatcherSilenceUntil = DateTime.now().add(const Duration(seconds: 2));

    // 5. 在后台悄悄计算 sortOrder 并写入数据库，此时 UI 已经完全安定
    List<Future> dbTasks = [];
    bool hasChanges = false;

    for (int i = 0; i < incompleteTodos.length; i++) {
      final todo = incompleteTodos[i];
      final newOrder = i * 1000.0; // 重新分配权重

      if (todo.sortOrder != newOrder) {
        hasChanges = true;
        final updatedTodo = todo.copyWith(sortOrder: newOrder, updatedAt: DateTime.now());


        final indexInMain = _todos.indexWhere((t) => t.id == todo.id);
        if (indexInMain != -1) _todos[indexInMain] = updatedTodo;

        dbTasks.add(_repository.updateTodo(updatedTodo));
      }
    }


    await Future.wait(dbTasks);

    if (hasChanges) {
      _triggerBackgroundSync();
    }
  }

  Future<void> deleteTodo(String id) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index != -1) {
      final todo = _todos[index];
      final deletedTodo = todo.copyWith(isDeleted: true, updatedAt: DateTime.now());
      await _repository.updateTodo(deletedTodo);
      loadTodos();
      _triggerBackgroundSync();
    }
  }

  Future<void> deleteTodoForever(String id) async {
    await _repository.deleteTodo(id);
    loadTodos();
    await _syncService.recordDeletedTodoId(id);
    _triggerBackgroundSync();
  }

  Future<void> restoreTodo(String id) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index != -1) {
      final todo = _todos[index];
      final restoredTodo = todo.copyWith(isDeleted: false, updatedAt: DateTime.now());
      await _repository.updateTodo(restoredTodo);
      loadTodos();
      _triggerBackgroundSync();
    }
  }

  Future<void> emptyTrash() async {
    final trash = trashTodos;
    for (var todo in trash) {
      await _repository.deleteTodo(todo.id);
      await _syncService.recordDeletedTodoId(todo.id);
    }
    loadTodos();
    _triggerBackgroundSync();
  }

  Future<void> clearCompleted() async {
    final completed = _todos.where((t) => t.isCompleted && !t.isDeleted).toList();
    for (var todo in completed) {
      final deletedTodo = todo.copyWith(isDeleted: true, updatedAt: DateTime.now());
      await _repository.updateTodo(deletedTodo);
    }
    loadTodos();
    _triggerBackgroundSync();
  }

  void clearLocalData() {
    _debounceTimer?.cancel();
    _syncTimer?.cancel();

    _searchQuery = '';
    _todos.clear();
    _filteredTodos.clear();

    notifyListeners();
  }

  void clearTimers() {
    _debounceTimer?.cancel();
    _syncTimer?.cancel();
  }
}