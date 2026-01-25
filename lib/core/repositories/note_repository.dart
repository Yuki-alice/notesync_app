import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notesync_app/models/note.dart';

class NoteRepository {
  static const String _notesKey = 'notes';

  // 新增：init 方法
  Future<void> init() async {}

  // 重命名：getAllNotes 适配 Provider 调用
  Future<List<Note>> getAllNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getStringList(_notesKey) ?? [];

    if (notesJson.isEmpty) {
      return [];
    }

    return notesJson.map((json) => Note.fromJson(jsonDecode(json))).toList();
  }

  // 重命名：addNote 适配 Provider 调用
  Future<void> addNote(Note note) async {
    final prefs = await SharedPreferences.getInstance();
    final notes = await getAllNotes();
    notes.add(note);
    await _saveAllNotes(notes);
  }

  // 新增：updateNote 适配 Provider 调用
  Future<void> updateNote(Note note) async {
    final prefs = await SharedPreferences.getInstance();
    final notes = await getAllNotes();

    final index = notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      notes[index] = note;
      await _saveAllNotes(notes);
    }
  }

  Future<void> deleteNote(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final notes = await getAllNotes();
    notes.removeWhere((note) => note.id == id);
    await _saveAllNotes(notes);
  }

  // 修正：searchNotes 改为 Future 方法（适配异步逻辑）
  Future<List<Note>> searchNotes(String query) async {
    final notes = await getAllNotes();
    if (query.isEmpty) return notes;

    final lowercaseQuery = query.toLowerCase();
    return notes.where((note) {
      return note.title.toLowerCase().contains(lowercaseQuery) ||
          note.content.toLowerCase().contains(lowercaseQuery) ||
          note.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }

  // 新增：getNoteById 适配 Provider 调用
  Future<Note?> getNoteById(String id) async {
    final notes = await getAllNotes();
    return notes.firstWhere((note) => note.id == id);
  }

  Future<void> _saveAllNotes(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = notes.map((note) => jsonEncode(note.toJson())).toList();
    await prefs.setStringList(_notesKey, notesJson);
  }

  Future<List<String>> getAllTags() async {
    final notes = await getAllNotes();
    final allTags = <String>{};

    for (final note in notes) {
      allTags.addAll(note.tags);
    }

    return allTags.toList()..sort();
  }

  Future<List<String>> getAllCategories() async {
    final notes = await getAllNotes();
    final allCategories = <String>{};

    for (final note in notes) {
      allCategories.add(note.category);
    }

    return allCategories.toList()..sort();
  }
}