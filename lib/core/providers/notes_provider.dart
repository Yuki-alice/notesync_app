import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/repositories/note_repository.dart';
import '../../models/note.dart';

class NotesProvider with ChangeNotifier {
  final NoteRepository _repository;
  List<Note> _notes = [];

  // 修正：uuid 定义位置（避免全局变量）
  final Uuid _uuid = const Uuid();

  NotesProvider(this._repository);

  List<Note> get notes => _notes;

  Future<void> init() async {
    await _repository.init();
    _notes = await _repository.getAllNotes(); // 补充 await
    notifyListeners();
  }

  Future<void> addNote({required String title, required String content}) async {
    final note = Note(
      id: _uuid.v4(), // 使用类内 uuid
      title: title,
      content: content,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _repository.addNote(note);
    _notes = await _repository.getAllNotes(); // 补充 await
    notifyListeners();
  }

  Future<void> updateNote(Note note) async {
    await _repository.updateNote(note);
    _notes = await _repository.getAllNotes(); // 补充 await
    notifyListeners();
  }

  Future<void> deleteNote(String id) async {
    await _repository.deleteNote(id);
    _notes = await _repository.getAllNotes(); // 补充 await
    notifyListeners();
  }

  Future<List<Note>> searchNotes(String query) async { // 改为 Future
    return await _repository.searchNotes(query);
  }

  Future<Note?> getNoteById(String id) async { // 改为 Future
    return await _repository.getNoteById(id);
  }
}