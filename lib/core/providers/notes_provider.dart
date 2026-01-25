import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/repositories/note_repository.dart';
import '../../models/note.dart';

class NotesProvider with ChangeNotifier {
  final NoteRepository _repository;
  List<Note> _notes = [];
  final Uuid _uuid = const Uuid();

  NotesProvider(this._repository) {
    loadNotes();
  }

  List<Note> get notes => _notes;

  void loadNotes() {
    _notes = _repository.getAllNotes();
    notifyListeners();
  }

  // 保持兼容性，初始化方法
  Future<void> init() async {
    loadNotes();
  }

  // 🔴 修改处：增加了 tags 参数，默认为空列表
  Future<void> addNote({
    required String title,
    required String content,
    List<String> tags = const []
  }) async {
    final note = Note(
      id: _uuid.v4(),
      title: title,
      content: content,
      tags: tags, // 保存标签
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _repository.addNote(note);
    loadNotes();
  }

  Future<void> updateNote(Note note) async {
    // updateNote 直接接收完整的 Note 对象（包含 ID 和 updated tags），所以逻辑不用变
    // 但为了严谨，我们在这里更新一下 updatedAt
    final updatedNote = note.copyWith(updatedAt: DateTime.now());
    await _repository.updateNote(updatedNote);
    loadNotes();
  }

  Future<void> deleteNote(String id) async {
    await _repository.deleteNote(id);
    loadNotes();
  }

  List<Note> searchNotes(String query) {
    return _repository.searchNotes(query);
  }
}