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
    // 🟢 高性能查询：只拉取我们需要比对的字段，速度极快
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
    // Isar 写入必须在事务中进行
    await _isar.writeTxn(() async {
      await _isar.notes.put(note);
    });
  }

  Future<void> updateNote(Note note) async {
    await _isar.writeTxn(() async {
      await _isar.notes.put(note);
    });
  }

  Future<void> deleteNote(String id) async {
    await _isar.writeTxn(() async {
      await _isar.notes.where().idEqualTo(id).deleteAll();
    });
  }

  List<Note> searchNotes(String query) {
    if (query.isEmpty) return getAllNotes();

    final lowercaseQuery = query.toLowerCase();
    // 🟢 未来升级点：这里可以换成 Isar 真正的全文搜索 .titleContains()
    final notes = _isar.notes.where().findAllSync();
    return notes.where((note) {
      return note.title.toLowerCase().contains(lowercaseQuery) ||
          note.plainText.toLowerCase().contains(lowercaseQuery) ||
          note.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }
}