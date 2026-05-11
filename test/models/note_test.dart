import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:komorebi/models/note.dart';

void main() {
  final now = DateTime(2026, 5, 11, 10, 0, 0);
  final later = DateTime(2026, 5, 11, 12, 0, 0);

  Note makeNote({
    String id = 'n1',
    String title = 'Test',
    String content = 'Hello',
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String> tagIds = const ['t1'],
    String? categoryId = 'c1',
    int version = 1,
    String? lastModifiedBy = 'device1',
    bool isPinned = false,
    bool isDeleted = false,
    bool isPrivate = false,
    List<String> imagePaths = const ['/img/a.png'],
  }) {
    return Note(
      id: id,
      title: title,
      content: content,
      createdAt: createdAt ?? now,
      updatedAt: updatedAt ?? later,
      tagIds: tagIds,
      categoryId: categoryId,
      version: version,
      lastModifiedBy: lastModifiedBy,
      isPinned: isPinned,
      isDeleted: isDeleted,
      isPrivate: isPrivate,
      imagePaths: imagePaths,
    );
  }

  group('Note.toJson / fromJson roundtrip', () {
    test('preserves all fields', () {
      final note = makeNote();
      final json = note.toJson();
      final restored = Note.fromJson(json);

      expect(restored.id, note.id);
      expect(restored.title, note.title);
      expect(restored.content, note.content);
      expect(restored.createdAt, note.createdAt);
      expect(restored.updatedAt, note.updatedAt);
      expect(restored.tagIds, note.tagIds);
      expect(restored.categoryId, note.categoryId);
      expect(restored.version, note.version);
      expect(restored.lastModifiedBy, note.lastModifiedBy);
      expect(restored.isPinned, note.isPinned);
      expect(restored.isDeleted, note.isDeleted);
      expect(restored.isPrivate, note.isPrivate);
      expect(restored.imagePaths, note.imagePaths);
    });

    test('handles null optional fields', () {
      final note = makeNote(
        categoryId: null,
        lastModifiedBy: null,
        tagIds: [],
        imagePaths: [],
      );
      final json = note.toJson();
      final restored = Note.fromJson(json);

      expect(restored.categoryId, isNull);
      expect(restored.lastModifiedBy, isNull);
      expect(restored.tagIds, isEmpty);
      expect(restored.imagePaths, isEmpty);
    });

    test('fromJson defaults for missing optional fields', () {
      final json = {
        'id': 'x',
        'title': 'T',
        'content': 'C',
        'createdAt': now.toIso8601String(),
        'updatedAt': later.toIso8601String(),
      };
      final note = Note.fromJson(json);

      expect(note.tagIds, isEmpty);
      expect(note.imagePaths, isEmpty);
      expect(note.version, 1);
      expect(note.isPinned, false);
      expect(note.isDeleted, false);
      expect(note.isPrivate, false);
      expect(note.categoryId, isNull);
      expect(note.lastModifiedBy, isNull);
    });

    test('toJson includes imagePaths', () {
      final note = makeNote(imagePaths: ['/a.png', '/b.png']);
      final json = note.toJson();
      expect(json['imagePaths'], ['/a.png', '/b.png']);
    });
  });

  group('Note.copyWith', () {
    test('copies with new values', () {
      final note = makeNote();
      final copied = note.copyWith(
        title: 'New Title',
        version: 5,
        isPinned: true,
      );

      expect(copied.title, 'New Title');
      expect(copied.version, 5);
      expect(copied.isPinned, true);
      // Unchanged fields
      expect(copied.id, note.id);
      expect(copied.content, note.content);
      expect(copied.categoryId, note.categoryId);
    });

    test('clearCategory sets categoryId to null', () {
      final note = makeNote(categoryId: 'c1');
      final copied = note.copyWith(clearCategory: true);
      expect(copied.categoryId, isNull);
    });

    test('clearCategory false preserves categoryId', () {
      final note = makeNote(categoryId: 'c1');
      final copied = note.copyWith(title: 'X');
      expect(copied.categoryId, 'c1');
    });

    test('with no arguments returns equivalent note', () {
      final note = makeNote();
      final copied = note.copyWith();
      expect(copied.id, note.id);
      expect(copied.title, note.title);
      expect(copied.version, note.version);
    });
  });

  group('Note.isRichText', () {
    test('returns true for Quill delta JSON array', () {
      final note = makeNote(content: '[{"insert":"hello"}]');
      expect(note.isRichText, true);
    });

    test('returns true for JSON object', () {
      final note = makeNote(content: '{"ops":[{"insert":"hi"}]}');
      expect(note.isRichText, true);
    });

    test('returns false for plain text', () {
      final note = makeNote(content: 'just plain text');
      expect(note.isRichText, false);
    });

    test('returns false for empty content', () {
      final note = makeNote(content: '');
      expect(note.isRichText, false);
    });

    test('trims whitespace before checking', () {
      final note = makeNote(content: '  [{"insert":"x"}]  ');
      expect(note.isRichText, true);
    });
  });

  group('Note.plainText', () {
    test('returns content directly for plain text', () {
      final note = makeNote(content: 'hello world');
      expect(note.plainText, 'hello world');
    });

    test('extracts text from Quill delta', () {
      final delta = [
        {'insert': 'Hello '},
        {'insert': 'World'},
      ];
      final note = makeNote(content: jsonEncode(delta));
      expect(note.plainText, 'Hello World');
    });

    test('skips non-string insert values (images, embeds)', () {
      final delta = [
        {'insert': 'Before '},
        {
          'insert': {
            'image': '/path/img.png',
          }
        },
        {'insert': ' After'},
      ];
      final note = makeNote(content: jsonEncode(delta));
      expect(note.plainText, 'Before  After');
    });

    test('returns empty string for malformed JSON', () {
      final note = makeNote(content: '[{"broken json');
      expect(note.plainText, '');
    });

    test('handles empty delta array', () {
      final note = makeNote(content: '[]');
      expect(note.plainText, '');
    });
  });

  group('Note.extractAllImagePaths', () {
    test('extracts image paths from delta', () {
      final delta = [
        {'insert': 'Text '},
        {
          'insert': {
            'image': '/storage/img1.png',
          }
        },
        {'insert': ' more'},
        {
          'insert': {
            'image': '/storage/img2.jpg',
          }
        },
      ];
      final paths = Note.extractAllImagePaths(jsonEncode(delta));
      expect(paths, ['/storage/img1.png', '/storage/img2.jpg']);
    });

    test('returns empty list for plain text', () {
      expect(Note.extractAllImagePaths('just text'), isEmpty);
    });

    test('returns empty list for empty string', () {
      expect(Note.extractAllImagePaths(''), isEmpty);
    });

    test('returns empty list for delta without images', () {
      final delta = [
        {'insert': 'Hello\n'},
        {'insert': 'World'},
      ];
      expect(Note.extractAllImagePaths(jsonEncode(delta)), isEmpty);
    });

    test('returns empty list for malformed JSON', () {
      expect(Note.extractAllImagePaths('[{broken'), isEmpty);
    });
  });

  group('Note.firstImagePath', () {
    test('returns first image path', () {
      final delta = [
        {'insert': 'Text '},
        {
          'insert': {
            'image': '/first.png',
          }
        },
        {
          'insert': {
            'image': '/second.png',
          }
        },
      ];
      final note = makeNote(content: jsonEncode(delta));
      expect(note.firstImagePath, '/first.png');
    });

    test('returns null when no images', () {
      final note = makeNote(content: 'no images here');
      expect(note.firstImagePath, isNull);
    });
  });
}
