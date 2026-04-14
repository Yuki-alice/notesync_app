import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_provider.dart';

enum ThemeVibe { solid, gradient }

class AppThemeStyle {
  final String id;
  final String name;
  final Color seedColor;
  final ThemeVibe vibe;

  const AppThemeStyle({
    required this.id, required this.name, required this.seedColor, this.vibe = ThemeVibe.solid,
  });
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _currentThemeId = 'classic_blue';
  bool _syncSettingsToCloud = false; // 🌟 新增：用户是否开启了配置漫游

  late SharedPreferences _prefs;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get syncSettingsToCloud => _syncSettingsToCloud;

  AppThemeStyle get currentStyle => presetThemes.firstWhere(
          (t) => t.id == _currentThemeId,
      orElse: () => presetThemes.first
  );

  Color get themeColor => currentStyle.seedColor;
  String get currentThemeId => _currentThemeId;

  static const List<AppThemeStyle> presetThemes = [
    AppThemeStyle(id: 'classic_blue', name: '极简原生', seedColor: Color(0xFF5C6BC0), vibe: ThemeVibe.solid),
    AppThemeStyle(id: 'sakura_anime', name: '樱花微醺', seedColor: Color(0xFFF06292), vibe: ThemeVibe.solid),
    AppThemeStyle(id: 'mint_breeze', name: '薄荷微风', seedColor: Color(0xFF009688), vibe: ThemeVibe.gradient),
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
    _syncSettingsToCloud = _prefs.getBool('sync_settings_to_cloud') ?? false; // 默认不漫游，尊重设备独立性
    notifyListeners();
  }

  // 🌟 新增：切换是否允许云端漫游设置
  Future<void> toggleSyncSettings(bool value, AuthProvider authProvider) async {
    _syncSettingsToCloud = value;
    await _prefs.setBool('sync_settings_to_cloud', value);
    notifyListeners();

    // 如果用户刚刚打开了同步开关，立即将当前设备的配置推送到云端作为基准
    if (value) {
      _pushSettingsToCloud(authProvider);
    }
  }

  // 🌟 新增：从云端拉取设置并覆盖本地 (建议在主界面的 initState 里，或登录成功后调用)
  Future<void> tryPullSettingsFromCloud(AuthProvider authProvider) async {
    if (!_syncSettingsToCloud || !authProvider.isAuthenticated) return;

    final cloudSettings = authProvider.cloudSettings;
    if (cloudSettings.isEmpty) return;

    bool changed = false;

    if (cloudSettings.containsKey('theme_mode_index')) {
      final cloudMode = ThemeMode.values[cloudSettings['theme_mode_index']];
      if (_themeMode != cloudMode) {
        _themeMode = cloudMode;
        await _prefs.setInt('theme_mode_index', cloudMode.index);
        changed = true;
      }
    }

    if (cloudSettings.containsKey('theme_style_id')) {
      final cloudStyleId = cloudSettings['theme_style_id'];
      if (_currentThemeId != cloudStyleId) {
        _currentThemeId = cloudStyleId;
        await _prefs.setString('theme_style_id', _currentThemeId);
        changed = true;
      }
    }

    if (changed) notifyListeners();
  }

  // 内部辅助方法：推送到云端
  Future<void> _pushSettingsToCloud(AuthProvider authProvider) async {
    if (!_syncSettingsToCloud || !authProvider.isAuthenticated) return;

    await authProvider.updateCloudSettings({
      'theme_mode_index': _themeMode.index,
      'theme_style_id': _currentThemeId,
    });
  }

  Future<void> setThemeMode(ThemeMode mode, {AuthProvider? authProvider}) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    await _prefs.setInt('theme_mode_index', mode.index);
    notifyListeners();

    if (authProvider != null) _pushSettingsToCloud(authProvider);
  }

  Future<void> setThemeStyle(String themeId, {AuthProvider? authProvider}) async {
    if (_currentThemeId == themeId) return;
    _currentThemeId = themeId;
    await _prefs.setString('theme_style_id', _currentThemeId);
    notifyListeners();

    if (authProvider != null) _pushSettingsToCloud(authProvider);
  }
}