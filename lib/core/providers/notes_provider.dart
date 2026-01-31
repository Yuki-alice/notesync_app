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

  // 当前排序方式
  NoteSortOption _sortOption = NoteSortOption.updatedNewest;

  // 1. 定义初始默认分类
  static const List<String> _defaultCategories = ['学习', '工作', '生活', '创意'];

  NotesProvider(this._repository) {
    loadNotes();
  }

  // 🔴 修改：主列表只返回未删除的笔记
  List<Note> get notes => _notes.where((n) => !n.isDeleted).toList();

  // 🔴 新增：回收站列表
  List<Note> get trashNotes => _notes.where((n) => n.isDeleted).toList();

  String? get selectedCategory => _selectedCategory;
  NoteSortOption get sortOption => _sortOption; // 暴露排序选项

  // 获取分类 (仅从未删除的笔记中提取)
  List<String> get categories {
    final Set<String> uniqueCategories = {};
    uniqueCategories.addAll(_defaultCategories);

    // 使用 this.notes 而不是 _notes，确保不包含已删除笔记的分类
    for (var note in this.notes) {
      if (note.category != null && note.category!.isNotEmpty) {
        uniqueCategories.add(note.category!);
      }
    }
    return uniqueCategories.toList()..sort();
  }

  // 核心：排序与筛选逻辑 (基于未删除的笔记)
  List<Note> get filteredNotes {
    // 使用 this.notes (已过滤删除状态) 作为数据源
    final sourceNotes = this.notes;

    // 1. 筛选分类
    var result = _selectedCategory == null
        ? List<Note>.from(sourceNotes)
        : sourceNotes.where((note) => note.category == _selectedCategory).toList();

    // 2. 执行排序
    result.sort((a, b) {
      // 优先级 1: 置顶状态 (置顶的排前面)
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }

      // 优先级 2: 根据选择的规则排序
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

  // 切换排序
  void changeSortOption(NoteSortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  // 切换置顶状态
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
      isDeleted: false, // 默认为 false
    );
    await _repository.addNote(note);
    loadNotes();
  }

  Future<void> updateNote(Note note) async {
    final updatedNote = note.copyWith(updatedAt: DateTime.now());
    await _repository.updateNote(updatedNote);
    loadNotes();
  }

  // 🔴 修改：软删除 (移入回收站)
  Future<void> deleteNote(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final note = _notes[index];
      // 将 isDeleted 设为 true
      await _repository.updateNote(note.copyWith(isDeleted: true));
      loadNotes();
    }
  }

  // 🔴 新增：还原笔记
  Future<void> restoreNote(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final note = _notes[index];
      await _repository.updateNote(note.copyWith(isDeleted: false));
      loadNotes();
    }
  }

  // 🔴 新增：永久删除
  Future<void> deleteNoteForever(String id) async {
    await _repository.deleteNote(id);
    loadNotes();
  }

  // 🔴 新增：清空回收站
  Future<void> emptyTrash() async {
    // 获取所有已删除的笔记副本，避免遍历时修改集合导致的问题
    final trash = List<Note>.from(trashNotes);
    for (var note in trash) {
      await _repository.deleteNote(note.id);
    }
    loadNotes();
  }

  List<Note> searchNotes(String query) {
    // 搜索也应该只搜索未删除的笔记
    return _repository.searchNotes(query).where((n) => !n.isDeleted).toList();
  }
}