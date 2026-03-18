import 'dart:ui';
import 'package:flutter/material.dart';

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

    return Scaffold(
      extendBody: true, // 保持开启，让列表能滑到底部
      backgroundColor: theme.colorScheme.surface,
      body: body,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25), // 🟢 增加模糊强度
          child: Container(
            decoration: BoxDecoration(
              // 🟢 核心：异色底底漆。浅色模式铺一层微透的纯白，深色铺黑，这样既有玻璃感，又不会跟背景混成一团。
              color: isDark
                  ? Colors.black.withOpacity(0.65)
                  : Colors.white.withOpacity(0.75),
              // 🟢 灵魂：顶部 0.5px 的极细分割线，完美复刻 iOS 质感
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
            ),
            child: NavigationBar(
              backgroundColor: Colors.transparent, // 让底层毛玻璃透出来
              elevation: 0,
              indicatorColor: theme.colorScheme.primaryContainer.withOpacity(0.6),
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.description_outlined),
                    selectedIcon: Icon(Icons.description_rounded),
                    label: '笔记'
                ),
                NavigationDestination(
                    icon: Icon(Icons.check_circle_outlined),
                    selectedIcon: Icon(Icons.check_circle_rounded),
                    label: '待办'
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}