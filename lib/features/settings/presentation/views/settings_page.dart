import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/providers/theme_provider.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/todos_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../utils/toast_utils.dart';
import '../../../../widgets/common/dialogs/app_dialog.dart';
import '../widgets/profile_dashboard_card.dart';
import '../widgets/theme_mode_toggle.dart';
import '../widgets/pro_mode_switch.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            title: Text(
              '设置',
              style: GoogleFonts.notoSans(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            centerTitle: false,
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: theme.colorScheme.onSurface,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 个人资料区
                  ProfileDashboardCard(auth: authProvider, theme: theme),
                  const SizedBox(height: 32),

                  // 2. 外观设置
                  _buildSectionTitle(context, '外观'),
                  _buildSettingGroup(
                    context,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildUniformIcon(
                                  context,
                                  Icons.brightness_6_rounded,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '深色模式',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ElegantThemeModeToggle(
                              currentMode: themeProvider.themeMode,
                              onChanged:
                                  (mode) => themeProvider.setThemeMode(mode),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSettingGroup(
                    context,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildUniformIcon(
                                  context,
                                  Icons.palette_rounded,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '个性化主题',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 100,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: ThemeProvider.presetThemes.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final style =
                                      ThemeProvider.presetThemes[index];
                                  final isSelected =
                                      themeProvider.currentThemeId == style.id;
                                  BoxDecoration decoration =
                                      (style.vibe == ThemeVibe.gradient)
                                          ? BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                style.seedColor.withValues(alpha:
                                                  0.6,
                                                ),
                                                style.seedColor.withValues(alpha:
                                                  0.2,
                                                ),
                                              ],
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow:
                                                isSelected
                                                    ? [
                                                      BoxShadow(
                                                        color: style.seedColor
                                                            .withValues(alpha: 0.4),
                                                        blurRadius: 10,
                                                        offset: const Offset(
                                                          0,
                                                          4,
                                                        ),
                                                      ),
                                                    ]
                                                    : null,
                                          )
                                          : BoxDecoration(
                                            color: style.seedColor,
                                            shape: BoxShape.circle,
                                            boxShadow:
                                                isSelected
                                                    ? [
                                                      BoxShadow(
                                                        color: style.seedColor
                                                            .withValues(alpha: 0.4),
                                                        blurRadius: 10,
                                                        offset: const Offset(
                                                          0,
                                                          4,
                                                        ),
                                                      ),
                                                    ]
                                                    : null,
                                          );

                                  return GestureDetector(
                                    onTap:
                                        () => themeProvider.setThemeStyle(
                                          style.id,
                                        ),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      width: 76,
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? style.seedColor.withValues(alpha:
                                                  0.05,
                                                )
                                                : theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color:
                                              isSelected
                                                  ? style.seedColor
                                                  : theme
                                                      .colorScheme
                                                      .outlineVariant
                                                      .withValues(alpha: 0.3),
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: decoration,
                                            child:
                                                isSelected
                                                    ? const Icon(
                                                      Icons.check_rounded,
                                                      color: Colors.white,
                                                      size: 20,
                                                    )
                                                    : null,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            style.name,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              height: 1.2,
                                              fontWeight:
                                                  isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                              color:
                                                  isSelected
                                                      ? style.seedColor
                                                      : theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // 3. 笔记管理
                  _buildSectionTitle(context, '笔记'),
                  _buildSettingGroup(
                    context,
                    children: [
                      const ProModeSwitchTile(), // 🟢 引入拆分组件
                      Divider(
                        height: 1,
                        indent: 64,
                        color: theme.colorScheme.outlineVariant.withValues(alpha:
                          0.3,
                        ),
                      ),
                      ListTile(
                        title: Text(
                          '分类管理',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '添加、重命名或删除分类',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        leading: _buildUniformIcon(
                          context,
                          Icons.category_rounded,
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onTap:
                            () => Navigator.pushNamed(
                              context,
                              AppRoutes.categories,
                            ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // 4. 数据管理
                  _buildSectionTitle(context, '数据'),
                  _buildSettingGroup(
                    context,
                    children: [
                      ListTile(
                        title: Text(
                          '回收站',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          '查看或恢复已删除的内容',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        leading: _buildUniformIcon(
                          context,
                          Icons.delete_outline_rounded,
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        onTap:
                            () => Navigator.pushNamed(context, AppRoutes.trash),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // 5. 退出登录
                  if (authProvider.isAuthenticated) ...[
                    _buildSettingGroup(
                      context,
                      children: [
                        ListTile(
                          title: Text(
                            '退出当前账号',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.error,
                            ),
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer
                                  .withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.logout_rounded,
                              color: theme.colorScheme.error,
                            ),
                          ),
                          onTap:
                              () => _showLogoutConfirmDialog(
                                context,
                                authProvider,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],

                  // 底部信仰声明
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'NoteSync',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Version 1.0.0',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUniformIcon(BuildContext context, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: theme.colorScheme.primary, size: 20),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSettingGroup(
    BuildContext context, {
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(children: children),
    );
  }

  void _showLogoutConfirmDialog(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    final confirm = await AppDialog.showConfirm(
      context: context,
      title: '退出登录',
      content: '退出登录将清除此设备上的本地缓存数据。\n您的数据已安全保存在云端，下次登录即可恢复。',
      icon: Icons.logout_rounded,
      confirmText: '确认退出',
      isDestructive: true,
    );
    if (confirm == true) {
      await authProvider.signOut();
      if (context.mounted) {
        context.read<NotesProvider>().clearLocalData();
        context.read<TodosProvider>().clearLocalData();
        ToastUtils.showInfo(context, '已安全退出账号');
      }
    }
  }
}
