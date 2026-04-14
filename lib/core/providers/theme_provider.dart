import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_provider.dart';

enum ThemeVibe { solid, gradient }

class AppThemeStyle {
  final String id;
  final String name;
  final Color seedColor;
  final ThemeVibe vibe;
  const AppThemeStyle({required this.id, required this.name, required this.seedColor, this.vibe = ThemeVibe.solid});
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _currentThemeId = 'classic_blue';
  bool _isProMode = false;
  bool _syncSettingsToCloud = false;

  late SharedPreferences _prefs;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isProMode => _isProMode;
  bool get syncSettingsToCloud => _syncSettingsToCloud;

  AppThemeStyle get currentStyle => presetThemes.firstWhere((t) => t.id == _currentThemeId, orElse: () => presetThemes.first);
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
    _themeMode = ThemeMode.values[_prefs.getInt('theme_mode_index') ?? ThemeMode.system.index];
    _currentThemeId = _prefs.getString('theme_style_id') ?? 'classic_blue';
    _isProMode = _prefs.getBool('isProMode') ?? false;
    _syncSettingsToCloud = _prefs.getBool('sync_settings_to_cloud') ?? false;
    notifyListeners();
  }

  // 🌟 核心修复：防反向覆盖的开关逻辑
  Future<void> toggleSyncSettings(bool value, AuthProvider authProvider) async {
    _syncSettingsToCloud = value;
    await _prefs.setBool('sync_settings_to_cloud', value);
    if (value && authProvider.isAuthenticated) {
      if (authProvider.cloudSettings.isNotEmpty) {
        await tryPullSettingsFromCloud(authProvider);
      } else {
        await _pushSettingsToCloud(authProvider);
      }
    }
    notifyListeners();
  }

  // 🌟 核心修复：全量拉取
  Future<void> tryPullSettingsFromCloud(AuthProvider authProvider) async {
    if (!_syncSettingsToCloud || !authProvider.isAuthenticated) return;
    final cloud = authProvider.cloudSettings;
    if (cloud.isEmpty) return;

    bool changed = false;
    if (cloud.containsKey('theme_mode_index')) {
      _themeMode = ThemeMode.values[cloud['theme_mode_index']];
      await _prefs.setInt('theme_mode_index', _themeMode.index);
      changed = true;
    }
    if (cloud.containsKey('theme_style_id')) {
      _currentThemeId = cloud['theme_style_id'];
      await _prefs.setString('theme_style_id', _currentThemeId);
      changed = true;
    }
    if (cloud.containsKey('is_pro_mode')) {
      _isProMode = cloud['is_pro_mode'];
      await _prefs.setBool('isProMode', _isProMode);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  Future<void> _pushSettingsToCloud(AuthProvider authProvider) async {
    if (!_syncSettingsToCloud || !authProvider.isAuthenticated) return;
    await authProvider.updateCloudSettings({
      'theme_mode_index': _themeMode.index,
      'theme_style_id': _currentThemeId,
      'is_pro_mode': _isProMode,
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
    await _prefs.setString('theme_style_id', themeId);
    notifyListeners();
    if (authProvider != null) _pushSettingsToCloud(authProvider);
  }

  Future<void> setProMode(bool value, {AuthProvider? authProvider}) async {
    if (_isProMode == value) return;
    _isProMode = value;
    await _prefs.setBool('isProMode', value);
    notifyListeners();
    if (authProvider != null) _pushSettingsToCloud(authProvider);
  }
}