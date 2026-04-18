import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../../models/note.dart';

class NoteRepository {
  final Isar _isar;

  NoteRepository(this._isar);

  Future<void> init() async {}

  Note? getNoteById(String id) {
    return _isar.notes.where().idEqualTo(id).findFirstSync();
  }

  Map<String, DateTime> getAllNotesMetadata() {
    final notes = _isar.notes.where().findAllSync();
    return {for (var note in notes) note.id: note.updatedAt};
  }

  List<Note> getAllNotes() {
    try {
      final notes = _isar.notes.where().findAllSync();
      notes.sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return notes;
    } catch (e) {
      debugPrint('Repo Error (getAllNotes): $e');
      return [];
    }
  }

  Future<void> addNote(Note note) async {
    await _isar.writeTxn(() async {
      await _isar.notes.put(note);
    });
  }

  Future<void> updateNote(Note note) async {
    note.version += 1;
    note.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.notes.put(note);
    });
  }

  /// 🌟 同步专用：保存笔记但不修改 updatedAt（保留云端时间戳）
  Future<void> saveNoteFromSync(Note note) async {
    await _isar.writeTxn(() async {
      await _isar.notes.put(note);
    });
  }

  Future<void> deleteNote(String id) async {
    await _isar.writeTxn(() async {
      await _isar.notes.where().idEqualTo(id).deleteAll();
    });
  }

  Future<List<Note>> searchNotes(String query, String? categoryId) async {
    var q = _isar.notes.filter().isDeletedEqualTo(false);

    if (categoryId != null && categoryId.isNotEmpty) {
      q = q.categoryIdEqualTo(categoryId);
    }

    if (query.trim().isNotEmpty) {
      q = q.group((q) => q.titleContains(query, caseSensitive: false)
          .or()
          .contentContains(query, caseSensitive: false));
    }

    return await q.sortByIsPinnedDesc().thenByUpdatedAtDesc().findAll();
  }

  Stream<void> watchNotesChanged() {
    return _isar.notes.watchLazy(fireImmediately: true);
  }
}