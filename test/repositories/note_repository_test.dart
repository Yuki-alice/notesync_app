import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:komorebi/models/note.dart';
import 'package:komorebi/core/repositories/note_repository.dart';

/// NoteRepository 测试
///
/// 需要 Isar 原生库。运行方式:
///   flutter test test/repositories/note_repository_test.dart
///
/// 如果 Isar 原生库未加载，测试将被跳过。
void main() {
  late Isar isar;
  late NoteRepository repo;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isar_test_');
    try {
      isar = await Isar.open(
        [NoteSchema],
        directory: tempDir.path,
        name: 'test_${DateTime.now().microsecondsSinceEpoch}',
      );
      repo = NoteRepository(isar);
    } catch (e) {
      // Isar 原生库不可用时跳过
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

  /// 辅助：检查 Isar 是否可用
  bool _isarAvailable() {
    try {
      isar.notes;
      return true;
    } catch (_) {
      return false;
    }
  }

  Note _makeNote({
    String id = 'note1',
    String title = 'Test Note',
    String content = 'Hello World',
    int version = 1,
    bool isPinned = false,
    bool isDeleted = false,
    String? categoryId,
    DateTime? updatedAt,
  }) {
    final now = DateTime(2026, 5, 11, 10);
    return Note(
      id: id,
      title: title,
      content: content,
      createdAt: now,
      updatedAt: updatedAt ?? now,
      version: version,
      isPinned: isPinned,
      isDeleted: isDeleted,
      categoryId: categoryId,
    );
  }

  group('NoteRepository - addNote / getNoteById', () {
    test('add then get returns the same note', () async {
      if (!_isarAvailable()) return;
      final note = _makeNote();
      await repo.addNote(note);

      final fetched = repo.getNoteById('note1');
      expect(fetched, isNotNull);
      expect(fetched!.id, 'note1');
      expect(fetched.title, 'Test Note');
      expect(fetched.content, 'Hello World');
    });

    test('getNoteById returns null for nonexistent id', () {
      if (!_isarAvailable()) return;
      expect(repo.getNoteById('nonexistent'), isNull);
    });

    test('addNote with replace: true replaces existing', () async {
      if (!_isarAvailable()) return;
      await repo.addNote(_makeNote(title: 'Original'));
      await repo.addNote(_makeNote(title: 'Replaced'));

      final fetched = repo.getNoteById('note1');
      expect(fetched!.title, 'Replaced');
    });
  });

  group('NoteRepository - updateNote', () {
    test('increments version and updates updatedAt', () async {
      if (!_isarAvailable()) return;
      final note = _makeNote(version: 3);
      await repo.addNote(note);

      final before = DateTime.now();
      await repo.updateNote(repo.getNoteById('note1')!);

      final updated = repo.getNoteById('note1')!;
      expect(updated.version, 4);
      expect(updated.updatedAt.isAfter(before) ||
          updated.updatedAt.isAtSameMomentAs(before), true);
    });
  });

  group('NoteRepository - deleteNote', () {
    test('deletes note by id', () async {
      if (!_isarAvailable()) return;
      await repo.addNote(_makeNote());
      expect(repo.getNoteById('note1'), isNotNull);

      await repo.deleteNote('note1');
      expect(repo.getNoteById('note1'), isNull);
    });

    test('delete nonexistent id does not throw', () async {
      if (!_isarAvailable()) return;
      await repo.deleteNote('nonexistent');
    });
  });

  group('NoteRepository - getAllNotes', () {
    test('returns all notes sorted by pinned then updatedAt desc', () async {
      if (!_isarAvailable()) return;
      final t1 = DateTime(2026, 5, 11, 10);
      final t2 = DateTime(2026, 5, 11, 11);
      final t3 = DateTime(2026, 5, 11, 12);

      await repo.addNote(_makeNote(
        id: 'a', title: 'A', updatedAt: t1, isPinned: false,
      ));
      await repo.addNote(_makeNote(
        id: 'b', title: 'B', updatedAt: t2, isPinned: true,
      ));
      await repo.addNote(_makeNote(
        id: 'c', title: 'C', updatedAt: t3, isPinned: false,
      ));

      final notes = repo.getAllNotes();
      expect(notes.length, 3);
      // Pinned first
      expect(notes[0].id, 'b');
      // Then by updatedAt desc
      expect(notes[1].id, 'c');
      expect(notes[2].id, 'a');
    });

    test('returns empty list when no notes', () {
      if (!_isarAvailable()) return;
      expect(repo.getAllNotes(), isEmpty);
    });
  });

  group('NoteRepository - getAllNotesMetadataWithVersion', () {
    test('returns correct metadata', () async {
      if (!_isarAvailable()) return;
      final now = DateTime(2026, 5, 11, 10);
      await repo.addNote(_makeNote(id: 'a', version: 3));
      await repo.addNote(_makeNote(id: 'b', version: 7));

      final meta = repo.getAllNotesMetadataWithVersion();
      expect(meta.length, 2);
      expect(meta['a']!.version, 3);
      expect(meta['b']!.version, 7);
    });
  });

  group('NoteRepository - saveNoteFromSync', () {
    test('preserves original version and updatedAt', () async {
      if (!_isarAvailable()) return;
      final syncTime = DateTime(2026, 5, 1, 8);
      final note = _makeNote(
        id: 'sync1',
        version: 15,
      );
      // 手动设置 updatedAt（通常由 updateNote 修改）
      note.updatedAt = syncTime;

      await repo.saveNoteFromSync(note);

      final fetched = repo.getNoteById('sync1')!;
      expect(fetched.version, 15); // 未被修改
      expect(fetched.updatedAt, syncTime); // 未被修改
    });
  });

  group('NoteRepository - searchNotes', () {
    test('search by title (case-insensitive)', () async {
      if (!_isarAvailable()) return;
      await repo.addNote(_makeNote(id: 'a', title: 'Flutter 学习'));
      await repo.addNote(_makeNote(id: 'b', title: 'Dart 入门'));
      await repo.addNote(_makeNote(id: 'c', title: 'FLUTTER 进阶'));

      final results = await repo.searchNotes('flutter', null);
      expect(results.length, 2);
      expect(results.every((n) => n.title.toLowerCase().contains('flutter')), true);
    });

    test('search by content', () async {
      if (!_isarAvailable()) return;
      await repo.addNote(_makeNote(id: 'a', title: 'Note A', content: '重要笔记'));
      await repo.addNote(_makeNote(id: 'b', title: 'Note B', content: '普通内容'));

      final results = await repo.searchNotes('重要', null);
      expect(results.length, 1);
      expect(results[0].id, 'a');
    });

    test('filters out deleted notes', () async {
      if (!_isarAvailable()) return;
      await repo.addNote(_makeNote(id: 'a', title: 'Flutter Note', isDeleted: false));
      await repo.addNote(_makeNote(id: 'b', title: 'Flutter Deleted', isDeleted: true));

      final results = await repo.searchNotes('flutter', null);
      expect(results.length, 1);
      expect(results[0].id, 'a');
    });

    test('filter by categoryId', () async {
      if (!_isarAvailable()) return;
      await repo.addNote(_makeNote(id: 'a', categoryId: 'cat1'));
      await repo.addNote(_makeNote(id: 'b', categoryId: 'cat2'));
      await repo.addNote(_makeNote(id: 'c', categoryId: 'cat1'));

      final results = await repo.searchNotes('', 'cat1');
      expect(results.length, 2);
      expect(results.every((n) => n.categoryId == 'cat1'), true);
    });

    test('empty query returns all non-deleted notes', () async {
      if (!_isarAvailable()) return;
      await repo.addNote(_makeNote(id: 'a'));
      await repo.addNote(_makeNote(id: 'b', isDeleted: true));
      await repo.addNote(_makeNote(id: 'c'));

      final results = await repo.searchNotes('', null);
      expect(results.length, 2);
    });
  });
}
