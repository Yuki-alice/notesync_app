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

  // 从数据库 UserProfile 表中缓存的数据
  Map<String, dynamic> _cloudProfileData = {};
  Map<String, dynamic> get cloudSettings => _cloudProfileData['settings_json'] ?? {};

  String get displayName {
    if (_currentUser == null) return '未登录';
    if (_cloudProfileData['nickname'] != null && _cloudProfileData['nickname'].toString().isNotEmpty) {
      return _cloudProfileData['nickname'];
    }
    // 兜底逻辑
    final metadata = _currentUser!.userMetadata;
    if (metadata != null && metadata.containsKey('full_name')) {
      final name = metadata['full_name'] as String;
      if (name.trim().isNotEmpty) return name;
    }
    return _currentUser!.email?.split('@').first ?? 'Note User';
  }

  String? get avatarUrl => _cloudProfileData['avatar_url'] ?? _currentUser?.userMetadata?['avatar_url'];
  String? get bio => _cloudProfileData['bio'] ?? _currentUser?.userMetadata?['bio'];

  // 🌟 补回来的 birthday（继续安全地存在 Auth MetaData 中）
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

    if (_currentUser != null) await refreshProfile();

    _authStateSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        _currentUser = session?.user;
        notifyListeners();
        refreshProfile();
      } else if (event == AuthChangeEvent.signedOut || event == AuthChangeEvent.userDeleted) {
        _currentUser = null;
        _localAvatarPath = null;
        _cloudProfileData.clear();
        notifyListeners();
      }
    });
  }

  Future<void> refreshProfile() async {
    if (!isAuthenticated) return;
    try {
      final userId = _currentUser!.id;
      final data = await _supabase.from('user_profiles').select().eq('id', userId).maybeSingle();

      if (data != null) {
        _cloudProfileData = data;
      } else {
        await _supabase.from('user_profiles').upsert({'id': userId, 'settings_json': {}});
        _cloudProfileData = {'id': userId, 'settings_json': {}};
      }

      // 顺便刷新一下底层的 Auth 用户信息，确保 birthday 不会过期
      final res = await _supabase.auth.getUser();
      if (res.user != null) {
        _currentUser = res.user;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('刷新 user_profiles 失败: $e');
    }
  }

  // 🌟 补回了 birthday 参数
  Future<void> updateProfile({String? nickname, String? avatarUrl, String? birthday, String? localPath, String? bio}) async {
    if (!isAuthenticated) return;
    try {
      final userId = _currentUser!.id;
      final Map<String, dynamic> updates = {'updated_at': DateTime.now().toUtc().toIso8601String()};

      if (nickname != null) updates['nickname'] = nickname;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (bio != null) updates['bio'] = bio;

      // 如果有业务字段修改，更新业务表
      if (updates.length > 1) {
        await _supabase.from('user_profiles').upsert({'id': userId, ...updates});
      }

      // 同步更新底层 auth meta (包含了补回来的 birthday)
      final currentData = Map<String, dynamic>.from(_currentUser!.userMetadata ?? {});
      if (nickname != null) currentData['full_name'] = nickname;
      if (avatarUrl != null) currentData['avatar_url'] = avatarUrl;
      if (bio != null) currentData['bio'] = bio;
      if (birthday != null) currentData['birthday'] = birthday; // 🌟 关键：保存到 Metadata

      await _supabase.auth.updateUser(UserAttributes(data: currentData));

      if (localPath != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('local_avatar_path', localPath);
        _localAvatarPath = localPath;
      }

      await refreshProfile();
    } catch (e) {
      debugPrint('更新资料失败: $e');
      rethrow;
    }
  }

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

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('local_avatar_path');
      await prefs.remove('custom_categories');
      _localAvatarPath = null;
      _cloudProfileData.clear();
    } catch (e) {
      debugPrint('登出失败: $e');
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }
}