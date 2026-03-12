import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginViewModel extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  // --- 状态变量 ---
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;

  // --- 状态获取 ---
  bool get isLoading => _isLoading;
  bool get isSignUp => _isSignUp;
  bool get obscurePassword => _obscurePassword;

  // --- 状态变更方法 ---
  void toggleSignUpMode() {
    _isSignUp = !_isSignUp;
    notifyListeners();
  }

  void togglePasswordVisibility() {
    _obscurePassword = !_obscurePassword;
    notifyListeners();
  }

  // --- 业务逻辑：商业级错误翻译 ---
  String _translateAuthError(String message) {
    final msg = message.toLowerCase();
    if (msg.contains('invalid login credentials')) return '邮箱或密码错误，请重试 🥺';
    if (msg.contains('user already registered')) return '该邮箱已注册，请直接登录呀~';
    if (msg.contains('password should be at least')) return '密码安全性太弱，不能少于 6 位哦';
    if (msg.contains('unable to validate email')) return '请输入有效的邮箱地址';
    if (msg.contains('rate limit')) return '操作太频繁啦，请稍后再试☕';
    return '验证失败，请稍后再试 ($message)';
  }

  // --- 业务逻辑：登录与注册 ---
  // 返回值：如果成功返回 null，如果是注册成功返回特定标识，如果失败返回错误信息
  Future<String?> authenticate({required String email, required String password}) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_isSignUp) {
        // 注册流程
        await _supabase.auth.signUp(email: email, password: password);
        await _supabase.auth.signOut(); // 强制登出，避免静默登录

        _isSignUp = false; // 注册成功后自动切回登录模式
        _isLoading = false;
        notifyListeners();
        return 'SIGNUP_SUCCESS';
      } else {
        // 登录流程
        await _supabase.auth.signInWithPassword(email: email, password: password);
        _isLoading = false;
        notifyListeners();
        return null; // 登录成功
      }
    } on AuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return _translateAuthError(e.message);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return '网络开小差了，请检查网络连接 📡';
    }
  }

  // --- 业务逻辑：忘记密码 ---
  Future<String?> resetPassword(String email) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      _isLoading = false;
      notifyListeners();
      return null; // 成功
    } on AuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      return _translateAuthError(e.message);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return '网络错误，请稍后重试';
    }
  }
}