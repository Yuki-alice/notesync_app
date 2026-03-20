// 文件路径: lib/core/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeVibe { solid, gradient }

class AppThemeStyle {
  final String id;
  final String name;
  final Color seedColor;
  final ThemeVibe vibe;

  const AppThemeStyle({
    required this.id,
    required this.name,
    required this.seedColor,
    this.vibe = ThemeVibe.solid,
  });
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _currentThemeId = 'classic_blue';
  late SharedPreferences _prefs;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  AppThemeStyle get currentStyle => presetThemes.firstWhere(
          (t) => t.id == _currentThemeId,
      orElse: () => presetThemes.first
  );

  Color get themeColor => currentStyle.seedColor;
  String get currentThemeId => _currentThemeId;

  // 🌟 超级调色盘 3.0：突破 MD3 算法压制的高辨识度色彩
  static const List<AppThemeStyle> presetThemes = [
    AppThemeStyle(id: 'classic_blue', name: '极简原生', seedColor: Color(0xFF5C6BC0), vibe: ThemeVibe.solid),
    AppThemeStyle(id: 'sakura_anime', name: '樱花微醺', seedColor: Color(0xFFF06292), vibe: ThemeVibe.solid),
    AppThemeStyle(id: 'mint_breeze', name: '薄荷微风', seedColor: Color(0xFF009688), vibe: ThemeVibe.gradient), // 加深薄荷绿
    AppThemeStyle(id: 'sunset_glow', name: '落日橘辉', seedColor: Color(0xFFFF5722), vibe: ThemeVibe.gradient),
    AppThemeStyle(id: 'ocean_deep', name: '静谧海蓝', seedColor: Color(0xFF0277BD), vibe: ThemeVibe.gradient),
    AppThemeStyle(id: 'nebula_purple', name: '星云幻紫', seedColor: Color(0xFF9C27B0), vibe: ThemeVibe.gradient),
    AppThemeStyle(id: 'ink_cyan', name: '苍岩青墨', seedColor: Color(0xFF004D40), vibe: ThemeVibe.solid),
    AppThemeStyle(id: 'latte_coffee', name: '拿铁咖啡', seedColor: Color(0xFF795548), vibe: ThemeVibe.solid),
  ];

  ThemeProvider() {
    _loadThemePrefs();
  }

  Future<void> _loadThemePrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final modeIndex = _prefs.getInt('theme_mode_index') ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[modeIndex];
    _currentThemeId = _prefs.getString('theme_style_id') ?? 'classic_blue';
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _prefs.setInt('theme_mode_index', mode.index);
    notifyListeners();
  }

  Future<void> setThemeStyle(String themeId) async {
    if (_currentThemeId == themeId) return;
    _currentThemeId = themeId;
    await _prefs.setString('theme_style_id', _currentThemeId);
    notifyListeners();
  }
}