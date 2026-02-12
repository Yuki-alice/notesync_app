import 'package:flutter/material.dart';

class MainLayoutDesktop extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final VoidCallback? onFabPressed;
  // 新增回调
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

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            backgroundColor: theme.colorScheme.surface,
            indicatorColor: theme.colorScheme.secondaryContainer,
            // 稍微加宽一点侧边栏，更有质感
            minWidth: 72,
            labelType: NavigationRailLabelType.all,
            groupAlignment: -0.8, // 内容靠上对齐

            // 1️⃣ 头部：Logo 和 新建按钮
            leading: Column(
              children: [
                const SizedBox(height: 12),
                // App Logo
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.edit_note_rounded, color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(height: 20),
                // 全局 FAB
                if (onFabPressed != null)
                  FloatingActionButton(
                    elevation: 0,
                    onPressed: onFabPressed,
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    child: const Icon(Icons.add),
                  ),
                const SizedBox(height: 12),
              ],
            ),

            // 2️⃣ 中部：主导航
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.description_outlined),
                selectedIcon: Icon(Icons.description_rounded),
                label: Text('笔记'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.task_alt_outlined),
                selectedIcon: Icon(Icons.task_alt_rounded),
                label: Text('待办'),
              ),
            ],

            // 3️⃣ 尾部：底部功能入口 (回收站、设置)
            trailing: Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 回收站
                    IconButton(
                      icon: const Icon(Icons.auto_delete_outlined),
                      tooltip: '回收站',
                      onPressed: onTrashTap,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    // 设置
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: '设置',
                      onPressed: onSettingsTap,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    // 用户头像 (装饰性)
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.secondary,
                      child: const Text('Me', style: TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const VerticalDivider(thickness: 1, width: 1),

          Expanded(child: body),
        ],
      ),
    );
  }
}