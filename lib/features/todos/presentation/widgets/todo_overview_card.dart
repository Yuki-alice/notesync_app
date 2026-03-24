import 'package:flutter/material.dart';

class TodoOverviewCard extends StatelessWidget {
  final double progress;
  final int completedCount;
  final int totalCount;
  final bool isDesktop;

  const TodoOverviewCard({
    super.key,
    required this.progress,
    required this.completedCount,
    required this.totalCount,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAllDone = progress == 1.0 && totalCount > 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isDesktop
            ? null
            : LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        color: isDesktop ? theme.colorScheme.surface : null,
        borderRadius: BorderRadius.circular(24),
        border: isDesktop
            ? Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4))
            : null,
        boxShadow: isDesktop
            ? []
            : [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // 🟢 关键修复：使用 spaceBetween 代替 Spacer()，解决 IntrinsicHeight 报错
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 上半部分：文字和圆环
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧文字 (包裹 Expanded 防止溢出)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAllDone ? '太棒了！🎉' : '今日概览',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '已完成 $completedCount / $totalCount 项任务',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // 右侧圆环
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      value: totalCount == 0 ? 0 : progress,
                      strokeWidth: 5,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      color: theme.colorScheme.primary,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Text(
                    '${((totalCount == 0 ? 0 : progress) * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 下半部分：桌面端装饰
          if (isDesktop) ...[
            const SizedBox(height: 16), // 手动添加间距
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tips_and_updates_outlined, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      isAllDone ? "休息一下吧！" : "保持专注，继续加油",
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalCount == 0 ? 0 : progress,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
          ]
        ],
      ),
    );
  }
}