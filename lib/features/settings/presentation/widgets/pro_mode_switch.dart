// 文件路径: lib/features/settings/presentation/widgets/pro_mode_switch.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/providers/auth_provider.dart';

class ProModeSwitch extends StatelessWidget {
  const ProModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.read<AuthProvider>();
    final theme = Theme.of(context);

    // 🌟 完全复用 settings_page 中 _buildNavTile 的精调字体样式
    final titleStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface);
    final subStyle = TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant);

    return InkWell(
      onTap: () {
        // 点击整行也能切换开关
        themeProvider.setProMode(!themeProvider.isProMode, authProvider: authProvider);
      },
      child: Padding(
        // 🌟 完全复用 _buildNavTile 的 Padding
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 🌟 核心修复：图标背景改为与其他选项一模一样的圆角矩形
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)
              ),
              child: Icon(Icons.code_rounded, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 16),

            // 🌟 中间文字区域对齐
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('专业编辑模式', style: titleStyle),
                  const SizedBox(height: 2),
                  Text('启用 Markdown 快捷语法 (如输入 # 加空格)', style: subStyle),
                ],
              ),
            ),

            // 🌟 右侧原生开关
            Switch(
              value: themeProvider.isProMode,
              onChanged: (val) {
                themeProvider.setProMode(val, authProvider: authProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}