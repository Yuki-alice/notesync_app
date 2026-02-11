import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/todos_provider.dart';
// 🟢 引入新页面
import '../../../../core/routes/app_routes.dart';
import 'category_management_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // 🟢 1. 优化后的 SliverAppBar
          SliverAppBar.large(
            title: const Text('设置', style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: false,
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(backgroundColor: theme.colorScheme.surface.withOpacity(0.5)),
            ),
            // 🟢 新增 flexibleSpace 用于装饰背景
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // 背景渐变，使用当前主题的主色和次色混合
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primaryContainer.withOpacity(0.4),
                          theme.colorScheme.surfaceContainerLowest,
                        ],
                      ),
                    ),
                  ),
                  // 右下角巨大的半透明装饰图标
                  Positioned(
                    right: -40,
                    bottom: -20,
                    child: Icon(
                      Icons.settings_suggest_rounded,
                      size: 180,
                      color: theme.colorScheme.primary.withOpacity(0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            // 🟢 为了配合头部，内容区域顶部增加一点额外间距
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 外观 ---
                  _buildSectionTitle(context, '外观'),
                  const SizedBox(height: 8),

                  _buildSettingCard(
                    context,
                    child: SwitchListTile(
                      value: provider.isDarkMode,
                      onChanged: (val) => provider.toggleTheme(),
                      title: const Text('深色模式', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('减轻眼部疲劳'),
                      secondary: Icon(
                        provider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('主题颜色', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 50,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: ThemeProvider.presetColors.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final color = ThemeProvider.presetColors[index];
                              final isSelected = provider.themeColor.value == color.value;

                              return GestureDetector(
                                onTap: () => provider.setThemeColor(color),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(color: theme.colorScheme.onSurface, width: 3)
                                        : null,
                                    boxShadow: isSelected
                                        ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, spreadRadius: 2)]
                                        : null,
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check, color: Colors.white, size: 28)
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- 🟢 新增：笔记管理 ---
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, '笔记'),
                  const SizedBox(height: 8),

                  _buildSettingCard(
                    context,
                    child: ListTile(
                      title: const Text('分类管理'),
                      subtitle: const Text('添加、重命名或删除分类'),
                      leading: Icon(Icons.category_rounded, color: theme.colorScheme.secondary),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.categories);
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),

                  // --- 数据 ---
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, '数据'),
                  const SizedBox(height: 8),

                  _buildSettingCard(
                    context,
                    child: ListTile(
                      title: const Text('清空回收站'),
                      leading: Icon(Icons.delete_sweep_rounded, color: theme.colorScheme.error),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _confirmClearAllTrash(context),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),

                  // --- 关于 ---
                  const SizedBox(height: 32),
                  _buildSectionTitle(context, '关于'),
                  const SizedBox(height: 8),

                  _buildSettingCard(
                    context,
                    child: Column(
                      children: [
                        ListTile(
                          title: const Text('版本'),
                          subtitle: const Text('1.0.0 (Beta)'),
                          leading: Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
                        ),
                        Divider(height: 1, indent: 56, color: theme.colorScheme.outlineVariant.withOpacity(0.2)),
                        ListTile(
                          title: const Text('开发者'),
                          subtitle: const Text('Flutter Enthusiast'),
                          leading: Icon(Icons.code_rounded, color: theme.colorScheme.secondary),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      'Made with ❤️ by Flutter',
                      style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
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

  Widget _buildSettingCard(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: child,
    );
  }

  void _confirmClearAllTrash(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        title: const Text('清空所有回收站?'),
        content: const Text('笔记和待办事项的回收站都将被清空，此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<NotesProvider>(context, listen: false).emptyTrash();
              Provider.of<TodosProvider>(context, listen: false).emptyTrash();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('所有回收站已清空'),
                  behavior: SnackBarBehavior.floating,
                  width: 200,
                  backgroundColor: theme.colorScheme.inverseSurface,
                  shape: const StadiumBorder(),
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
            child: const Text('全部清空'),
          ),
        ],
      ),
    );
  }
}