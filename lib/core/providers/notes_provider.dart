import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/repositories/note_repository.dart';
import '../../models/note.dart';

// 排序枚举
enum NoteSortOption {
  updatedNewest('最近修改'),
  createdNewest('最近创建'),
  titleAZ('标题 A-Z');

  final String label;
  const NoteSortOption(this.label);
}

class NotesProvider with ChangeNotifier {
  final NoteRepository _repository;
  List<Note> _notes = [];
  final Uuid _uuid = const Uuid();

  String? _selectedCategory;
  String _searchQuery = ''; // 🔴 新增：搜索关键词

  // 当前排序方式
  NoteSortOption _sortOption = NoteSortOption.updatedNewest;

  // 1. 定义初始默认分类
  static const List<String> _defaultCategories = ['学习', '工作', '生活', '创意'];

  NotesProvider(this._repository) {
    loadNotes();
  }

  // 主列表只返回未删除的笔记
  List<Note> get notes => _notes.where((n) => !n.isDeleted).toList();

  // 回收站列表
  List<Note> get trashNotes => _notes.where((n) => n.isDeleted).toList();

  String? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  NoteSortOption get sortOption => _sortOption;

  List<String> get categories {
    final Set<String> uniqueCategories = {};
    uniqueCategories.addAll(_defaultCategories);
    for (var note in this.notes) {
      if (note.category != null && note.category!.isNotEmpty) {
        uniqueCategories.add(note.category!);
      }
    }
    return uniqueCategories.toList()..sort();
  }

  // 🔴 核心：筛选逻辑 (分类 + 搜索 + 排序)
  List<Note> get filteredNotes {
    final sourceNotes = this.notes;

    // 1. 筛选分类
    var result = _selectedCategory == null
        ? List<Note>.from(sourceNotes)
        : sourceNotes.where((note) => note.category == _selectedCategory).toList();

    // 2. 🔴 筛选搜索关键词
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((n) {
        return n.title.toLowerCase().contains(query) ||
            n.plainText.toLowerCase().contains(query);
      }).toList();
    }

    // 3. 执行排序
    result.sort((a, b) {
      // 优先级 1: 置顶状态
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      // 优先级 2: 排序规则
      switch (_sortOption) {
        case NoteSortOption.updatedNewest:
          return b.updatedAt.compareTo(a.updatedAt);
        case NoteSortOption.createdNewest:
          return b.createdAt.compareTo(a.createdAt);
        case NoteSortOption.titleAZ:
          return a.title.compareTo(b.title);
      }
    });

    return result;
  }

  void loadNotes() {
    _notes = _repository.getAllNotes();
    notifyListeners();
  }

  void selectCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  // 🔴 新增：设置搜索词
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void changeSortOption(NoteSortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  Future<void> togglePin(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final note = _notes[index];
      await updateNote(note.copyWith(isPinned: !note.isPinned));
    }
  }

  Future<void> addNote({
    required String title,
    required String content,
    List<String> tags = const [],
    String? category,
  }) async {
    final note = Note(
      id: _uuid.v4(),
      title: title,
      content: content,
      tags: tags,
      category: category,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isPinned: false,
      isDeleted: false,
    );
    await _repository.addNote(note);
    loadNotes();
  }

  Future<void> updateNote(Note note) async {
    final updatedNote = note.copyWith(updatedAt: DateTime.now());
    await _repository.updateNote(updatedNote);
    loadNotes();
  }

  Future<void> deleteNote(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final note = _notes[index];
      await _repository.updateNote(note.copyWith(isDeleted: true));
      loadNotes();
    }
  }

  Future<void> restoreNote(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final note = _notes[index];
      await _repository.updateNote(note.copyWith(isDeleted: false));
      loadNotes();
    }
  }

  Future<void> deleteNoteForever(String id) async {
    await _repository.deleteNote(id);
    loadNotes();
  }

  Future<void> emptyTrash() async {
    final trash = List<Note>.from(trashNotes);
    for (var note in trash) {
      await _repository.deleteNote(note.id);
    }
    loadNotes();
  }
}