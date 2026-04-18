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
import '../../core/services/webdav_sync_service.dart';
import '../repositories/category_repository.dart';
import '../repositories/tag_repository.dart';

import '../../core/services/privacy_service.dart';

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

  // 🌟 架构师特供：内存级私密笔记追踪器 (不污染数据库结构)
  final Set<String> _secretNoteIds = {};

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
  // 🌟 核心拦截 1：出库解密管线 (Read Pipeline)
  // =========================================================================
  Future<void> loadNotes() async {
    await _repository.searchNotes(_searchQuery, _selectedCategoryId);
    _categories = _categoryRepository.getAllCategories();
    _tags = _tagRepository.getAllTags();

    // 获取底层真实数据 (包含乱码密文)
    final rawNotes = _repository.getAllNotes();
    final privacy = PrivacyService();

    _secretNoteIds.clear();
    _plainTextCache.clear(); // 🌟 清除缓存，确保获取最新内容

    // 内存级清洗：瞬间解密
    _notes = rawNotes.map((n) {
      final isEncrypted = n.title.startsWith('AES_V1::') || n.content.startsWith('AES_V1::');
      if (isEncrypted) {
        _secretNoteIds.add(n.id); // 登记为私密笔记
        // 🌟 如果隐私服务已锁定，不解密，但设置 isPrivate 为 true
        if (!privacy.isUnlocked) {
          return n.copyWith(isPrivate: true); // 返回加密笔记，但标记为隐私
        }
        // 解密并设置 isPrivate 为 true
        return n.copyWith(
          title: privacy.decryptText(n.title),
          content: privacy.decryptText(n.content),
          isPrivate: true,
        );
      }
      return n;
    }).toList();

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
      _runTagGC();
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
  // 🌟 核心拦截 2：入库加密管线 (Write Pipeline)
  // =========================================================================
  Future<Note> addNote({
    required String title,
    required String content,
    List<String> tagIds = const [],
    String? categoryId,
    bool isPrivate = false,
    List<String> imagePaths = const [],
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
      isPrivate: isPrivate,
      imagePaths: imagePaths,
    );

    await _repository.addNote(note);
    
    // 🌟 如果是隐私笔记，登记到私密笔记集合
    if (isPrivate) {
      _secretNoteIds.add(note.id);
    }
    
    loadNotes();
    _triggerBackgroundSync();
    return note;
  }

  Future<void> updateNote(Note note) async {
    final privacy = PrivacyService();
    final isSecret = _secretNoteIds.contains(note.id);

    // 🌟 致命防线：如果引擎锁定，禁止保存私密笔记！
    // 防止用户在未解锁状态下编辑笔记，将 "🔒 [私密内容...]" 提示语当成明文覆写进数据库
    if (isSecret && !privacy.isUnlocked) {
      debugPrint('🛡️ [安全拦截] 引擎处于锁定状态，拒绝覆写极密数据！');
      return;
    }

    final finalTitle = isSecret ? privacy.encryptText(note.title) : note.title;
    final finalContent = isSecret ? privacy.encryptText(note.content) : note.content;

    final updatedNote = note.copyWith(
        title: finalTitle,
        content: finalContent,
        version: note.version + 1,
        updatedAt: DateTime.now()
    );

    await _repository.updateNote(updatedNote);
    loadNotes();
    _runTagGC();
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
    _runTagGC();
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
    _runTagGC();
    _triggerBackgroundSync();
  }

  Future<void> _cleanUpOldTrash() async {
    if (Supabase.instance.client.auth.currentUser == null) return;

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
      await _runImageGC();
    }
    await _runTagGC();
  }

  Future<void> _runImageGC() async {
    if (_notes.isEmpty || Supabase.instance.client.auth.currentUser == null) return;
    await _imageService.cleanUpUnusedImages(_repository.getAllNotes());
  }

  Future<void> _runTagGC() async {
    if (_notes.isEmpty || Supabase.instance.client.auth.currentUser == null) return;

    final allTags = _tagRepository.getAllTags();
    if (allTags.isEmpty) return;

    final validTagIds = allTags.where((t) => !t.isDeleted).map((t) => t.id).toSet();

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

    final usedTagIds = <String>{};
    for (var note in _notes) {
      usedTagIds.addAll(note.tagIds);
    }

    final now = DateTime.now();
    List<String> orphans = [];
    for (var tag in allTags) {
      if (tag.isDeleted || (!usedTagIds.contains(tag.id) && now.difference(tag.createdAt).inMinutes > 60)) {
        orphans.add(tag.id);
        await _tagRepository.deleteTag(tag.id);
      }
    }

    if (orphans.isNotEmpty) {
      _tags = _tagRepository.getAllTags();
      notifyListeners();

      try {
        final prefs = await SharedPreferences.getInstance();
        final syncMode = prefs.getString('sync_mode') ?? 'supabase';
        if (syncMode == 'supabase' && Supabase.instance.client.auth.currentUser != null) {
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