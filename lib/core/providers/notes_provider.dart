import 'dart:async';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/repositories/note_repository.dart';

import '../../models/note.dart';
import '../../models/category.dart';
import '../../models/tag.dart';
import '../../core/services/image_storage_service.dart';
import '../../core/services/supabase_sync_service.dart';
import '../repositories/category_repository.dart';
import '../repositories/tag_repository.dart';
import '../../core/services/webdav_sync_service.dart';

enum SyncState { idle, syncing, success, error, unauthenticated }

enum NoteSortOption {
  updatedNewest('最近修改'),
  createdNewest('最近创建'),
  titleAZ('标题 A-Z');

  final String label;
  const NoteSortOption(this.label);
}

StreamSubscription<void>? _dbSubscription;

class NotesProvider with ChangeNotifier, WidgetsBindingObserver {
  final NoteRepository _repository;
  final CategoryRepository _categoryRepository;
  final TagRepository _tagRepository;
  final Uuid _uuid = const Uuid();

  List<Note> _notes = [];
  List<Note> _filteredNotes = [];


  List<Category> _categories = [];
  List<Tag> _tags = [];

  final Map<String, String> _plainTextCache = {};
  final ImageStorageService _imageService = ImageStorageService();

  String? _selectedCategoryId; // 🌟 改为按 ID 筛选
  String _searchQuery = '';
  NoteSortOption _sortOption = NoteSortOption.updatedNewest;

  Timer? _debounceTimer;
  late final SupabaseSyncService _syncService;
  Timer? _syncTimer;

  SyncState _syncState = SyncState.idle;
  SyncState get syncState => _syncState;
  StreamSubscription<void>? _dbSubscription;

  void _setSyncState(SyncState state) {
    _syncState = state;
    notifyListeners();
  }

  // 🌟 构造函数注入新仓库
  NotesProvider(this._repository, this._categoryRepository, this._tagRepository) {
    WidgetsBinding.instance.addObserver(this);
    _syncService = SupabaseSyncService(_repository, null, _categoryRepository, _tagRepository);
    _dbSubscription = _repository.watchNotesChanged().listen((_) {
      loadNotes();
    });
    loadNotes();
    _cleanUpOldTrash();
    syncWithCloud();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      syncWithCloud();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _syncTimer?.cancel();
    _dbSubscription?.cancel();
    super.dispose();
  }

  // =========================================================================
  // 🌟 V2: 内存透视镜 (暴露给 UI 翻译 ID 用的)
  // =========================================================================
  List<Category> get categories => _categories;
  List<Tag> get tags => _tags;

  Category? getCategoryById(String? id) {
    if (id == null) return null;
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  Tag? getTagById(String? id) {
    if (id == null) return null;
    try {
      return _tags.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  // =========================================================================
  // 核心加载与同步
  // =========================================================================
  Future<void> loadNotes() async {
    final results = await _repository.searchNotes(_searchQuery, _selectedCategoryId);
    _categories = _categoryRepository.getAllCategories();
    _tags = _tagRepository.getAllTags();
    _notes = _repository.getAllNotes();
    _applyFilters();
  }

  Future<Tag> createTag(String name) async {
    final tag = Tag(
      id: const Uuid().v4(),
      name: name,
      createdAt: DateTime.now(),
    );
    await _tagRepository.addTag(tag);
    loadNotes();
    _triggerBackgroundSync();
    return tag;
  }
  Future<bool> _isSyncAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isAutoSyncEnabled') ?? false;
  }

  Future<void> syncWithCloud() async {
    // 1. 检查总闸
    if (!await _isSyncAllowed()) return;

    if (_syncState == SyncState.syncing) return;
    _setSyncState(SyncState.syncing);

    try {
      final prefs = await SharedPreferences.getInstance();

      final syncMode = prefs.getString('sync_mode') ?? 'supabase';

      if (syncMode == 'webdav') {
        final webDavService = WebDavSyncService(Isar.getInstance()!);
        await webDavService.syncAll();
        _plainTextCache.clear();
      } else {

        if (Supabase.instance.client.auth.currentUser == null) {
          _setSyncState(SyncState.unauthenticated);
          return;
        }
        await _syncService.syncNotes(onTextSyncComplete: () => loadNotes());
      }
      loadNotes();
      _setSyncState(SyncState.success);
    } catch (e) {
      _setSyncState(SyncState.error);
    }
  }

  void _triggerBackgroundSync() async{
    _syncTimer?.cancel();
    if(!await _isSyncAllowed()) return;
    _syncTimer = Timer(const Duration(seconds: 5), () {
      syncWithCloud();
    });
  }

  // Getters
  List<Note> get notes => _notes.where((n) => !n.isDeleted).toList();
  List<Note> get trashNotes => _notes.where((n) => n.isDeleted).toList();
  List<Note> get filteredNotes => _filteredNotes;
  String? get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  NoteSortOption get sortOption => _sortOption;

  String _getNotePlainText(Note note) {
    if (_plainTextCache.containsKey(note.id)) return _plainTextCache[note.id]!;
    final text = note.plainText;
    _plainTextCache[note.id] = text;
    return text;
  }

  void _applyFilters() {
    final sourceNotes = notes;

    var result = _selectedCategoryId == null
        ? List<Note>.from(sourceNotes)
        : sourceNotes.where((note) => note.categoryId == _selectedCategoryId).toList();

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((n) {
        final cachedPlainText = _getNotePlainText(n).toLowerCase();

        // 🌟 V2: 搜索时，将 tagId 翻译成 tagName 再对比！
        final tagNames = n.tagIds.map((id) => getTagById(id)?.name.toLowerCase() ?? '').toList();

        return n.title.toLowerCase().contains(query) ||
            cachedPlainText.contains(query) ||
            tagNames.any((name) => name.contains(query));
      }).toList();
    }

    result.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      switch (_sortOption) {
        case NoteSortOption.updatedNewest: return b.updatedAt.compareTo(a.updatedAt);
        case NoteSortOption.createdNewest: return b.createdAt.compareTo(a.createdAt);
        case NoteSortOption.titleAZ: return a.title.compareTo(b.title);
      }
    });

