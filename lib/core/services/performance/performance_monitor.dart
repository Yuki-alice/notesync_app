import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 性能日志条目
class PerformanceLog {
  final String label;
  final int durationMs;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  PerformanceLog({
    required this.label,
    required this.durationMs,
    required this.timestamp,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
    'label': label,
    'durationMs': durationMs,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };

  factory PerformanceLog.fromJson(Map<String, dynamic> json) {
    return PerformanceLog(
      label: json['label'] as String,
      durationMs: json['durationMs'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// 性能统计信息
class PerformanceStats {
  final int count;
  final int totalMs;
  final int maxMs;
  final int minMs;
  final double avgMs;

  PerformanceStats({
    required this.count,
    required this.totalMs,
    required this.maxMs,
    required this.minMs,
    required this.avgMs,
  });

  Map<String, dynamic> toJson() => {
    'count': count,
    'totalMs': totalMs,
    'maxMs': maxMs,
    'minMs': minMs,
    'avgMs': avgMs.toStringAsFixed(2),
  };
}

/// 自定义性能监控器
///
/// 轻量级性能监控，无需第三方依赖。
/// 记录方法耗时，支持统计报告和日志导出。
class CustomPerformanceMonitor {
  static final CustomPerformanceMonitor _instance = CustomPerformanceMonitor._internal();
  factory CustomPerformanceMonitor() => _instance;
  CustomPerformanceMonitor._internal();

  final List<PerformanceLog> _logs = [];
  static const int _maxLogCount = 1000;

  /// 慢操作阈值（毫秒）— 云端同步等网络操作天然较慢，设为 3 秒
  static const int _slowThresholdMs = 3000;

  /// 是否启用监控
  bool _enabled = true;
  bool get enabled => _enabled;

  /// 启用/禁用监控
  void setEnabled(bool value) => _enabled = value;

  /// 记录性能数据
  void record(String label, int durationMs, {Map<String, dynamic>? metadata}) {
    if (!_enabled) return;

    if (_logs.length >= _maxLogCount) {
      _logs.removeAt(0);
    }

    _logs.add(PerformanceLog(
      label: label,
      durationMs: durationMs,
      timestamp: DateTime.now(),
      metadata: metadata,
    ));

    // 超过阈值打印警告（仅在 debug 模式）
    if (durationMs > _slowThresholdMs && kDebugMode) {
      debugPrint('🐌 性能警告: $label 耗时 ${durationMs}ms');
    }
  }

  /// 获取指定标签的统计信息
  PerformanceStats? getStats(String label) {
    final filtered = _logs.where((l) => l.label == label).toList();
    if (filtered.isEmpty) return null;

    final durations = filtered.map((l) => l.durationMs).toList();
    final total = durations.reduce((a, b) => a + b);

    return PerformanceStats(
      count: filtered.length,
      totalMs: total,
      maxMs: durations.reduce((a, b) => a > b ? a : b),
      minMs: durations.reduce((a, b) => a < b ? a : b),
      avgMs: total / filtered.length,
    );
  }

  /// 获取所有标签的统计报告
  Map<String, PerformanceStats> getAllStats() {
    final labels = _logs.map((l) => l.label).toSet();
    final result = <String, PerformanceStats>{};

    for (final label in labels) {
      final stats = getStats(label);
      if (stats != null) {
        result[label] = stats;
      }
    }

    return result;
  }

  /// 获取完整报告（JSON 格式）
  Map<String, dynamic> getReport() {
    final stats = getAllStats();
    return {
      'generatedAt': DateTime.now().toIso8601String(),
      'totalLogs': _logs.length,
      'stats': stats.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  /// 导出日志到文件（用于用户反馈时附带）
  Future<File> exportLogs() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/performance_logs.json');

    final data = _logs.map((l) => l.toJson()).toList();
    await file.writeAsString(jsonEncode(data));

    return file;
  }

  /// 导出统计报告到文件
  Future<File> exportReport() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/performance_report.json');

    await file.writeAsString(jsonEncode(getReport()));
    return file;
  }

  /// 获取最近的日志
  List<PerformanceLog> getRecentLogs({int count = 50}) {
    if (_logs.length <= count) return List.unmodifiable(_logs);
    return List.unmodifiable(_logs.sublist(_logs.length - count));
  }

  /// 清空日志
  void clear() => _logs.clear();

  /// 获取日志数量
  int get logCount => _logs.length;
}
