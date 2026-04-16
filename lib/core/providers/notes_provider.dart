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

  String? _selectedCategoryId;
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
    if (state == AppLifecycleState.resumed) syncWithCloud();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _syncTimer?.cancel();
    _dbSubscription?.cancel();
    super.dispose();
  }

  // 给 UI 提供数据时，坚决不给 isDeleted == true 的死数据！
  List<Category> get categories => _categories.where((c) => !c.isDeleted).toList();
  List<Tag> get tags => _tags.where((t) => !t.isDeleted).toList();

  Category? getCategoryById(String? id) {
    if (id == null) return null;
    try {
      return _categories.firstWhere((c) => c.id == id && !c.isDeleted);
    } catch (e) {
      return null;
    }
  }

  Tag? getTagById(String? id) {
    if (id == null) return null;
    try {
      return _tags.firstWhere((t) => t.id == id && !t.isDeleted);
    } catch (e) {
      return null;
    }
  }

  // =========================================================================
  // 核心加载与同步
  // =========================================================================
  Future<void> loadNotes() async {
    await _repository.searchNotes(_searchQuery, _selectedCategoryId);
    _categories = _categoryRepository.getAllCategories();
    _tags = _tagRepository.getAllTags();
    _notes = _repository.getAllNotes();
    _applyFilters();
  }

  Future<bool> _isSyncAllowed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isAutoSyncEnabled') ?? false;
  }

  Future<void> syncWithCloud() async {
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
      _runTagGC(); // 🌟 同步完成后触发一波清理
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
  // 核心笔记数据写入
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
      version: 1,
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
    final updatedNote = note.copyWith(
        version: note.version + 1,
        updatedAt: DateTime.now()
    );
    await _repository.updateNote(updatedNote);
    _plainTextCache[updatedNote.id] = updatedNote.plainText;
    loadNotes();
    _runTagGC(); // 🌟 保存笔记时触发垃圾回收
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
    _runTagGC(); // 🌟 彻底删除笔记时触发垃圾回收
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
    _runTagGC(); // 🌟 清空回收站时触发垃圾回收
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
    _runTagGC(); // 🌟 启动 App 时执行全量体检扫除
  }

  Future<void> _runImageGC() async {
    await _imageService.cleanUpUnusedImages(_repository.getAllNotes());
  }

  // =========================================================================
  // 🌟 V2: 标签 Auto-GC 自动垃圾回收引擎
  // =========================================================================
  Future<void> _runTagGC() async {
    final allTags = _tagRepository.getAllTags();
    final validTagIds = allTags.where((t) => !t.isDeleted).map((t) => t.id).toSet();

    // 1. 自动剥离：遍历所有笔记，如果身上挂着被软删的幽灵标签，强行解绑！
    bool noteChanged = false;
    for (var note in _notes) {
      final cleanTagIds = note.tagIds.where((id) => validTagIds.contains(id)).toList();
      if (cleanTagIds.length != note.tagIds.length) {
        await _repository.updateNote(note.copyWith(
            tagIds: cleanTagIds,
            version: note.version + 1,
            updatedAt: DateTime.now()
        ));
        noteChanged = true;
      }
    }
    if (noteChanged) loadNotes();

    // 2. 收集正在使用的标签 (因为上一步解绑，这里收集的绝对是合法标签)
    final usedTagIds = <String>{};
    for (var note in _notes) {
      usedTagIds.addAll(note.tagIds);
    }

    // 3. 找出真正的孤儿
    final now = DateTime.now();
    List<String> orphans = [];
    for (var tag in allTags) {
      // 判定标准：已被软删的、或者 (没有被使用 且 存活超过1小时的新兵保护期)
      if (tag.isDeleted || (!usedTagIds.contains(tag.id) && now.difference(tag.createdAt).inMinutes > 60)) {
        orphans.add(tag.id);
        await _tagRepository.deleteTag(tag.id); // 本地物理销毁
      }
    }

    // 4. 云端核弹抹除
    if (orphans.isNotEmpty) {
      _tags = _tagRepository.getAllTags();
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        final syncMode = prefs.getString('sync_mode') ?? 'supabase';
        if (syncMode == 'supabase' && Supabase.instance.client.auth.currentUser != null) {
          // 如果垃圾太多，分批次删除防报错
          for (var i = 0; i < orphans.length; i += 50) {
            final chunk = orphans.sublist(i, i + 50 > orphans.length ? orphans.length : i + 50);
            await Supabase.instance.client.from('tags').delete().inFilter('id', chunk);
          }
          debugPrint('🧹 [TAG-GC] 成功清理云端孤儿标签: ${orphans.length} 个');
        }
      } catch (e) {
        debugPrint('🧹 [TAG-GC] 云端标签清理失败: $e');
      }
    }
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

  // =========================================================================
  // 🌟 分类管理 (分类仍需要手动管理)
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

  // 🌟 强力解绑：删除分类时，将原本属于它的笔记释放为“无分类”
  Future<void> deleteCategory(String id) async {
    await _categoryRepository.deleteCategory(id);
    await _syncService.recordDeletedCategory(id);

    // 释放笔记
    for (var note in _notes) {
      if (note.categoryId == id) {
        final updatedNote = note.copyWith(
            clearCategory: true,
            version: note.version + 1,
            updatedAt: DateTime.now()
        );
        await _repository.updateNote(updatedNote);
        _plainTextCache[updatedNote.id] = updatedNote.plainText;
      }
    }

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
  Note? getNoteById(String id) {
    try {
      return notes.firstWhere((note) => note.id == id);
    } catch (e) {
      return null;
    }
  }
}