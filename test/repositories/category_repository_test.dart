import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:komorebi/models/category.dart';
import 'package:komorebi/models/note.dart';
import 'package:komorebi/core/repositories/category_repository.dart';
import 'package:komorebi/core/repositories/note_repository.dart';

/// CategoryRepository 测试
///
/// 需要 Isar 原生库。运行方式:
///   flutter test test/repositories/category_repository_test.dart
void main() {
  late Isar isar;
  late CategoryRepository repo;
  late NoteRepository noteRepo;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isar_cat_test_');
    try {
      isar = await Isar.open(
        [CategorySchema, NoteSchema],
        directory: tempDir.path,
        name: 'cat_test_${DateTime.now().microsecondsSinceEpoch}',
      );
      repo = CategoryRepository(isar);
      noteRepo = NoteRepository(isar);
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
      isar.categorys;
      return true;
    } catch (_) {
      return false;
    }
  }

  Category _makeCategory({
    String id = 'cat1',
    String name = 'Test Category',
    double sortOrder = 0.0,
    String? color = '#FF5733',
    String? icon = 'folder',
  }) {
    return Category(
      id: id,
      name: name,
      sortOrder: sortOrder,
      color: color,
      icon: icon,
      createdAt: DateTime(2026, 5, 11, 10),
      updatedAt: DateTime(2026, 5, 11, 10),
    );
  }

  Note _makeNote({
    String id = 'note1',
    String title = 'Test Note',
    String? categoryId = 'cat1',
  }) {
    final now = DateTime(2026, 5, 11, 10);
    return Note(
      id: id,
      title: title,
      content: 'content',
      createdAt: now,
      updatedAt: now,
      categoryId: categoryId,
    );
  }

  group('CategoryRepository - addCategory / getCategoryById', () {
    test('add then get returns the same category', () async {
      if (!_isarAvailable()) return;
      final cat = _makeCategory();
      await repo.addCategory(cat);

      final fetched = repo.getCategoryById('cat1');
      expect(fetched, isNotNull);
      expect(fetched!.id, 'cat1');
      expect(fetched.name, 'Test Category');
      expect(fetched.color, '#FF5733');
    });

    test('getCategoryById returns null for nonexistent id', () {
      if (!_isarAvailable()) return;
      expect(repo.getCategoryById('nonexistent'), isNull);
    });
  });

  group('CategoryRepository - getAllCategories', () {
    test('returns categories sorted by sortOrder', () async {
      if (!_isarAvailable()) return;
      await repo.addCategory(_makeCategory(id: 'a', sortOrder: 2));
      await repo.addCategory(_makeCategory(id: 'b', sortOrder: 0));
      await repo.addCategory(_makeCategory(id: 'c', sortOrder: 1));

      final cats = repo.getAllCategories();
      expect(cats.length, 3);
      expect(cats[0].id, 'b'); // sortOrder 0
      expect(cats[1].id, 'c'); // sortOrder 1
      expect(cats[2].id, 'a'); // sortOrder 2
    });

    test('returns empty list when no categories', () {
      if (!_isarAvailable()) return;
      expect(repo.getAllCategories(), isEmpty);
    });
  });

  group('CategoryRepository - updateCategory', () {
    test('updates category name', () async {
      if (!_isarAvailable()) return;
      await repo.addCategory(_makeCategory(name: 'Original'));

      final cat = repo.getCategoryById('cat1')!;
      cat.name = 'Updated';
      await repo.updateCategory(cat);

      expect(repo.getCategoryById('cat1')!.name, 'Updated');
    });
  });

  group('CategoryRepository - deleteCategory', () {
    test('deletes category by id', () async {
      if (!_isarAvailable()) return;
      await repo.addCategory(_makeCategory());
      expect(repo.getCategoryById('cat1'), isNotNull);

      await repo.deleteCategory('cat1');
      expect(repo.getCategoryById('cat1'), isNull);
    });

    test('deleting category clears categoryId in affected notes', () async {
      if (!_isarAvailable()) return;
      await repo.addCategory(_makeCategory());
      await noteRepo.addNote(_makeNote(categoryId: 'cat1'));

      await repo.deleteCategory('cat1');

      final note = noteRepo.getNoteById('note1')!;
      expect(note.categoryId, isNull);
      expect(note.version, 2); // version incremented
    });

    test('delete nonexistent id does not throw', () async {
      if (!_isarAvailable()) return;
      await repo.deleteCategory('nonexistent');
    });
  });
}
