import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'network_service.dart';

enum OfflineTaskType {
  syncNotes,
  syncTodos,
  syncCategories,
  syncTags,
  deleteNote,
  deleteTodo,
}

class OfflineTask {
  final String id;
  final OfflineTaskType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  OfflineTask({
    required this.id,
    required this.type,
    required this.payload,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
      };

  factory OfflineTask.fromJson(Map<String, dynamic> json) => OfflineTask(
        id: json['id'] as String,
        type: OfflineTaskType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => OfflineTaskType.syncNotes,
        ),
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class OfflineQueue {
  static const String _storageKey = 'offline_sync_queue';
  final List<OfflineTask> _tasks = [];
  final NetworkService _network = NetworkService();
  bool _isFlushing = false;

  int get pendingCount => _tasks.length;
  List<OfflineTask> get tasks => List.unmodifiable(_tasks);

  Future<void> init() async {
    await _loadFromDisk();
    _network.addListener(_onNetworkChanged);
  }

  void enqueue(OfflineTask task) {
    if (_network.isOnline) return;

    _tasks.add(task);
    _saveToDisk();

    if (kDebugMode) {
      debugPrint('📦 离线任务入队: ${task.type.name} (队列: ${_tasks.length})');
    }
  }

  Future<void> flush() async {
    if (_isFlushing || _tasks.isEmpty || !_network.isOnline) return;

    _isFlushing = true;
    if (kDebugMode) {
      debugPrint('🚀 开始执行离线队列 (${_tasks.length} 个任务)');
    }

    final tasksToFlush = List<OfflineTask>.from(_tasks);
    _tasks.clear();
    await _saveToDisk();

    for (final task in tasksToFlush) {
      try {
        await _executeTask(task);
        if (kDebugMode) {
          debugPrint('✅ 离线任务完成: ${task.type.name}');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ 离线任务失败: ${task.type.name} -> $e');
        }
        _tasks.add(task);
        await _saveToDisk();
      }
    }

    _isFlushing = false;

    if (kDebugMode) {
      debugPrint('🏁 离线队列执行完毕 (剩余: ${_tasks.length})');
    }
  }

  Future<void> _executeTask(OfflineTask task) async {
    _onSyncTrigger?.call();
  }

  VoidCallback? _onSyncTrigger;

  void setSyncTrigger(VoidCallback callback) {
    _onSyncTrigger = callback;
  }

  void _onNetworkChanged() {
    if (_network.isOnline) {
      flush();
    }
  }

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr != null) {
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        _tasks.clear();
        _tasks.addAll(jsonList.map((j) => OfflineTask.fromJson(j as Map<String, dynamic>)));
        if (kDebugMode && _tasks.isNotEmpty) {
          debugPrint('📂 加载离线队列: ${_tasks.length} 个任务');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ 加载离线队列失败: $e');
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _tasks.map((t) => t.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ 保存离线队列失败: $e');
    }
  }

  void clear() {
    _tasks.clear();
    _saveToDisk();
  }

  Future<void> dispose() async {
    _network.removeListener(_onNetworkChanged);
    await _saveToDisk();
  }
}
