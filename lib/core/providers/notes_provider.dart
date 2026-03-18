import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/repositories/note_repository.dart';
import '../../models/note.dart';
import '../../core/services/image_storage_service.dart';
import '../../core/services/supabase_sync_service.dart';

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
  final Uuid _uuid = const Uuid();

  List<Note> _notes = [];
  List<Note> _filteredNotes = [];

  final Map<String, String> _plainTextCache = {};
  final ImageStorageService _imageService = ImageStorageService();
  List<String> _manualCategories = [];

  String? _selectedCategory;
  String _searchQuery = '';
  NoteSortOption _sortOption = NoteSortOption.updatedNewest;

  Timer? _debounceTimer;

  late final SupabaseSyncService _syncService;
  Timer? _syncTimer;

  SyncState _syncState = SyncState.idle;
  SyncState get syncState => _syncState;

  void _setSyncState(SyncState state) {
    _syncState = state;
    notifyListeners();
  }

  NotesProvider(this._repository) {
    WidgetsBinding.instance.addObserver(this);
    _syncService = SupabaseSyncService(_repository);

    loadNotes();
    _loadManualCategories();
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
    super.dispose();
  }

  Future<void> syncWithCloud() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      _setSyncState(SyncState.unauthenticated);
      return;
    }
    if (_syncState == SyncState.syncing) return;

    _setSyncState(SyncState.syncing);

    try {
      await _syncService.syncNotes(
        onTextSyncComplete: () {
          _plainTextCache.clear();
          loadNotes();
        },
      );

      // 🟢 修复：每次同步笔记后，强制同步一次分类
      await _loadManualCategories();

      _plainTextCache.clear();
      loadNotes();

      _setSyncState(SyncState.success);
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (_syncState == SyncState.success) _setSyncState(SyncState.idle);
      });
    } catch (e) {
      _setSyncState(SyncState.error);
      Future.delayed(const Duration(seconds: 3), () {
        if (_syncState == SyncState.error) _setSyncState(SyncState.idle);
      });
    }
  }
  /// 🟢 后台防抖同步（静默触发，不阻塞 UI）
  void _triggerBackgroundSync() {
    _syncTimer?.cancel();
    // 等待 5 秒钟，如果这期间用户没有新的操作，就在后台默默同步
    _syncTimer = Timer(const Duration(seconds: 5), () {
      syncWithCloud();
    });
  }

  // Getters
  List<Note> get notes => _notes.where((n) => !n.isDeleted).toList();
  List<Note> get trashNotes => _notes.where((n) => n.isDeleted).toList();
  List<Note> get filteredNotes => _filteredNotes;

  String? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  NoteSortOption get sortOption => _sortOption;

  List<String> get categories {
    final Set<String> uniqueCategories = {};
    uniqueCategories.addAll(_manualCategories);
    for (var note in notes) {
      if (note.category != null && note.category!.isNotEmpty) {
        uniqueCategories.add(note.category!);
      }
    }
    return uniqueCategories.toList()..sort();
  }

  // --- 手动分类持久化 ---
  Future<void> _loadManualCategories() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. 先读取本地缓存（保证页面秒开）
    _manualCategories = prefs.getStringList('custom_categories') ?? [];
    notifyListeners();

    // 2. 主动向云端请求最新数据进行合并（解决多设备不同步）
    try {
      final res = await Supabase.instance.client.auth.getUser(); // 强制网络请求
      final user = res.user;
      if (user != null && user.userMetadata != null) {
        final cloudCategories = user.userMetadata!['custom_categories'];
        if (cloudCategories != null && cloudCategories is List) {
          final List<String> cloudList = List<String>.from(cloudCategories);

          // 合并本地与云端分类并去重
          final Set<String> merged = {..._manualCategories, ...cloudList};
          _manualCategories = merged.toList();

          // 重新存入本地
          await prefs.setStringList('custom_categories', _manualCategories);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('拉取云端分类失败: $e');
    }
  }

  Future<void> _saveManualCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_categories', _manualCategories);

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final currentData = Map<String, dynamic>.from(user.userMetadata ?? {});
      currentData['custom_categories'] = _manualCategories;
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(data: currentData),
        );
      } catch (e) {
        debugPrint('分类同步到云端失败: $e');
      }
    }
  }
  Future<void> addCategory(String category) async {
    if (category.trim().isEmpty) return;
    final cleanName = category.trim();
    if (categories.contains(cleanName)) return;

    _manualCategories.add(cleanName);
    await _saveManualCategories();
    notifyListeners();
  }

  String _getNotePlainText(Note note) {
    if (_plainTextCache.containsKey(note.id)) {
      return _plainTextCache[note.id]!;
    }
    final text = note.plainText;
    _plainTextCache[note.id] = text;
    return text;
  }

  void loadNotes() {
    _notes = _repository.getAllNotes();
    _applyFilters();
  }

  void _applyFilters() {
    final sourceNotes = notes;

    var result =
        _selectedCategory == null
            ? List<Note>.from(sourceNotes)
            : sourceNotes
                .where((note) => note.category == _selectedCategory)
                .toList();

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result =
          result.where((n) {
            final cachedPlainText = _getNotePlainText(n).toLowerCase();
            return n.title.toLowerCase().contains(query) ||
                cachedPlainText.contains(query) ||
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
    _plainTextCache[note.id] = note.plainText;
    loadNotes();
    _triggerBackgroundSync();
    return note;
  }

  Future<void> updateNote(Note note) async {
    final updatedNote = note.copyWith(updatedAt: DateTime.now());
    await _repository.updateNote(updatedNote);
    _plainTextCache[updatedNote.id] = updatedNote.plainText;
    loadNotes();
    _triggerBackgroundSync();
  }

  Future<void> deleteNote(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final note = _notes[index];
      // 🟢 [关键修改] 移入回收站时，更新 updatedAt 为当前时间。
      // 这样这个时间就等同于 "deletedAt" (被删除的时间)，作为 30 天倒计时的起点。
      await _repository.updateNote(
        note.copyWith(isDeleted: true, updatedAt: DateTime.now()),
      );
      loadNotes();
      _triggerBackgroundSync();
    }
  }

  Future<void> restoreNote(String id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index != -1) {
      final note = _notes[index];
      // 🟢 恢复笔记时，也将修改时间重置为当前时间
      await _repository.updateNote(
        note.copyWith(isDeleted: false, updatedAt: DateTime.now()),
      );
      loadNotes();
      _triggerBackgroundSync();
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

  // --- 🟢 [新增核心逻辑] 自动清理 30 天前的垃圾 ---
  Future<void> _cleanUpOldTrash() async {
    final now = DateTime.now();
    bool hasDeletedAny = false;

    // 使用当前 trashNotes 的拷贝来遍历，避免遍历时修改列表导致报错
    final currentTrash = List<Note>.from(trashNotes);

    for (var note in currentTrash) {
      // 因为在 deleteNote 时我们更新了 updatedAt，这里直接算差值就是呆在回收站的天数
      final difference = now.difference(note.updatedAt).inDays;

      // 超过 30 天，无情抹除
      if (difference >= 30) {
        await _repository.deleteNote(note.id);
        _plainTextCache.remove(note.id);
        hasDeletedAny = true;
      }
    }

    // 如果真的删除了过期笔记，通知 UI 刷新并清理图片垃圾
    if (hasDeletedAny) {
      loadNotes();
      _runImageGC();
    }
  }

  Future<void> _runImageGC() async {
    final allNotes = _repository.getAllNotes();
    await _imageService.cleanUpUnusedImages(allNotes);
  }

  // --- 分类管理逻辑 ---

  Future<void> renameCategory(String oldName, String newName) async {
    if (oldName == newName) return;

    final targetNotes = _notes.where((n) => n.category == oldName).toList();
    for (var note in targetNotes) {
      final updated = note.copyWith(
        category: newName,
        updatedAt: DateTime.now(),
      );
      await _repository.updateNote(updated);
    }

    if (_manualCategories.contains(oldName)) {
      final index = _manualCategories.indexOf(oldName);
      _manualCategories[index] = newName;
      await _saveManualCategories();
    } else {
      if (!_manualCategories.contains(newName)) {
        _manualCategories.add(newName);
        await _saveManualCategories();
      }
    }

    loadNotes();
  }

  Future<void> deleteCategory(String categoryName) async {
    final targetNotes =
        _notes.where((n) => n.category == categoryName).toList();
    for (var note in targetNotes) {
      final updated = note.copyWith(
        clearCategory: true,
        updatedAt: DateTime.now(),
      );
      await _repository.updateNote(updated);
    }

    if (_manualCategories.contains(categoryName)) {
      _manualCategories.remove(categoryName);
      await _saveManualCategories();
    }

    loadNotes();
  }

  Future<void> clearLocalData() async {
    final allNotes = _repository.getAllNotes();
    for (var note in allNotes) {
      await _repository.deleteNote(note.id);
    }
    _notes.clear();
    _filteredNotes.clear();
    _manualCategories.clear();
    notifyListeners();
  }
}
