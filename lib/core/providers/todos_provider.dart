import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/repositories/todo_repository.dart';
import '../../models/todo.dart';

class TodosProvider with ChangeNotifier {
  final TodoRepository _repository;
  List<Todo> _todos = [];
  final Uuid _uuid = const Uuid();

  TodosProvider(this._repository) {
    // 构造时即可加载数据
    loadTodos();
  }

  List<Todo> get todos => _todos;

  void loadTodos() {
    _todos = _repository.getAllTodos(); // 去掉 await，改为同步调用
    notifyListeners();
  }

  // 保持 init 方法兼容现有调用，但内部直接调用 load
  Future<void> init() async {
    loadTodos();
  }

  Future<void> addTodo({required String title}) async {
    final todo = Todo(
      id: _uuid.v4(),
      title: title,
      isCompleted: false,
      createdAt: DateTime.now(),
    );
    await _repository.addTodo(todo);
    loadTodos();
  }

  Future<void> updateTodo(Todo todo) async {
    await _repository.updateTodo(todo);
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

  // 搜索现在可以是同步的，UI 响应更快
  List<Todo> searchTodos(String query) {
    return _repository.searchTodos(query);
  }
}