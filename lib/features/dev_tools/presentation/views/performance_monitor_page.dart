import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/performance/perf.dart';
import '../../../../core/services/performance/performance_monitor.dart';
import '../../../../core/services/performance/performance_report_exporter.dart';
import '../../../../core/services/performance/fps_monitor.dart';

/// 开发者性能监控页面
///
/// 仅在 Debug 模式下可用，用于展示实时性能数据和图表。
/// 发布版本不会包含此页面（通过 kDebugMode 条件编译控制入口）。
class PerformanceMonitorPage extends StatefulWidget {
  const PerformanceMonitorPage({super.key});

  @override
  State<PerformanceMonitorPage> createState() => _PerformanceMonitorPageState();
}

class _PerformanceMonitorPageState extends State<PerformanceMonitorPage> {
  late Timer _refreshTimer;
  Map<String, PerformanceStats> _stats = {};
  List<PerformanceLog> _recentLogs = [];
  Map<String, dynamic> _summary = {};
  final FpsMonitor _fpsMonitor = FpsMonitor();
  FpsSessionResult? _sessionResult;

  @override
  void initState() {
    super.initState();
    _refreshData();
    // 每 2 秒自动刷新
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) _refreshData();
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    _fpsMonitor.stop();
    super.dispose();
  }

  void _refreshData() {
    setState(() {
      _stats = Perf.monitor.getAllStats();
      _recentLogs = Perf.monitor.getRecentLogs(count: 50);
      _summary = PerformanceReportExporter().getPerformanceSummary();
    });
  }

  void _toggleFpsRecording() {
    if (_fpsMonitor.isRecording) {
      _fpsMonitor.stopRecording();
      setState(() {
        _sessionResult = _fpsMonitor.getSessionResult();
      });
    } else {
      _fpsMonitor.startRecording();
      setState(() {
        _sessionResult = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            title: Text(
              '性能监控',
              style: GoogleFonts.notoSans(fontWeight: FontWeight.w600),
            ),
            centerTitle: false,
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _refreshData,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('清空日志'),
                      content: const Text('确定要清空所有性能监控数据吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () {
                            Perf.clear();
                            _refreshData();
                            Navigator.pop(ctx);
                          },
                          child: const Text('确定'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // FPS 监控卡片
                  _buildFpsCard(theme),
                  const SizedBox(height: 24),

                  // 概览卡片
                  _buildSummaryCard(theme),
                  const SizedBox(height: 24),

                  // 统计图表
                  if (_stats.isNotEmpty) ...[
                    _buildSectionTitle('性能统计', theme),
                    const SizedBox(height: 12),
                    _buildStatsChart(theme),
                    const SizedBox(height: 24),
                  ],

                  // 最近日志
                  if (_recentLogs.isNotEmpty) ...[
                    _buildSectionTitle('最近操作', theme),
                    const SizedBox(height: 12),
                    _buildRecentLogsList(theme),
                    const SizedBox(height: 24),
                  ],

                  // 导出按钮
                  _buildExportButtons(theme),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFpsCard(ThemeData theme) {
    final isRecording = _fpsMonitor.isRecording;
    final fpsStats = _fpsMonitor.getStats();
    final fpsHistory = _fpsMonitor.getFpsHistory(count: 60);
    final sessionResult = _sessionResult;

    final FpsData displayStats = sessionResult ?? fpsStats;
    final displayHistory = sessionResult?.fpsHistory ?? fpsHistory;

    final currentFps = sessionResult != null
        ? sessionResult.averageFps
        : fpsStats.currentFps;
    final isFpsGood = currentFps >= 55;
    final isFpsWarning = currentFps >= 30 && currentFps < 55;

    Color fpsColor;
    if (isFpsGood) {
      fpsColor = Colors.green.shade600;
    } else if (isFpsWarning) {
      fpsColor = Colors.orange.shade600;
    } else {
      fpsColor = Colors.red.shade600;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isFpsGood
              ? [Colors.green.shade50, Colors.teal.shade50]
              : isFpsWarning
                  ? [Colors.orange.shade50, Colors.yellow.shade50]
                  : [Colors.red.shade50, Colors.pink.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFpsGood
              ? Colors.green.shade200
              : isFpsWarning
                  ? Colors.orange.shade200
                  : Colors.red.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRecording ? Icons.fiber_manual_record : Icons.speed_rounded,
                color: isRecording ? Colors.red.shade600 : fpsColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isRecording ? '正在录制帧率...' : '帧率监控',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (isRecording)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '录制中',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else if (sessionResult != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: fpsColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${currentFps.toStringAsFixed(1)} FPS',
                    style: TextStyle(
                      color: fpsColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '未录制',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (displayHistory.isNotEmpty)
            SizedBox(
              height: 60,
              child: CustomPaint(
                size: const Size(double.infinity, 60),
                painter: _FpsChartPainter(displayHistory),
              ),
            )
          else
            SizedBox(
              height: 60,
              child: Center(
                child: Text(
                  isRecording ? '正在采集帧率数据...' : '点击开始录制以采集帧率数据',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildFpsItem('平均', displayStats.averageFps.toStringAsFixed(1), theme),
              _buildFpsItem('最小', displayStats.minFps.toStringAsFixed(1), theme),
              _buildFpsItem('最大', displayStats.maxFps.toStringAsFixed(1), theme),
              _buildFpsItem('掉帧', '${displayStats.droppedFrames}', theme),
              _buildFpsItem('掉帧率', '${(displayStats.dropRate * 100).toStringAsFixed(1)}%', theme),
            ],
          ),
          const SizedBox(height: 16),
          // 录制控制按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _toggleFpsRecording,
              icon: Icon(isRecording ? Icons.stop_rounded : Icons.videocam_rounded),
              label: Text(isRecording ? '停止录制' : '开始录制'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isRecording ? Colors.red.shade600 : theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (sessionResult != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '录制结果',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '时长: ${sessionResult.duration.inSeconds}.${(sessionResult.duration.inMilliseconds % 1000).toString().padLeft(3, '0')}s | '
                    '总帧数: ${sessionResult.totalFrames} | '
                    '平均: ${sessionResult.averageFps.toStringAsFixed(1)} FPS',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFpsItem(String label, String value, ThemeData theme) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    final status = _summary['status']?.toString() ?? '暂无数据';
    final totalOps = _summary['totalOperations'] ?? 0;
    final avgMs = _summary['averageDurationMs']?.toString() ?? '0';
    final maxMs = _summary['maxDurationMs'] ?? 0;
    final opCount = _summary['operationCount'] ?? 0;

    final isHealthy = status == '性能良好';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHealthy
              ? [Colors.green.shade50, Colors.teal.shade50]
              : [Colors.orange.shade50, Colors.red.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHealthy ? Colors.green.shade200 : Colors.orange.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isHealthy ? Colors.green.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: isHealthy ? Colors.green.shade800 : Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$opCount 个操作类型',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildSummaryItem('总操作数', totalOps.toString(), theme),
              _buildSummaryItem('平均耗时', '${avgMs}ms', theme),
              _buildSummaryItem('最大耗时', '${maxMs}ms', theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, ThemeData theme) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsChart(ThemeData theme) {
    // 按平均耗时排序
    final sortedEntries = _stats.entries.toList()
      ..sort((a, b) => b.value.avgMs.compareTo(a.value.avgMs));

    // 取前 10 个
    final displayEntries = sortedEntries.take(10).toList();
    final maxAvg = displayEntries.isNotEmpty
        ? displayEntries.map((e) => e.value.avgMs).reduce(max)
        : 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '平均耗时 Top ${displayEntries.length}',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...displayEntries.map((entry) {
            final label = entry.key;
            final stats = entry.value;
            final barWidth = maxAvg > 0 ? (stats.avgMs / maxAvg) : 0.0;
            final isSlow = stats.avgMs > 1000;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${stats.avgMs.toStringAsFixed(1)}ms',
                        style: TextStyle(
                          color: isSlow ? Colors.red.shade600 : theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: isSlow ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: barWidth.toDouble(),
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        isSlow ? Colors.red.shade400 : theme.colorScheme.primary,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '次数: ${stats.count} | 最大: ${stats.maxMs}ms | 最小: ${stats.minMs}ms | 总计: ${stats.totalMs}ms',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentLogsList(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '最近 ${_recentLogs.length} 条记录',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ..._recentLogs.reversed.take(20).map((log) {
            final isSlow = log.durationMs > 1000;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isSlow ? Colors.red.shade400 : Colors.green.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.label,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (log.metadata != null)
                          Text(
                            log.metadata.toString(),
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${log.durationMs}ms',
                    style: TextStyle(
                      color: isSlow ? Colors.red.shade600 : theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: isSlow ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildExportButtons(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('导出报告', theme),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildExportButton(
              theme,
              icon: Icons.code_rounded,
              label: 'JSON 报告',
              onTap: () async {
                final file = await PerformanceReportExporter().exportJsonReport();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('JSON 报告已导出: ${file.path}')),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExportButton(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.outline,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// FPS 图表绘制器
class _FpsChartPainter extends CustomPainter {
  final List<double> fpsHistory;

  _FpsChartPainter(this.fpsHistory);

  @override
  void paint(Canvas canvas, Size size) {
    if (fpsHistory.isEmpty) return;

    final paint = Paint()
      ..color = Colors.green.shade400
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.green.shade100.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final maxFps = 60.0;
    final minFps = 0.0;
    final range = maxFps - minFps;

    final stepX = size.width / (fpsHistory.length - 1);

    for (int i = 0; i < fpsHistory.length; i++) {
      final x = i * stepX;
      final normalizedY = (fpsHistory[i].clamp(minFps, maxFps) - minFps) / range;
      final y = size.height - (normalizedY * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // 绘制 30fps 和 60fps 参考线
    final refPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // 60fps 线（顶部）
    canvas.drawLine(
      Offset(0, 0),
      Offset(size.width, 0),
      refPaint,
    );

    // 30fps 线（中间）
    final y30 = size.height * 0.5;
    canvas.drawLine(
      Offset(0, y30),
      Offset(size.width, y30),
      refPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
