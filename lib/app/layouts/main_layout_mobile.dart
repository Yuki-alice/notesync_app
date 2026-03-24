// 文件路径: lib/app/layouts/main_layout_mobile.dart
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/providers/theme_provider.dart';

class MainLayoutMobile extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  const MainLayoutMobile({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktopPlatform = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    final themeProvider = context.watch<ThemeProvider>();
    final currentStyle = themeProvider.currentStyle;

    // 🌟 手机端重构：彻底解决右滑断层 BUG
    // 返回纯正的 Scaffold 结构，背景色直接设为纯色（极其稳定，不会穿帮）
    return Scaffold(
      extendBody: true,
      backgroundColor: theme.colorScheme.surface,

      body: isDesktopPlatform
          ? Column(
        children: [
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Expanded(child: DragToMoveArea(child: Container(color: Colors.transparent))),
                if (!Platform.isMacOS)
                  SizedBox(width: 138, child: WindowCaption(brightness: theme.brightness, backgroundColor: Colors.transparent)),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      )
          : body,

      // 🌟 手机端光影魔法：精准附魔底部导航栏！
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            // 只有渐变主题才在导航栏展示炫光
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.65) : Colors.white.withValues(alpha: 0.75),
              gradient: currentStyle.vibe == ThemeVibe.gradient ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.15),
                  Colors.transparent,
                  theme.colorScheme.secondary.withValues(alpha: 0.1),
                ],
              ) : null,
              border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2), width: 0.5)),
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent, // 必须透明以透出下方的渐变和模糊
              elevation: 0,
              indicatorColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description_rounded), label: '笔记'),
                NavigationDestination(icon: Icon(Icons.check_circle_outlined), selectedIcon: Icon(Icons.check_circle_rounded), label: '待办'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}