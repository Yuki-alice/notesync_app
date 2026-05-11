import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/profile_dashboard_card.dart';
import '../widgets/pro_mode_switch.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/todos_provider.dart';
import '../../../../core/routes/app_routes.dart';

import 'appearance_settings_page.dart';
import 'sync_settings_page.dart';
import 'storage_settings_page.dart';
import 'statistics_page.dart';
import 'about_settings_page.dart';
import 'lan_sync_radar_page.dart';

// 开发工具页面（仅在 Debug 模式下导入）
import '../../../dev_tools/presentation/views/performance_monitor_page.dart' as dev_tools;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _performLogout(BuildContext context) async {
    // 保存 NavigatorState，确保在异步操作后仍能正确导航
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. 断开监听与缓存
      final notesProvider = context.read<NotesProvider>();
      final todosProvider = context.read<TodosProvider>();
      notesProvider.clearTimers();
      notesProvider.clearLocalData();
      todosProvider.clearLocalData();

      // 2. 物理粉碎本地残余数据 (保护前任隐私)
      final isar = Isar.getInstance();
      if (isar != null) {
        await isar.writeTxn(() async {
          await isar.clear();
        });
      }

      // 3. 断开云端，这会触发 AuthProvider 的状态改变
      await Supabase.instance.client.auth.signOut();

      // 4. 关闭 loading 框并返回上一页
      // 使用保存的 navigator，避免 context 失效问题
      navigator.pop(); // 关闭 loading dialog

      // 如果这个设置页是 push 进来的，就 pop 掉它回到主屏
      if (navigator.canPop()) {
        navigator.pop();
      }
    } catch (e) {
      // 出错时也要关闭 loading 框
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      debugPrint('登出失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();

    final titleStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface);
    final subStyle = TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            title: Text('设置', style: GoogleFonts.notoSans(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
            centerTitle: false,
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileDashboardCard(auth: authProvider, theme: theme),
                  const SizedBox(height: 24),

                  const _SectionTitle('创作足迹'),
                  _SettingGroupContainer(
                    children: [
                      _buildNavTile(context, icon: Icons.insights_rounded, title: '创作统计', subtitle: '灵感字数、陪伴天数等深度数据', titleStyle: titleStyle, subStyle: subStyle, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatisticsPage()))),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const _SectionTitle('实验室 (测试中)'),
                  _SettingGroupContainer(
                    children: [
                      _buildNavTile(context, icon: Icons.radar_rounded, title: '局域网雷达', subtitle: 'P2P 同步测试，无需公网环境', titleStyle: titleStyle, subStyle: subStyle, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanSyncRadarPage()))),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const _SectionTitle('应用偏好'),
                  _SettingGroupContainer(
                    children: [
                      _buildNavTile(context, icon: Icons.palette_outlined, title: '外观与主题', subtitle: '深色模式与个性强调色', titleStyle: titleStyle, subStyle: subStyle, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppearanceSettingsPage()))),
                      Divider(height: 1, indent: 56, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15)),
                      const ProModeSwitch(),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const _SectionTitle('云端与存储'),
                  _SettingGroupContainer(
                    children: [
                      _buildNavTile(context, icon: Icons.cloud_sync_outlined, title: '云端同步配置', subtitle: '多引擎同步与同步状态管理', titleStyle: titleStyle, subStyle: subStyle, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncSettingsPage()))),
                      Divider(height: 1, indent: 56, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15)),
                      _buildNavTile(context, icon: Icons.storage_rounded, title: '存储与备份', subtitle: '空间占用分析与本地快照', titleStyle: titleStyle, subStyle: subStyle, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageSettingsPage()))),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const _SectionTitle('整理与安全'),
                  _SettingGroupContainer(
                    children: [
                      _buildNavTile(context, icon: Icons.category_outlined, title: '分类管理', subtitle: '添加、重命名或删除分类', titleStyle: titleStyle, subStyle: subStyle, onTap: () => Navigator.pushNamed(context, AppRoutes.categories)),
                      Divider(height: 1, indent: 56, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15)),
                      _buildNavTile(context, icon: Icons.delete_outline_rounded, title: '回收站', subtitle: '找回误删的笔记与待办', titleStyle: titleStyle, subStyle: subStyle, onTap: () => Navigator.pushNamed(context, AppRoutes.trash)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const _SectionTitle('支持'),
                  _SettingGroupContainer(
                    children: [
                      _buildNavTile(context, icon: Icons.info_outline_rounded, title: '关于与帮助', subtitle: '版本更新日志、GitHub 及文档', titleStyle: titleStyle, subStyle: subStyle, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutSettingsPage()))),
                    ],
                  ),

                  // 开发工具入口（仅在 Debug 模式下显示）
                  if (kDebugMode) ...[
                    const SizedBox(height: 24),
                    const _SectionTitle('开发者工具'),
                    _SettingGroupContainer(
                      children: [
                        _buildNavTile(
                          context,
                          icon: Icons.speed_rounded,
                          title: '性能监控',
                          subtitle: '实时性能数据与图表分析',
                          titleStyle: titleStyle,
                          subStyle: subStyle,
                          iconColor: Colors.deepPurple,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const dev_tools.PerformanceMonitorPage()),
                          ),
                        ),
                      ],
                    ),
                  ],

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile(BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required TextStyle titleStyle,
    required TextStyle subStyle,
    Color? iconColor,
    required VoidCallback onTap
  }) {
    final theme = Theme.of(context);
    final iColor = iconColor ?? theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: titleStyle),
                  const SizedBox(height: 2),
                  Text(subtitle, style: subStyle),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: theme.colorScheme.outlineVariant),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(left: 16, bottom: 12), child: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.outline, fontWeight: FontWeight.w700, fontSize: 13)));
}

class _SettingGroupContainer extends StatelessWidget {
  final List<Widget> children;

  const _SettingGroupContainer({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Material(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );
  }
}