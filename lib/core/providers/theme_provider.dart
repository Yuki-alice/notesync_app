import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  int _colorSeedValue = Colors.indigo.value; // 默认颜色值的整数表示
  late SharedPreferences _prefs;

  bool get isDarkMode => _isDarkMode;
  Color get themeColor => Color(_colorSeedValue); // 获取当前颜色对象

  // 🟢 预设的颜色列表 (MD3 推荐色)
  static const List<Color> presetColors = [
    Colors.indigo,
    Colors.blue,
    Colors.teal,
    Colors.green,
    Colors.orange,
    Colors.deepOrange,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.blueGrey,
  ];

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider() {
    _loadThemePrefs();
  }

  Future<void> _loadThemePrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _isDarkMode = _prefs.getBool('is_dark_mode') ?? false;
    // 读取保存的颜色值，如果没有则默认 Indigo
    _colorSeedValue = _prefs.getInt('theme_color_value') ?? Colors.indigo.value;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _prefs.setBool('is_dark_mode', _isDarkMode);
    notifyListeners();
  }

  // 🟢 新增：设置主题色
  Future<void> setThemeColor(Color color) async {
    if (_colorSeedValue == color.value) return;
    _colorSeedValue = color.value;
    await _prefs.setInt('theme_color_value', _colorSeedValue);
    notifyListeners();
  }
}