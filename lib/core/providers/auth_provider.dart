import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class AuthProvider with ChangeNotifier {
  final _supabase = Supabase.instance.client;

  User? _currentUser;
  bool _isInitialized = false;
  StreamSubscription<AuthState>? _authStateSubscription;

  String? _localAvatarPath;
  String? get localAvatarPath => _localAvatarPath;

  // 🌟 记录上次同步的云端头像URL，用于检测变化
  String? _lastSyncedAvatarUrl;

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
        final now = DateTime.now().toUtc();
        await _supabase.from('user_profiles').upsert({
          'id': userId,
          'settings_json': {},
          'last_active_at': now.toIso8601String(),
        });
        _cloudProfileData = {'id': userId, 'settings_json': {}};
      }
      notifyListeners();

      // 🌟 检测云端头像变化，自动下载到本地
      await downloadAvatarToLocal();
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

      final now = DateTime.now().toUtc();
      await _supabase.from('user_profiles').upsert({
        'id': userId,
        'settings_json': currentSettings,
        'updated_at': now.toIso8601String(),
        'last_active_at': now.toIso8601String(),
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
      final now = DateTime.now().toUtc();
      final Map<String, dynamic> updates = {
        'updated_at': now.toIso8601String(),
        'last_active_at': now.toIso8601String(),
      };

      if (nickname != null) updates['nickname'] = nickname;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (bio != null) updates['bio'] = bio;

      if (updates.length > 2) {
        await _supabase.from('user_profiles').upsert({'id': userId, ...updates});
      }

      final currentData = Map<String, dynamic>.from(_currentUser!.userMetadata ?? {});
      if (nickname != null) currentData['full_name'] = nickname;
      if (avatarUrl != null) currentData['avatar_url'] = avatarUrl;
      if (bio != null) currentData['bio'] = bio;
      if (birthday != null) currentData['birthday'] = birthday;

      await _supabase.auth.updateUser(UserAttributes(data: currentData));

      // 🌟 保存本地头像路径到 SharedPreferences
      if (localPath != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('local_avatar_path', localPath);
        _localAvatarPath = localPath;
      }

      await refreshProfile();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      _cloudProfileData.clear();
      _lastSyncedAvatarUrl = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('local_avatar_path');
      _localAvatarPath = null;
      notifyListeners();
    } catch (e) {
      debugPrint('登出失败: $e');
    }
  }

  // 🌟 从云端下载头像到本地
  Future<void> downloadAvatarToLocal() async {
    final cloudUrl = avatarUrl;
    if (cloudUrl == null || cloudUrl.isEmpty) return;

    // 🌟 如果云端URL没变化，跳过下载
    if (_lastSyncedAvatarUrl == cloudUrl) return;

    try {
      final userId = _currentUser?.id;
      if (userId == null) return;

      final response = await http.get(Uri.parse(cloudUrl));
      if (response.statusCode != 200) {
        debugPrint('⚠️ 下载云端头像失败: HTTP ${response.statusCode}');
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final fileExt = _getFileExtensionFromUrl(cloudUrl);
      final fileName = '$userId-avatar.$fileExt';
      final localFile = File('${directory.path}/$fileName');

      await localFile.writeAsBytes(response.bodyBytes);

      // 🌟 清理旧头像文件
      await _cleanupOldLocalAvatars(userId, fileName);

      // 🌟 保存新路径
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_avatar_path', localFile.path);
      _localAvatarPath = localFile.path;
      _lastSyncedAvatarUrl = cloudUrl;

      debugPrint('✅ 云端头像已下载到本地: ${localFile.path}');
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ 下载云端头像失败: $e');
    }
  }

  // 🌟 从URL提取文件扩展名
  String _getFileExtensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final lastSegment = pathSegments.last;
        if (lastSegment.contains('.')) {
          return lastSegment.split('.').last.toLowerCase();
        }
      }
      return 'jpg';
    } catch (e) {
      return 'jpg';
    }
  }

  // 🌟 清理旧本地头像文件
  Future<void> _cleanupOldLocalAvatars(String userId, String currentFileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dir = Directory(directory.path);
      if (!await dir.exists()) return;

      final files = dir.listSync().whereType<File>().toList();
      for (final file in files) {
        final fileName = path.basename(file.path);
        // 删除属于当前用户但不是当前头像的文件
        if (fileName.startsWith('$userId-') && fileName != currentFileName) {
          await file.delete();
          debugPrint('🗑️ 清理旧本地头像: $fileName');
        }
      }
    } catch (e) {
      debugPrint('⚠️ 清理旧本地头像失败: $e');
    }
  }
}