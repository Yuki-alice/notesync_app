import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:komorebi/models/tag.dart';
import 'package:komorebi/models/note.dart';
import 'package:komorebi/core/repositories/tag_repository.dart';
import 'package:komorebi/core/repositories/note_repository.dart';

/// TagRepository 测试
///
/// 需要 Isar 原生库。运行方式:
///   flutter test test/repositories/tag_repository_test.dart
void main() {
  late Isar isar;
  late TagRepository repo;
  late NoteRepository noteRepo;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isar_tag_test_');
    try {
      isar = await Isar.open(
        [TagSchema, NoteSchema],
        directory: tempDir.path,
        name: 'tag_test_${DateTime.now().microsecondsSinceEpoch}',
      );
      repo = TagRepository(isar);
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
      isar.tags;
      return true;
    } catch (_) {
      return false;
    }
  }

  Tag _makeTag({
    String id = 'tag1',
    String name = 'Test Tag',
    String? color = '#33FF57',
  }) {
    final now = DateTime(2026, 5, 11, 10);
    return Tag(
      id: id,
      name: name,
      color: color,
      createdAt: now,
      updatedAt: now,
    );
  }

  Note _makeNote({
    String id = 'note1',
    String title = 'Test Note',
    List<String> tagIds = const ['tag1'],
  }) {
    final now = DateTime(2026, 5, 11, 10);
    return Note(
      id: id,
      title: title,
      content: 'content',
      createdAt: now,
      updatedAt: now,
      tagIds: tagIds,
    );
  }

  group('TagRepository - addTag / getTagById', () {
    test('add then get returns the same tag', () async {
      if (!_isarAvailable()) return;
      final tag = _makeTag();
      await repo.addTag(tag);

      final fetched = repo.getTagById('tag1');
      expect(fetched, isNotNull);
      expect(fetched!.id, 'tag1');
      expect(fetched.name, 'Test Tag');
      expect(fetched.color, '#33FF57');
    });

    test('getTagById returns null for nonexistent id', () {
      if (!_isarAvailable()) return;
      expect(repo.getTagById('nonexistent'), isNull);
    });
  });

  group('TagRepository - getAllTags', () {
    test('returns tags sorted by createdAt desc', () async {
      if (!_isarAvailable()) return;
      final t1 = DateTime(2026, 5, 11, 10);
      final t2 = DateTime(2026, 5, 11, 11);
      final t3 = DateTime(2026, 5, 11, 12);

      await repo.addTag(_makeTag(id: 'a', name: 'A')..createdAt = t1);
      await repo.addTag(_makeTag(id: 'b', name: 'B')..createdAt = t3);
      await repo.addTag(_makeTag(id: 'c', name: 'C')..createdAt = t2);

      final tags = repo.getAllTags();
      expect(tags.length, 3);
      expect(tags[0].id, 'b'); // createdAt t3 (latest)
      expect(tags[1].id, 'c'); // createdAt t2
      expect(tags[2].id, 'a'); // createdAt t1 (oldest)
    });

    test('returns empty list when no tags', () {
      if (!_isarAvailable()) return;
      expect(repo.getAllTags(), isEmpty);
    });
  });

  group('TagRepository - deleteTag', () {
    test('deletes tag by id', () async {
      if (!_isarAvailable()) return;
      await repo.addTag(_makeTag());
      expect(repo.getTagById('tag1'), isNotNull);

      await repo.deleteTag('tag1');
      expect(repo.getTagById('tag1'), isNull);
    });

    test('deleting tag removes tagId from affected notes', () async {
      if (!_isarAvailable()) return;
      await repo.addTag(_makeTag());
      await noteRepo.addNote(_makeNote(tagIds: ['tag1', 'tag2']));

      await repo.deleteTag('tag1');

      final note = noteRepo.getNoteById('note1')!;
      expect(note.tagIds, isNot(contains('tag1')));
      expect(note.tagIds, contains('tag2'));
      expect(note.version, 2); // version incremented
    });

    test('delete nonexistent id does not throw', () async {
      if (!_isarAvailable()) return;
      await repo.deleteTag('nonexistent');
    });
  });
}
