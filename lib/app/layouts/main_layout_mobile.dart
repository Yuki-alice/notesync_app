import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    final themeProvider = context.watch<ThemeProvider>();
    final currentStyle = themeProvider.currentStyle;

    return Scaffold(
      extendBody: true,
      backgroundColor: theme.colorScheme.surface,

      // 🌟 极致精简：直接将主体扔进来，彻底与外层窗口解耦
      body: body,

      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
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
              backgroundColor: Colors.transparent,
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