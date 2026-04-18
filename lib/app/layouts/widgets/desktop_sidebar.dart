import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/privacy_mode_provider.dart';

class DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback? onFabPressed;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onTrashTap;

  const DesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.onFabPressed,
    this.onSettingsTap,
    this.onTrashTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();

    // 构建头像组件
    Widget buildAvatarContent() {
      if (authProvider.localAvatarPath != null && File(authProvider.localAvatarPath!).existsSync()) {
        return Image.file(File(authProvider.localAvatarPath!), fit: BoxFit.cover);
      } else if (authProvider.avatarUrl != null) {
        return Image.network(authProvider.avatarUrl!, fit: BoxFit.cover);
      } else {
        final name = authProvider.displayName;
        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'N';
        return Text(initial, style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontSize: 13, fontWeight: FontWeight.bold));
      }
    }

    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      backgroundColor: Colors.transparent, // 必须透明
      indicatorColor: theme.colorScheme.secondaryContainer,
      minWidth: 64,
      labelType: NavigationRailLabelType.none,
      groupAlignment: -0.9,

      // 1. 顶部：新建按钮
      leading: Column(
        children: [
          const SizedBox(height: 16),
          if (onFabPressed != null)
            Consumer<PrivacyModeProvider>(
              builder: (context, privacyModeProvider, _) {
                final isPrivate = privacyModeProvider.isPrivateMode;
                return Tooltip(
                  message: isPrivate ? '新建私密笔记 (Ctrl+N)' : '新建笔记 (Ctrl+N)',
                  waitDuration: const Duration(milliseconds: 300),
                  child: Material(
                    color: isPrivate
                        ? theme.colorScheme.errorContainer
                        : theme.colorScheme.primaryContainer,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onFabPressed,
                      hoverColor: isPrivate
                          ? theme.colorScheme.error.withValues(alpha: 0.1)
                          : theme.colorScheme.primary.withValues(alpha: 0.1),
                      child: SizedBox(
                        width: 40, height: 40,
                        child: Icon(
                          isPrivate ? Icons.lock : Icons.add_rounded,
                          size: 24,
                          color: isPrivate
                              ? theme.colorScheme.onErrorContainer
                              : theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
        ],
      ),

      // 2. 中部：导航菜单
      destinations: const [
        NavigationRailDestination(
            icon: Tooltip(message: '全部笔记', child: Icon(Icons.description_outlined, size: 24)),
            selectedIcon: Tooltip(message: '全部笔记', child: Icon(Icons.description_rounded, size: 24)),
            label: Text('笔记')
        ),
        NavigationRailDestination(
            icon: Tooltip(message: '待办事项', child: Icon(Icons.task_alt_outlined, size: 24)),
            selectedIcon: Tooltip(message: '待办事项', child: Icon(Icons.task_alt_rounded, size: 24)),
            label: Text('待办')
        ),
      ],

      // 3. 底部：系统操作与用户中枢
      trailing: Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(icon: const Icon(Icons.auto_delete_outlined, size: 22), tooltip: '回收站', onPressed: onTrashTap, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 8),
              IconButton(icon: const Icon(Icons.settings_outlined, size: 22), tooltip: '系统设置', onPressed: onSettingsTap, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 24),

              // 用户弹窗菜单
              PopupMenuButton<String>(
                offset: const Offset(50, -100),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: theme.colorScheme.surfaceContainerHigh,
                elevation: 8,
                tooltip: '账户管理',
                onSelected: (value) async {
                  if (value == 'profile' || value == 'theme') onSettingsTap?.call();
                  if (value == 'logout') await context.read<AuthProvider>().signOut();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'profile', child: Row(children: [Icon(Icons.account_circle_outlined, size: 18, color: theme.colorScheme.onSurface), const SizedBox(width: 12), Expanded(child: Text(authProvider.displayName, overflow: TextOverflow.ellipsis))])),
                  PopupMenuItem(value: 'theme', child: Row(children: [Icon(Icons.dark_mode_outlined, size: 18, color: theme.colorScheme.onSurface), const SizedBox(width: 12), const Text('外观与设置')])),
                  const PopupMenuDivider(),
                  PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout_rounded, size: 18, color: theme.colorScheme.error), const SizedBox(width: 12), Text('退出登录', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold))])),
                ],
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5), width: 1.5), boxShadow: [BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2))]),
                    clipBehavior: Clip.antiAlias,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: buildAvatarContent(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}