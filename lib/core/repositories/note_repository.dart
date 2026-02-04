import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../models/note.dart';

class NoteRepository {
  final Box<Note> _box;

  NoteRepository(this._box);

  Future<void> init() async {}

  List<Note> getAllNotes() {
    try {
      final notes = _box.values.toList();
      notes.sort((a, b) {
        // 优先按置顶排序，再按更新时间
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return notes;
    } catch (e) {
      debugPrint('Repo Error (getAllNotes): $e');
      return []; // 出错时返回空列表，而不是崩溃
    }
  }

  Future<void> addNote(Note note) async {
    try {
      await _box.put(note.id, note);
    } catch (e) {
      debugPrint('Repo Error (addNote): $e');
      rethrow; // 将错误向上抛出，以便 UI 层（如 SnackBar）可以提示用户
    }
  }

  Future<void> updateNote(Note note) async {
    try {
      await _box.put(note.id, note);
    } catch (e) {
      debugPrint('Repo Error (updateNote): $e');
      rethrow;
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      await _box.delete(id);
    } catch (e) {
      debugPrint('Repo Error (deleteNote): $e');
      rethrow;
    }
  }

  List<Note> searchNotes(String query) {
    if (query.isEmpty) return getAllNotes();

    try {
      final lowercaseQuery = query.toLowerCase();
      return _box.values.where((note) {
        // 排除已删除的笔记 (如果回收站逻辑需要搜索，可去掉 !note.isDeleted)
        // 这里假设搜索只针对未删除的，或者由 Provider 层再次过滤
        return note.title.toLowerCase().contains(lowercaseQuery) ||
            note.plainText.toLowerCase().contains(lowercaseQuery) ||
            note.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery));
      }).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      debugPrint('Repo Error (searchNotes): $e');
      return [];
    }
  }

  Note? getNoteById(String id) {
    try {
      return _box.get(id);
    } catch (e) {
      debugPrint('Repo Error (getNoteById): $e');
      return null;
    }
  }
}