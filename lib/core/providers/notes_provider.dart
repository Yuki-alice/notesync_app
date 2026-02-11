import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🟢 引入本地存储
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
  final Uuid _uuid = const Uuid();

  List<Note> _notes = [];
  List<Note> _filteredNotes = [];

  // 🟢 新增：用于存储用户手动创建（但可能还没写笔记）的分类
  List<String> _manualCategories = [];

  String? _selectedCategory;
  String _searchQuery = '';
  NoteSortOption _sortOption = NoteSortOption.updatedNewest;

  Timer? _debounceTimer;

  NotesProvider(this._repository) {
    loadNotes();
    _loadManualCategories(); // 🟢 初始化时加载手动分类
  }

  // Getters
  List<Note> get notes => _notes.where((n) => !n.isDeleted).toList();
  List<Note> get trashNotes => _notes.where((n) => n.isDeleted).toList();
  List<Note> get filteredNotes => _filteredNotes;

  String? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  NoteSortOption get sortOption => _sortOption;

  // 🟢 核心修改：分类列表 = 笔记中的分类 + 手动创建的分类 (去重)
  List<String> get categories {
    final Set<String> uniqueCategories = {};

    // 1. 先加入手动创建的
    uniqueCategories.addAll(_manualCategories);

    // 2. 再加入笔记中存在的
    for (var note in this.notes) {
      if (note.category != null && note.category!.isNotEmpty) {
        uniqueCategories.add(note.category!);
      }
    }
    return uniqueCategories.toList()..sort();
  }

  // --- 🟢 手动分类的持久化逻辑 ---

  Future<void> _loadManualCategories() async {
    final prefs = await SharedPreferences.getInstance();
    _manualCategories = prefs.getStringList('custom_categories') ?? [];
    notifyListeners();
  }

  Future<void> _saveManualCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_categories', _manualCategories);
  }

  /// 🟢 新增：添加分类
  Future<void> addCategory(String category) async {
    if (category.trim().isEmpty) return;
    final cleanName = category.trim();

    // 如果已经存在（无论是手动列表里还是笔记里），就不重复加了
    if (categories.contains(cleanName)) return;

    _manualCategories.add(cleanName);
    await _saveManualCategories();
    notifyListeners();
  }

  // --- 原有逻辑 ---

  void loadNotes() {
    _notes = _repository.getAllNotes();
    _applyFilters();
  }

  void _applyFilters() {
    final sourceNotes = this.notes;

    var result = _selectedCategory == null
        ? List<Note>.from(sourceNotes)
        : sourceNotes.where((note) => note.category == _selectedCategory).toList();

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((n) {
        return n.title.toLowerCase().contains(query) ||
            n.plainText.toLowerCase().contains(query) ||
            n.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    result.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      switch (_sortOption) {
        case NoteSortOption.updatedNewest:
          return b.updatedAt.compareTo(a.updatedAt);
        case NoteSortOption.createdNewest:
          return b.createdAt.compareTo(a.createdAt);
        case NoteSortOption.titleAZ:
          return a.title.compareTo(b.title);
      }
    });

    _filteredNotes = result;
    notifyListeners();
  }

  void selectCategory(String? category) {
    _selectedCategory = category;
    _applyFilters();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _applyFilters();
    });
  }

  void changeSortOption(NoteSortOption option) {
    _sortOption = option;
    _applyFilters();
  }

  Future<void> togglePin(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final note = _notes[index];
      await updateNote(note.copyWith(isPinned: !note.isPinned));
    }
  }

  Future<Note> addNote({
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
    return note;
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

  // 🟢 修改：重命名分类 (同时更新笔记和手动列表)
  Future<void> renameCategory(String oldName, String newName) async {
    if (oldName == newName) return;

    // 1. 更新笔记中的分类
    final targetNotes = _notes.where((n) => n.category == oldName).toList();
    for (var note in targetNotes) {
      final updated = note.copyWith(category: newName, updatedAt: DateTime.now());
      await _repository.updateNote(updated);
    }

    // 2. 如果该分类也在手动列表里，也需要重命名
    if (_manualCategories.contains(oldName)) {
      final index = _manualCategories.indexOf(oldName);
      _manualCategories[index] = newName;
      await _saveManualCategories();
    } else {
      // 如果它本来不在手动列表里（是纯动态的），重命名后我们通常希望它变为“手动管理的”，防止因为笔记被移走而消失
      // 可选策略：重命名操作往往意味着用户很在意这个新分类名，所以可以加入手动列表
      if (!_manualCategories.contains(newName)) {
        _manualCategories.add(newName);
        await _saveManualCategories();
      }
    }

    loadNotes();
  }

  // 🟢 修改：删除分类 (同时移除笔记关联和手动列表)
  Future<void> deleteCategory(String categoryName) async {
    // 1. 清除笔记关联
    final targetNotes = _notes.where((n) => n.category == categoryName).toList();
    for (var note in targetNotes) {
      final updated = note.copyWith(clearCategory: true, updatedAt: DateTime.now());
      await _repository.updateNote(updated);
    }

    // 2. 从手动列表中移除
    if (_manualCategories.contains(categoryName)) {
      _manualCategories.remove(categoryName);
      await _saveManualCategories();
    }

    loadNotes();
  }
}