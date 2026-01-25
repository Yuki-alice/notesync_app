import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  late SharedPreferences _prefs;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemePrefs();
  }

  Future<void> _loadThemePrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _isDarkMode = _prefs.getBool('is_dark_mode') ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _prefs.setBool('is_dark_mode', _isDarkMode);
    notifyListeners();
  }

  ThemeData get currentTheme {
    // 使用 Material 3 的 ColorScheme
    final brightness = _isDarkMode ? Brightness.dark : Brightness.light;
    return ThemeData(
      useMaterial3: true, // 启用 M3
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blueAccent, // 种子颜色
        brightness: brightness,
      ),
      // 优化 AppBar 样式
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 2, // 滚动时的阴影效果
        backgroundColor: _isDarkMode ? null : Colors.white, // 浅色模式下白色背景更干净
      ),
      // 优化卡片样式
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias, // 裁剪内容适配圆角
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}