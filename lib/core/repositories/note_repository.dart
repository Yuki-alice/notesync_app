import 'package:hive/hive.dart';
import 'package:notesync_app/models/note.dart';

class NoteRepository {
  final Box<Note> _box;

  NoteRepository(this._box);

  // 初始化方法现在可以为空，因为 main.dart 已经完成了 Box 的打开
  Future<void> init() async {}

  List<Note> getAllNotes() {
    // Hive 的 values 是可迭代的，直接转为 List
    // 按更新时间降序排列 (最近修改的在前面)
    final notes = _box.values.toList();
    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return notes;
  }

  Future<void> addNote(Note note) async {
    // 使用 note.id 作为 key，方便后续快速查找
    await _box.put(note.id, note);
  }

  Future<void> updateNote(Note note) async {
    await _box.put(note.id, note);
  }

  Future<void> deleteNote(String id) async {
    await _box.delete(id);
  }

  // 搜索逻辑：同步且快速
  List<Note> searchNotes(String query) {
    if (query.isEmpty) return getAllNotes();

    final lowercaseQuery = query.toLowerCase();
    return _box.values.where((note) {
      return note.title.toLowerCase().contains(lowercaseQuery) ||
          note.plainText.toLowerCase().contains(lowercaseQuery) ||
          note.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery));
    }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Note? getNoteById(String id) {
    return _box.get(id);
  }
}