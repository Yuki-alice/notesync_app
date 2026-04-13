import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/todos_provider.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../widgets/common/dialogs/app_sheet.dart';
import '../../../../widgets/common/dialogs/app_dialog.dart';
import '../../../../utils/toast_utils.dart';
import '../viewmodels/profile_viewmodel.dart';
import 'edit_profile_sheet.dart';

class ProfileDashboardCard extends StatefulWidget {
  final AuthProvider auth;
  final ThemeData theme;

  const ProfileDashboardCard({super.key, required this.auth, required this.theme});

  @override
  State<ProfileDashboardCard> createState() => _ProfileDashboardCardState();
}

class _ProfileDashboardCardState extends State<ProfileDashboardCard> {
  // 🌟 登出逻辑已完美集成至名片组件内部
  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await AppDialog.showConfirm(
        context: context,
        title: '退出登录',
        content: '退出登录将彻底清除此设备上的所有本地缓存（包括私密图片与分类）。\n您的数据已安全保存在云端，下次登录即可恢复。',
        icon: Icons.logout_rounded,
        confirmText: '确认退出',
        isDestructive: true
    );

    if (confirm == true && context.mounted) {
      ToastUtils.showInfo(context, '正在彻底销毁本地数据...');

      context.read<NotesProvider>().clearLocalData();
      context.read<TodosProvider>().clearLocalData();

      try {
        final isar = Isar.getInstance()!;
        await isar.writeTxn(() async => await isar.clear());
        final appDir = await getApplicationDocumentsDirectory();
        final imgDir = Directory('${appDir.path}/note_images');
        if (await imgDir.exists()) await imgDir.delete(recursive: true);
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key != 'isProMode' && key != 'themeMode' && key != 'themeStyle' && !key.startsWith('webdav_') && key != 'isAutoSyncEnabled') {
          await prefs.remove(key);
        }
      }

      await widget.auth.signOut();

      if (context.mounted) {
        ToastUtils.showSuccess(context, '数据已彻底擦除，安全退出');
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.settings, (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.auth.isAuthenticated) return _buildUnauthState(context);

    final theme = widget.theme;
    final auth = widget.auth;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                // 头像
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primaryContainer),
                  clipBehavior: Clip.hardEdge,
                  child: Builder(
                    builder: (context) {
                      if (auth.localAvatarPath != null && File(auth.localAvatarPath!).existsSync()) return Image.file(File(auth.localAvatarPath!), fit: BoxFit.cover);
                      else if (auth.avatarUrl != null) return Image.network(auth.avatarUrl!, fit: BoxFit.cover);
                      else return Center(child: Text(auth.displayName.isNotEmpty ? auth.displayName[0].toUpperCase() : 'N', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)));
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // 昵称与签名
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(auth.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(auth.bio ?? '记录生活，同步灵感', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                // 🌟 编辑按钮
                IconButton(
                  onPressed: () => AppSheet.show(context: context, builder: (ctx) => ChangeNotifierProvider(create: (_) => ProfileViewModel(auth), child: const EditProfileSheet())),
                  icon: Icon(Icons.edit_rounded, size: 18, color: theme.colorScheme.primary),
                  style: IconButton.styleFrom(backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1)),
                ),
                const SizedBox(width: 8),
                // 🌟 退出登录按钮 (与编辑平级，极度整洁)
                IconButton(
                  onPressed: () => _handleLogout(context),
                  icon: Icon(Icons.logout_rounded, size: 18, color: theme.colorScheme.error),
                  style: IconButton.styleFrom(backgroundColor: theme.colorScheme.errorContainer.withValues(alpha: 0.5)),
                  tooltip: '退出登录',
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 🌟 真实的同步状态看板
            _buildSyncStatusBox(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusBox(BuildContext context, ThemeData theme) {
    final notesProvider = context.watch<NotesProvider>();
    final todosProvider = context.watch<TodosProvider>();

    return FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox(height: 60);

          final prefs = snapshot.data!;
          final isSyncEnabled = prefs.getBool('isAutoSyncEnabled') ?? false;
          final syncMode = prefs.getString('sync_mode') ?? 'supabase';
          final engineName = syncMode == 'supabase' ? '官方云 (Supabase)' : '私有云 (WebDAV)';

          final notesCount = notesProvider.filteredNotes.length;
          final todosCount = todosProvider.todos.length;
          final syncState = notesProvider.syncState;

          Color statusColor;
          String statusText;
          IconData statusIcon;

          // 🌟 状态智能判断逻辑
          if (!isSyncEnabled) {
            statusColor = theme.colorScheme.outline;
            statusText = '已暂停';
            statusIcon = Icons.cloud_off_rounded;
          } else if (syncState == SyncState.syncing) {
            statusColor = theme.colorScheme.primary;
            statusText = '正在同步';
            statusIcon = Icons.sync_rounded;
          } else if (syncState == SyncState.error) {
            statusColor = theme.colorScheme.error;
            statusText = '连接异常';
            statusIcon = Icons.error_outline_rounded;
          } else {
            statusColor = Colors.green;
            statusText = '已就绪';
            statusIcon = Icons.cloud_done_rounded;
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                // 图标
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 16),
                // 数据统计
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isSyncEnabled ? engineName : '同步功能已关闭', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(isSyncEnabled ? '已关联 $notesCount 篇笔记与 $todosCount 个待办' : '数据目前仅保存在本地设备', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
                // 状态 Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          );
        }
    );
  }

  Widget _buildUnauthState(BuildContext context) {
    final theme=widget.theme;
    return Container(
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(28), border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2))),
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Container(width: 64, height: 64, decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5), shape: BoxShape.circle), child: Icon(Icons.person_outline_rounded, size: 32, color: theme.colorScheme.outline)),
          const SizedBox(height: 20),
          const Text('尚未开启云端同步', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('登录账号，跨设备随时随地访问灵感', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.login), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text('去登录 / 注册', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))),
        ],
      ),
    );
  }
}