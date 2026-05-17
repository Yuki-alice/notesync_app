import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../../models/note.dart';
import '../services/performance/perf.dart';

class NoteRepository {
  final Isar _isar;
  List<Note>? _allNotesCache;

  NoteRepository(this._isar);

  Future<void> init() async {}

  Note? getNoteById(String id) {
    return Perf.traceSync('repo.note.getById', () {
      return _isar.notes.where().idEqualTo(id).findFirstSync();
    }, metadata: {'id': id});
  }

  Map<String, DateTime> getAllNotesMetadata() {
    final notes = _isar.notes.where().findAllSync();
    return {for (var note in notes) note.id: note.updatedAt};
  }

  /// 🌟 获取包含版本号的元数据（用于同步冲突检测）
  Map<String, NoteSyncMeta> getAllNotesMetadataWithVersion() {
    final notes = _isar.notes.where().findAllSync();
    return {
      for (var note in notes)
        note.id: NoteSyncMeta(
          updatedAt: note.updatedAt,
          version: note.version,
        )
    };
  }

  List<Note> getAllNotes() {
    return Perf.traceSync('repo.note.getAll', () {
      try {
        if (_allNotesCache != null) {
          return _allNotesCache!;
        }
        debugPrint('[CACHE] getAllNotes MISS → querying DB');
        final notes = _isar.notes.where().findAllSync();
        notes.sort((a, b) {
          if (a.isPinned != b.isPinned) {
            return a.isPinned ? -1 : 1;
          }
          return b.updatedAt.compareTo(a.updatedAt);
        });
        _allNotesCache = notes;
        debugPrint('[CACHE] getAllNotes cached ${notes.length} notes');
        return notes;
      } catch (e) {
        debugPrint('Repo Error (getAllNotes): $e');
        return [];
      }
    });
  }

  void invalidateCache() {
    _allNotesCache = null;
    debugPrint('[CACHE] getAllNotes cache invalidated');
  }

  Future<void> addNote(Note note) async {
    await Perf.trace('repo.note.add', () => _isar.writeTxn(() async {
      await _isar.notes.put(note);
    }));
    invalidateCache();
  }

  Future<void> updateNote(Note note) async {
    await Perf.trace('repo.note.update', () => _isar.writeTxn(() async {
      note.version += 1;
      note.updatedAt = DateTime.now();
      await _isar.notes.put(note);
    }));
    invalidateCache();
  }

  /// 🌟 同步专用：保存笔记但不修改 updatedAt（保留云端时间戳）
  Future<void> saveNoteFromSync(Note note) async {
    await Perf.trace('repo.note.saveFromSync', () => _isar.writeTxn(() async {
      await _isar.notes.put(note);
    }));
    invalidateCache();
  }

  /// 🌟 同步专用：批量保存笔记（保留云端时间戳）
  Future<void> saveNotesFromSync(List<Note> notes) async {
    if (notes.isEmpty) return;
    await Perf.trace('repo.note.saveNotesFromSync', () async {
      // 🌟 优化：分批写入，每批 50 条，避免阻塞主线程
      const batchSize = 50;
      final totalBatches = (notes.length / batchSize).ceil();
      for (var i = 0; i < notes.length; i += batchSize) {
        final end = i + batchSize > notes.length ? notes.length : i + batchSize;
        final batch = notes.sublist(i, end);
        final batchIndex = (i / batchSize).floor() + 1;

        await _isar.writeTxn(() async {
          await _isar.notes.putAll(batch);
        });
        debugPrint('[SYNC] 笔记批次写入完成: $batchIndex/$totalBatches (${batch.length} 条)');

        // 让出主线程，避免阻塞 UI
        await Future.delayed(Duration.zero);
      }
    });
    invalidateCache();
  }

  Future<void> deleteNote(String id) async {
    await Perf.trace('repo.note.delete', () => _isar.writeTxn(() async {
      await _isar.notes.where().idEqualTo(id).deleteAll();
    }));
    invalidateCache();
  }

  Future<List<Note>> searchNotes(String query, String? categoryId) async {
    return await Perf.trace('repo.note.search', () async {
      var q = _isar.notes.filter().isDeletedEqualTo(false);

      if (categoryId != null && categoryId.isNotEmpty) {
        q = q.categoryIdEqualTo(categoryId);
      }

      if (query.trim().isNotEmpty) {
        q = q.group((q) => q.titleContains(query, caseSensitive: false)
            .or()
            .contentContains(query, caseSensitive: false));
      }

      return await q.sortByIsPinnedDesc().thenByUpdatedAtDesc().findAll();
    }, metadata: {'query': query, 'categoryId': categoryId});
  }

  Stream<void> watchNotesChanged() {
    return _isar.notes.watchLazy(fireImmediately: true);
  }
}

/// 🌟 笔记同步元数据（用于冲突检测）
class NoteSyncMeta {
  final DateTime updatedAt;
  final int version;

  const NoteSyncMeta({
    required this.updatedAt,
    required this.version,
  });
}