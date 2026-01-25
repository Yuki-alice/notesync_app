import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/repositories/todo_repository.dart';
import '../../models/todo.dart';

class TodosProvider with ChangeNotifier {
  final TodoRepository _repository;
  List<Todo> _todos = [];

  TodosProvider(this._repository);

  List<Todo> get todos => _todos;

  Future<void> init() async {
    await _repository.init();
    _todos = await _repository.getAllTodos(); // 补充 await
    notifyListeners();
  }

  Future<void> addTodo({required String title}) async {
    final todo = Todo(
      id: const Uuid().v4(),
      title: title,
      isCompleted: false,
      createdAt: DateTime.now(),
    );
    await _repository.addTodo(todo);
    _todos = await _repository.getAllTodos(); // 补充 await
    notifyListeners();
  }

  Future<void> updateTodo(Todo todo) async {
    await _repository.updateTodo(todo);
    _todos = await _repository.getAllTodos(); // 补充 await
    notifyListeners();
  }

  Future<void> deleteTodo(String id) async {
    await _repository.deleteTodo(id);
    _todos = await _repository.getAllTodos(); // 补充 await
    notifyListeners();
  }

  Future<void> toggleTodoStatus(String id) async { // 改为 Future
    await _repository.toggleTodoStatus(id);
    _todos = await _repository.getAllTodos(); // 补充 await
    notifyListeners();
  }

  Future<List<Todo>> searchTodos(String query) async { // 改为 Future
    return await _repository.searchTodos(query);
  }
}