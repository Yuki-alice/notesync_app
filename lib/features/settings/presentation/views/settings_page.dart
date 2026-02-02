import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/theme_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          // 外观设置
          _buildSectionHeader(theme, '外观'),
          SwitchListTile(
            title: const Text('深色模式'),
            subtitle: const Text('减轻眼部疲劳，适合夜间使用'),
            secondary: Icon(
              themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: theme.colorScheme.primary,
            ),
            value: themeProvider.isDarkMode,
            onChanged: (value) => themeProvider.toggleTheme(),
          ),

          const Divider(),

          // 关于
          _buildSectionHeader(theme, '关于'),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('版本'),
            subtitle: const Text('1.0.0+1'),
          ),
          ListTile(
            leading: const Icon(Icons.code_rounded),
            title: const Text('开发者'),
            subtitle: const Text('Yuki Alice'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}