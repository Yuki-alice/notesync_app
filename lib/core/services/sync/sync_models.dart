// 共享类型、常量与日志工具
// 本文件定义 Supabase 同步体系中各子服务共享的常量、数据模型和日志类，
// 作为最底层依赖被所有子服务文件导入。

import 'package:flutter/foundation.dart';

// =========================================================================
// 共享常量
// =========================================================================

const String deletedTodosKey = 'deleted_todo_ids';
const String deletedNotesKey = 'deleted_note_ids';
const String deletedCategoriesKey = 'deleted_categories';
const String deletedTagsKey = 'deleted_tag_ids';
const String lastNoteSyncKey = 'last_sync_time';
const String lastTodoSyncKey = 'last_todo_sync_time';
const String lastSyncedVersionsKey = 'last_synced_versions';
const String imageBucket = 'note_images';
const Duration timeBuffer = Duration(seconds: 2);

// WebDAV 增量同步时间戳键
const String webdavLastNoteSyncKey = 'webdav_last_note_sync_time';
const String webdavLastTodoSyncKey = 'webdav_last_todo_sync_time';
const String webdavLastCategorySyncKey = 'webdav_last_category_sync_time';

// =========================================================================
// 日志工具
// =========================================================================

class SyncLogger {
  static void info(String module, String msg) {
    if (kDebugMode) {
      final time = DateTime.now().toIso8601String().split('T')[1].substring(0, 12);
      print('[$time] 🟢 [SYNC-$module] $msg');
    }
  }

  static void warn(String module, String msg) {
    if (kDebugMode) {
      final time = DateTime.now().toIso8601String().split('T')[1].substring(0, 12);
      print('[$time] ⚠️ [SYNC-$module] $msg');
    }
  }

  static void error(String module, String msg, [dynamic error]) {
    if (kDebugMode) {
      final time = DateTime.now().toIso8601String().split('T')[1].substring(0, 12);
      print('[$time] ❌ [SYNC-$module] $msg ${error != null ? '-> $error' : ''}');
    }
  }
}

// =========================================================================
// 同步计划与冲突模型
// =========================================================================

class SyncPlan {
  final List<String> toPull;
  final List<String> toPush;
  final List<String> toDeleteLocally;
  final List<SyncConflict> conflicts;

  SyncPlan({
    required this.toPull,
    required this.toPush,
    required this.toDeleteLocally,
    this.conflicts = const [],
  });
}

class SyncConflict {
  final String noteId;
  final int localVersion;
  final int cloudVersion;
  final DateTime localUpdatedAt;
  final DateTime cloudUpdatedAt;

  SyncConflict({
    required this.noteId,
    required this.localVersion,
    required this.cloudVersion,
    required this.localUpdatedAt,
    required this.cloudUpdatedAt,
  });
}

class CloudNoteMeta {
  final DateTime updatedAt;
  final int version;

  CloudNoteMeta({required this.updatedAt, required this.version});
}

// =========================================================================
// 同步异常
// =========================================================================

enum SyncErrorType {
  network,
  timeout,
  auth,
  server,
  quotaExceeded,
  unknown,
}

class SyncException implements Exception {
  final String message;
  final SyncErrorType type;
  final dynamic originalError;

  SyncException(
    this.message, {
    required this.type,
    this.originalError,
  });

  @override
  String toString() => 'SyncException[$type]: $message';
}
