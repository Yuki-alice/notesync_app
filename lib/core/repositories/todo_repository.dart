import 'package:hive/hive.dart';
import 'package:notesync_app/models/todo.dart';

class TodoRepository {
  final Box<Todo> _box;

  TodoRepository(this._box);

  Future<void> init() async {}

  List<Todo> getAllTodos() {
    // 未完成的排前面，已完成的排后面
    final todos = _box.values.toList();
    todos.sort((a, b) {
      if (a.isCompleted == b.isCompleted) {
        return b.createdAt.compareTo(a.createdAt);
      }
      return a.isCompleted ? 1 : -1;
    });
    return todos;
  }

  Future<void> addTodo(Todo todo) async {
    await _box.put(todo.id, todo);
  }

  Future<void> updateTodo(Todo todo) async {
    await _box.put(todo.id, todo);
  }

  Future<void> deleteTodo(String id) async {
    await _box.delete(id);
  }

  Future<void> toggleTodoStatus(String id) async {
    final todo = _box.get(id);
    if (todo != null) {
      final updatedTodo = todo.copyWith(
        isCompleted: !todo.isCompleted,
        updatedAt: DateTime.now(),
      );
      await _box.put(id, updatedTodo);
    }
  }

  List<Todo> searchTodos(String query) {
    if (query.isEmpty) return getAllTodos();

    final lowercaseQuery = query.toLowerCase();
    return _box.values
        .where((todo) => todo.title.toLowerCase().contains(lowercaseQuery))
        .toList();
  }
}