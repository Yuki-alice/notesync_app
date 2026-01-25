import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notesync_app/models/todo.dart';

class TodoRepository {
  static const String _todosKey = 'todos';

  // 新增：适配 Provider 的 init 方法（空实现，保持接口统一）
  Future<void> init() async {}

  // 重命名：getAllTodos 适配 Provider 调用
  Future<List<Todo>> getAllTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final todosJson = prefs.getStringList(_todosKey) ?? [];

    if (todosJson.isEmpty) {
      return [];
    }

    return todosJson.map((json) => Todo.fromJson(jsonDecode(json))).toList();
  }

  // 重命名：addTodo 适配 Provider 调用
  Future<void> addTodo(Todo todo) async {
    final prefs = await SharedPreferences.getInstance();
    final todos = await getAllTodos();
    todos.add(todo);
    await _saveAllTodos(todos);
  }

  // 新增：updateTodo 适配 Provider 调用
  Future<void> updateTodo(Todo todo) async {
    final prefs = await SharedPreferences.getInstance();
    final todos = await getAllTodos();

    final index = todos.indexWhere((t) => t.id == todo.id);
    if (index != -1) {
      todos[index] = todo;
      await _saveAllTodos(todos);
    }
  }

  Future<void> deleteTodo(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final todos = await getAllTodos();
    todos.removeWhere((todo) => todo.id == id);
    await _saveAllTodos(todos);
  }

  // 重命名：toggleTodoStatus 适配 Provider 调用，修复字段逻辑
  Future<void> toggleTodoStatus(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final todos = await getAllTodos();

    final index = todos.indexWhere((todo) => todo.id == id);
    if (index != -1) {
      final currentTodo = todos[index];
      todos[index] = currentTodo.copyWith(
        isCompleted: !currentTodo.isCompleted,
        updatedAt: DateTime.now(),
      );
      await _saveAllTodos(todos);
    }
  }

  // 新增：searchTodos 适配 Provider 调用
  Future<List<Todo>> searchTodos(String query) async {
    final todos = await getAllTodos();
    if (query.isEmpty) return todos;

    final lowercaseQuery = query.toLowerCase();
    return todos
        .where((todo) => todo.title.toLowerCase().contains(lowercaseQuery))
        .toList();
  }

  Future<void> _saveAllTodos(List<Todo> todos) async {
    final prefs = await SharedPreferences.getInstance();
    final todosJson = todos.map((todo) => jsonEncode(todo.toJson())).toList();
    await prefs.setStringList(_todosKey, todosJson);
  }
}