import 'dart:ui';
import 'package:flutter/material.dart';
import 'widgets/desktop_sidebar.dart';

class MainLayoutDesktop extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final VoidCallback? onFabPressed;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onTrashTap;

  const MainLayoutDesktop({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.onFabPressed,
    this.onSettingsTap,
    this.onTrashTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = Color.alphaBlend(
      theme.colorScheme.primary.withValues(alpha: 0.04),
      theme.colorScheme.surface,
    );

    return Scaffold(
      backgroundColor: surfaceColor,
      // 🌟 直接横向排列侧边栏和主页面，干掉被提取走的顶部栏
      body: Row(
        children: [
          // 左侧：高级磨砂玻璃侧边栏积木
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: 64,
                color: surfaceColor.withValues(alpha: 0.8),
                child: DesktopSidebar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  onFabPressed: onFabPressed,
                  onSettingsTap: onSettingsTap,
                  onTrashTap: onTrashTap,
                ),
              ),
            ),
          ),

          // 右侧：业务主体悬浮卡片积木
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(8, 8, 16, 16), // 上方补了一点间距更美观
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3), width: 1),
                boxShadow: [
                  BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.04), blurRadius: 24, offset: const Offset(0, 4)),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}