    _filteredNotes = result;
    notifyListeners();
  }

  void selectCategory(String? categoryId) {
    _selectedCategoryId = categoryId;
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

  // =========================================================================
  // 🌟 V2: 核心笔记数据写入 (版本号递增)
  // =========================================================================
  Future<Note> addNote({
    required String title,
    required String content,
    List<String> tagIds = const [],
    String? categoryId,
  }) async {
    final note = Note(
      id: _uuid.v4(),
      title: title,
      content: content,
      tagIds: tagIds,
      categoryId: categoryId,
      version: 1, // 🌟 V2 新增
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isPinned: false,
      isDeleted: false,
    );
    await _repository.addNote(note);
    _plainTextCache[note.id] = note.plainText;
    loadNotes();
    _triggerBackgroundSync();
    return note;
  }

  Future<void> updateNote(Note note) async {
    // 🌟 V2 核心：每次修改，版本号必须 +1，时间刷新
    final updatedNote = note.copyWith(
        version: note.version + 1,
        updatedAt: DateTime.now()
    );
    await _repository.updateNote(updatedNote);
    _plainTextCache[updatedNote.id] = updatedNote.plainText;
    loadNotes();
    _triggerBackgroundSync();
  }

  Future<void> togglePin(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      await updateNote(_notes[index].copyWith(isPinned: !_notes[index].isPinned));
    }
  }

  Future<void> deleteNote(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      await updateNote(_notes[index].copyWith(isDeleted: true));
    }
  }

  Future<void> restoreNote(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      await updateNote(_notes[index].copyWith(isDeleted: false));
    }
  }

  Future<void> deleteNoteForever(String id) async {
    await _repository.deleteNote(id);
    _plainTextCache.remove(id);
    loadNotes();
    await _syncService.recordDeletedNoteId(id);
    _runImageGC();
    _triggerBackgroundSync();
  }

  Future<void> emptyTrash() async {
    final trash = List<Note>.from(trashNotes);
    for (var note in trash) {
      await _repository.deleteNote(note.id);
      _plainTextCache.remove(note.id);
      await _syncService.recordDeletedNoteId(note.id);
    }
    loadNotes();
    _runImageGC();
    _triggerBackgroundSync();
  }

  Future<void> _cleanUpOldTrash() async {
    final now = DateTime.now();
    bool hasDeletedAny = false;
    final currentTrash = List<Note>.from(trashNotes);
    for (var note in currentTrash) {
      if (now.difference(note.updatedAt).inDays >= 30) {
        await _repository.deleteNote(note.id);
        _plainTextCache.remove(note.id);
        hasDeletedAny = true;
      }
    }
    if (hasDeletedAny) {
      loadNotes();
      _runImageGC();
    }
  }

  Future<void> _runImageGC() async {
    await _imageService.cleanUpUnusedImages(_repository.getAllNotes());
  }

  // =========================================================================
  // 🌟 V2: 分类管理 (由于已交由 CategoryRepository，这里大大简化)
  // =========================================================================
  Future<void> addCategory(String name) async {
    final newCat = Category(
      id: _uuid.v4(),
      name: name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _categoryRepository.addCategory(newCat);
    loadNotes();
    _triggerBackgroundSync();
  }

  Future<void> renameCategory(String id, String newName) async {
    final cat = getCategoryById(id);
    if (cat != null) {
      await _categoryRepository.updateCategory(cat.copyWith(name: newName, updatedAt: DateTime.now()));
      loadNotes();
      _triggerBackgroundSync();
    }
  }

  Future<void> deleteCategory(String id) async {
    await _categoryRepository.deleteCategory(id);
    await _syncService.recordDeletedCategory(id);
    loadNotes();
    _triggerBackgroundSync();
  }

  void clearLocalData() {
    _debounceTimer?.cancel();
    _syncTimer?.cancel();
    _plainTextCache.clear();
    _selectedCategoryId = null;
    _searchQuery = '';
    _notes.clear();
    _filteredNotes.clear();
    _categories.clear();
    _tags.clear();
    notifyListeners();
  }
  void clearTimers(){
    _debounceTimer?.cancel();
    _syncTimer?.cancel();
  }

}