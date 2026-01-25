import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  late SharedPreferences _prefs;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemePrefs();
  }

  // 加载本地主题配置
  Future<void> _loadThemePrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _isDarkMode = _prefs.getBool('is_dark_mode') ?? false;
    notifyListeners();
  }

  // 切换主题
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _prefs.setBool('is_dark_mode', _isDarkMode);
    notifyListeners();
  }

  // 获取当前主题
  ThemeData get currentTheme {
    return _isDarkMode ? ThemeData.dark() : ThemeData.light().copyWith(
      primaryColor: Colors.blueAccent,
      scaffoldBackgroundColor: Colors.white,
    );
  }
}