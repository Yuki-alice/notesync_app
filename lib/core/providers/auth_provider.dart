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

  String get displayName {
    if (_currentUser == null) return '未登录';
    final metadata = _currentUser!.userMetadata;
    if (metadata != null && metadata.containsKey('full_name')) {
      final name = metadata['full_name'] as String;
      if (name.trim().isNotEmpty) return name;
    }
    return _currentUser!.email?.split('@').first ?? 'Note User';
  }

  String? get avatarUrl => _currentUser?.userMetadata?['avatar_url'] as String?;
  String? get birthday => _currentUser?.userMetadata?['birthday'] as String?;

  // 🌟 新增：获取个性签名
  String? get bio => _currentUser?.userMetadata?['bio'] as String?;

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
        notifyListeners();
        refreshProfile();
      } else if (event == AuthChangeEvent.signedOut || event == AuthChangeEvent.userDeleted) {
        _currentUser = null;
        _localAvatarPath = null;
        notifyListeners();
      }
    });
  }

  Future<void> refreshProfile() async {
    if (!isAuthenticated) return;
    try {
      final res = await _supabase.auth.getUser();
      if (res.user != null) {
        final newCloudUrl = res.user!.userMetadata?['avatar_url'] as String?;
        final oldCloudUrl = _currentUser?.userMetadata?['avatar_url'] as String?;

        if (newCloudUrl != oldCloudUrl) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('local_avatar_path');
          _localAvatarPath = null;
        }

        _currentUser = res.user;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('刷新用户资料失败: $e');
    }
  }

  // 🌟 修改：支持更新个性签名 (bio)
  Future<void> updateProfile({String? nickname, String? avatarUrl, String? birthday, String? localPath, String? bio}) async {
    if (!isAuthenticated) return;
    try {
      final currentData = Map<String, dynamic>.from(_currentUser!.userMetadata ?? {});

      if (nickname != null) currentData['full_name'] = nickname;
      if (avatarUrl != null) currentData['avatar_url'] = avatarUrl;
      if (birthday != null) currentData['birthday'] = birthday;
      if (bio != null) currentData['bio'] = bio; // 注入签名

      final response = await _supabase.auth.updateUser(
        UserAttributes(data: currentData),
      );

      if (localPath != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('local_avatar_path', localPath);
        _localAvatarPath = localPath;
      }

      _currentUser = response.user;
      notifyListeners();
    } catch (e) {
      debugPrint('更新用户资料失败: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('local_avatar_path');
      await prefs.remove('custom_categories');
      _localAvatarPath = null;
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