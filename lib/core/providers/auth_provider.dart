import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  User? _currentUser;
  bool _isInitialized = false;
  StreamSubscription<AuthState>? _authStateSubscription;

  String? _localAvatarPath;
  String? get localAvatarPath => _localAvatarPath;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _isInitialized;

  // 🌟 新增：从数据库 user_profiles 表缓存的数据
  Map<String, dynamic> _cloudProfileData = {};
  Map<String, dynamic> get cloudSettings => _cloudProfileData['settings_json'] ?? {};

  String get displayName {
    if (_currentUser == null) return '未登录';
    if (_cloudProfileData['nickname'] != null && _cloudProfileData['nickname'].toString().isNotEmpty) {
      return _cloudProfileData['nickname'];
    }
    final metadata = _currentUser!.userMetadata;
    if (metadata != null && metadata.containsKey('full_name')) {
      final name = metadata['full_name'] as String;
      if (name.trim().isNotEmpty) return name;
    }
    return _currentUser!.email?.split('@').first ?? 'Note User';
  }

  String? get avatarUrl => _cloudProfileData['avatar_url'] ?? _currentUser?.userMetadata?['avatar_url'];
  String? get bio => _cloudProfileData['bio'] ?? _currentUser?.userMetadata?['bio'];
  String? get birthday => _currentUser?.userMetadata?['birthday'] as String?;

  AuthProvider() {
    _initializeAuth();
  }

  void _initializeAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _localAvatarPath = prefs.getString('local_avatar_path');

    _currentUser = _supabase.auth.currentUser;
    _isInitialized = true;
    notifyListeners();

    if (_currentUser != null) refreshProfile();

    _authStateSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        _currentUser = session?.user;
        refreshProfile();
      } else if (event == AuthChangeEvent.signedOut || event == AuthChangeEvent.userDeleted) {
        _currentUser = null;
        _localAvatarPath = null;
        _cloudProfileData.clear();
        notifyListeners();
      }
    });
  }

  // 🌟 核心修复：拉取 user_profiles 业务表
  Future<void> refreshProfile() async {
    if (!isAuthenticated) return;
    try {
      final userId = _currentUser!.id;
      // 🌟 读取 settings_json 所在表
      final data = await _supabase.from('user_profiles').select().eq('id', userId).maybeSingle();

      if (data != null) {
        _cloudProfileData = data;
      } else {
        // 兜底：如果没数据，初始化一行
        await _supabase.from('user_profiles').upsert({'id': userId, 'settings_json': {}});
        _cloudProfileData = {'id': userId, 'settings_json': {}};
      }
      notifyListeners();
    } catch (e) {
      debugPrint('刷新 user_profiles 失败: $e');
    }
  }

  // 🌟 核心修复：专门用于更新漫游设置的接口
  Future<void> updateCloudSettings(Map<String, dynamic> newSettings) async {
    if (!isAuthenticated) return;
    try {
      final userId = _currentUser!.id;
      final currentSettings = Map<String, dynamic>.from(_cloudProfileData['settings_json'] ?? {});
      currentSettings.addAll(newSettings);

      await _supabase.from('user_profiles').upsert({
        'id': userId,
        'settings_json': currentSettings,
        'updated_at': DateTime.now().toUtc().toIso8601String()
      });

      _cloudProfileData['settings_json'] = currentSettings;
      notifyListeners();
    } catch (e) {
      debugPrint('漫游设置上传失败: $e');
    }
  }

  Future<void> updateProfile({String? nickname, String? avatarUrl, String? birthday, String? localPath, String? bio}) async {
    if (!isAuthenticated) return;
    try {
      final userId = _currentUser!.id;
      final Map<String, dynamic> updates = {'updated_at': DateTime.now().toUtc().toIso8601String()};

      if (nickname != null) updates['nickname'] = nickname;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (bio != null) updates['bio'] = bio;

      if (updates.length > 1) {
        await _supabase.from('user_profiles').upsert({'id': userId, ...updates});
      }

      final currentData = Map<String, dynamic>.from(_currentUser!.userMetadata ?? {});
      if (nickname != null) currentData['full_name'] = nickname;
      if (avatarUrl != null) currentData['avatar_url'] = avatarUrl;
      if (bio != null) currentData['bio'] = bio;
      if (birthday != null) currentData['birthday'] = birthday;

      await _supabase.auth.updateUser(UserAttributes(data: currentData));
      await refreshProfile();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      _cloudProfileData.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('local_avatar_path');
      _localAvatarPath = null;
      notifyListeners();
    } catch (e) {
      debugPrint('登出失败: $e');
    }
  }
}