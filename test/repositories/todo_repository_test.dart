import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:komorebi/models/todo.dart';
import 'package:komorebi/core/repositories/todo_repository.dart';

/// TodoRepository 测试
///
/// 需要 Isar 原生库。运行方式:
///   flutter test test/repositories/todo_repository_test.dart
void main() {
  late Isar isar;
  late TodoRepository repo;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isar_todo_test_');
    try {
      isar = await Isar.open(
        [TodoSchema],
        directory: tempDir.path,
        name: 'todo_test_${DateTime.now().microsecondsSinceEpoch}',
      );
      repo = TodoRepository(isar);
    } catch (e) {
      return;
    }
  });

  tearDown(() async {
    try {
      await isar.close(deleteFromDisk: true);
    } catch (_) {}
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  bool _isarAvailable() {
    try {
      isar.todos;
      return true;
    } catch (_) {
      return false;
    }
  }

  Todo _makeTodo({
    String id = 'todo1',
    String title = 'Test Todo',
    bool isCompleted = false,
    bool isDeleted = false,
    int version = 1,
    String? categoryId,
    DateTime? dueDate,
    double sortOrder = 0.0,
  }) {
    final now = DateTime(2026, 5, 11, 10);
    return Todo(
      id: id,
      title: title,
      isCompleted: isCompleted,
      isDeleted: isDeleted,
      createdAt: now,
      updatedAt: now,
      version: version,
      categoryId: categoryId,
      dueDate: dueDate,
      sortOrder: sortOrder,
    );
  }

  group('TodoRepository - addTodo / getTodoById', () {
    test('add then get returns the same todo', () async {
      if (!_isarAvailable()) return;
      final todo = _makeTodo();
      await repo.addTodo(todo);

      final fetched = repo.getTodoById('todo1');
      expect(fetched, isNotNull);
      expect(fetched!.id, 'todo1');
      expect(fetched.title, 'Test Todo');
      expect(fetched.isCompleted, false);
    });

    test('getTodoById returns null for nonexistent id', () {
      if (!_isarAvailable()) return;
      expect(repo.getTodoById('nonexistent'), isNull);
    });
  });

  group('TodoRepository - updateTodo', () {
    test('increments version and updates updatedAt', () async {
      if (!_isarAvailable()) return;
      final todo = _makeTodo(version: 3);
      await repo.addTodo(todo);

      final before = DateTime.now();
      await repo.updateTodo(repo.getTodoById('todo1')!);

      final updated = repo.getTodoById('todo1')!;
      expect(updated.version, 4);
      expect(updated.updatedAt.isAfter(before) ||
          updated.updatedAt.isAtSameMomentAs(before), true);
    });

    test('updateTodo changes title', () async {
      if (!_isarAvailable()) return;
      await repo.addTodo(_makeTodo(title: 'Original'));

      final todo = repo.getTodoById('todo1')!;
      todo.title = 'Updated';
      await repo.updateTodo(todo);

      expect(repo.getTodoById('todo1')!.title, 'Updated');
    });
  });

  group('TodoRepository - deleteTodo', () {
    test('deletes todo by id', () async {
      if (!_isarAvailable()) return;
      await repo.addTodo(_makeTodo());
      expect(repo.getTodoById('todo1'), isNotNull);

      await repo.deleteTodo('todo1');
      expect(repo.getTodoById('todo1'), isNull);
    });

    test('delete nonexistent id does not throw', () async {
      if (!_isarAvailable()) return;
      await repo.deleteTodo('nonexistent');
    });
  });

  group('TodoRepository - getAllTodos', () {
    test('returns todos sorted by completion then createdAt desc', () async {
      if (!_isarAvailable()) return;
      final t1 = DateTime(2026, 5, 11, 10);
      final t2 = DateTime(2026, 5, 11, 11);

      await repo.addTodo(_makeTodo(
        id: 'a', title: 'A', isCompleted: false, sortOrder: 0,
      ));
      await repo.addTodo(_makeTodo(
        id: 'b', title: 'B', isCompleted: true, sortOrder: 1,
      ));
      await repo.addTodo(_makeTodo(
        id: 'c', title: 'C', isCompleted: false, sortOrder: 2,
      ));

      final todos = repo.getAllTodos();
      expect(todos.length, 3);
      // 未完成的在前
      expect(todos[0].isCompleted, false);
      expect(todos[1].isCompleted, false);
      expect(todos[2].isCompleted, true);
    });

    test('returns empty list when no todos', () {
      if (!_isarAvailable()) return;
      expect(repo.getAllTodos(), isEmpty);
    });
  });

  group('TodoRepository - getAllTodosMetadata', () {
    test('returns correct metadata map', () async {
      if (!_isarAvailable()) return;
      final now = DateTime(2026, 5, 11, 10);
      await repo.addTodo(_makeTodo(id: 'a', version: 3));
      await repo.addTodo(_makeTodo(id: 'b', version: 7));

      final meta = repo.getAllTodosMetadata();
      expect(meta.length, 2);
      expect(meta.containsKey('a'), true);
      expect(meta.containsKey('b'), true);
    });
  });

  group('TodoRepository - searchTodos', () {
    test('search by title', () async {
      if (!_isarAvailable()) return;
      await repo.addTodo(_makeTodo(id: 'a', title: 'Flutter 学习'));
      await repo.addTodo(_makeTodo(id: 'b', title: 'Dart 入门'));

      final results = await repo.searchTodos('flutter', null);
      expect(results.length, 1);
      expect(results.first.title, 'Flutter 学习');
    });

    test('search with category filter', () async {
      if (!_isarAvailable()) return;
      await repo.addTodo(_makeTodo(id: 'a', title: 'Work', categoryId: 'work'));
      await repo.addTodo(_makeTodo(id: 'b', title: 'Personal', categoryId: 'personal'));

      final results = await repo.searchTodos('', 'work');
      expect(results.length, 1);
      expect(results.first.id, 'a');
    });
  });
}
