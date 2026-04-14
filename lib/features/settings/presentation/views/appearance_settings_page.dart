import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../widgets/theme_mode_toggle.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('外观与主题', style: GoogleFonts.notoSans(fontWeight: FontWeight.w600, fontSize: 17)),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // 🌟 1. 深色模式 (复用你现有的 ElegantThemeModeToggle)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text('深色模式', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: ElegantThemeModeToggle(
              currentMode: themeProvider.themeMode,
              onChanged: (mode){
                final auth = context.read<AuthProvider>();
                themeProvider.setThemeMode(mode, authProvider: auth);
              },
            ),
          ),
          const SizedBox(height: 32),

          // 🌟 2. 主题色骨架选择器 (参考漫画 App)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text('个性化主题与强调色', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          SizedBox(
            height: 180, // 给足够的高度展示卡片
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: ThemeProvider.presetThemes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final style = ThemeProvider.presetThemes[index];
                final isSelected = themeProvider.currentThemeId == style.id;

                return GestureDetector(
                  onTap: () {
                    final auth = context.read<AuthProvider>();
                    themeProvider.setThemeStyle(style.id, authProvider: auth);
                  },
                  child: Column(
                    children: [
                      // 📱 手机骨架卡片
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 90,
                        height: 140,
                        decoration: BoxDecoration(
                          color: isSelected ? style.seedColor.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? style.seedColor : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected ? [BoxShadow(color: style.seedColor.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 8))] : [BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Stack(
                          children: [
                            // 骨架 UI 元素
                            Positioned(top: 16, left: 12, right: 12, child: Container(height: 12, decoration: BoxDecoration(color: style.seedColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)))),
                            Positioned(top: 36, left: 12, right: 40, child: Container(height: 8, decoration: BoxDecoration(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)))),
                            Positioned(top: 50, left: 12, right: 12, child: Container(height: 40, decoration: BoxDecoration(color: style.seedColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)))),
                            // 悬浮 FAB 骨架
                            Positioned(bottom: 12, right: 12, child: Container(width: 24, height: 24, decoration: BoxDecoration(color: style.seedColor, shape: BoxShape.circle))),
                            // 选中状态打勾
                            if (isSelected) Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: style.seedColor, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, size: 12, color: Colors.white))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 主题名称
                      Text(style.name, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? style.seedColor : theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}