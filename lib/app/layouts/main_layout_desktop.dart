import 'package:flutter/material.dart';

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

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            backgroundColor: theme.colorScheme.surface,
            indicatorColor: theme.colorScheme.secondaryContainer,
            minWidth: 72,
            labelType: NavigationRailLabelType.all,
            // 🟢 稍微向上调整对齐比例，填补移除 Logo 后的空白
            groupAlignment: -0.85,

            // 1️⃣ 头部：优化后的新建按钮
            leading: Column(
              children: [
                const SizedBox(height: 24), // 顶部留出舒适的呼吸空间
                if (onFabPressed != null)
                  FloatingActionButton(
                    elevation: 0,
                    hoverElevation: 3, // 🟢 鼠标悬浮时微微抬起，增强桌面端交互感
                    onPressed: onFabPressed,
                    tooltip: '新建',
                    // 🟢 改用 primaryContainer，色彩更柔和，符合现代桌面端设计语言
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16), // 🟢 更加现代的平滑圆角
                    ),
                    // 🟢 使用更圆润饱满的加号图标
                    child: const Icon(Icons.add_rounded, size: 28),
                  ),
                const SizedBox(height: 16),
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