import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'performance_monitor.dart';

/// 性能报告导出器
///
/// 支持导出为 JSON 报告。
class PerformanceReportExporter {
  static final PerformanceReportExporter _instance = PerformanceReportExporter._internal();
  factory PerformanceReportExporter() => _instance;
  PerformanceReportExporter._internal();

  final CustomPerformanceMonitor _monitor = CustomPerformanceMonitor();

  /// 生成并导出 JSON 报告到文件
  Future<File> exportJsonReport() async {
    return await _monitor.exportReport();
  }

  /// 生成并导出日志到文件
  Future<File> exportLogs() async {
    return await _monitor.exportLogs();
  }

  /// 获取最近的慢操作（超过阈值的记录）
  List<Map<String, dynamic>> getRecentSlowOperations({int thresholdMs = 1000, int limit = 20}) {
    final logs = _monitor.getRecentLogs(count: _monitor.logCount);
    final slowLogs = logs
        .where((log) => log.durationMs > thresholdMs)
        .take(limit)
        .map((log) => log.toJson())
        .toList();
    return slowLogs;
  }

  /// 获取性能摘要（用于 UI 展示）
  Map<String, dynamic> getPerformanceSummary() {
    final report = _monitor.getReport();
    final stats = report['stats'] as Map<String, dynamic>? ?? {};

    if (stats.isEmpty) {
      return {'status': '暂无数据', 'totalOperations': 0};
    }

    int totalOps = 0;
    int totalMs = 0;
    int maxMs = 0;

    for (final data in stats.values) {
      final map = data as Map<String, dynamic>;
      totalOps += (map['count'] as int? ?? 0);
      totalMs += (map['totalMs'] as int? ?? 0);
      final currentMax = map['maxMs'] as int? ?? 0;
      if (currentMax > maxMs) maxMs = currentMax;
    }

    final avgMs = totalOps > 0 ? totalMs / totalOps : 0;

    return {
      'status': maxMs > 1000 ? '存在慢操作' : '性能良好',
      'totalOperations': totalOps,
      'totalDurationMs': totalMs,
      'averageDurationMs': avgMs.toStringAsFixed(2),
      'maxDurationMs': maxMs,
      'operationCount': stats.length,
    };
  }
}
