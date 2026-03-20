import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

// 🟢 引入刚刚拆分出来的积木
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

    // 生成极浅的不透明底色
    final surfaceColor = Color.alphaBlend(
      theme.colorScheme.primary.withOpacity(0.04),
      theme.colorScheme.surface,
    );

    return Scaffold(
      backgroundColor: surfaceColor,
      body: Column(
        children: [
          // ==========================================
          // 1️⃣ 顶部无边框沉浸式拖拽栏
          // ==========================================
          SizedBox(
            height: 38,
            child: Row(
              children: [
                Expanded(
                  child: DragToMoveArea(
                    child: Container(
                      color: Colors.transparent,
                      padding: const EdgeInsets.only(left: 16),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'NoteSync',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!Platform.isMacOS)
                  SizedBox(
                    width: 138,
                    child: WindowCaption(
                      brightness: theme.brightness,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
              ],
            ),
          ),

          // ==========================================
          // 2️⃣ 下方主工作区拼装
          // ==========================================
          Expanded(
            child: Row(
              children: [
                // 🟢 左侧：高级磨砂玻璃侧边栏积木
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      width: 64,
                      color: surfaceColor.withOpacity(0.8),
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

                // 🟢 右侧：业务主体悬浮卡片积木
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(8, 0, 16, 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3), width: 1),
                      boxShadow: [
                        BoxShadow(color: theme.colorScheme.shadow.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 4)),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}