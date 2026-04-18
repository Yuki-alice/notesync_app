import 'package:flutter/material.dart';
import '../services/privacy_service.dart';

/// 隐私模式状态管理
/// 
/// 用于跨组件共享隐私笔记模式状态
/// 让 MainScreen 和 NotesPage 都能感知隐私模式
class PrivacyModeProvider extends ChangeNotifier {
  bool _isPrivateMode = false;
  
  bool get isPrivateMode => _isPrivateMode;
  
  /// 进入隐私模式
  Future<bool> enterPrivateMode(BuildContext context) async {
    final privacy = PrivacyService();
    
    // 如果未设置密码，提示先设置
    if (!await privacy.hasPassword()) {
      return false; // 需要外部处理设置对话框
    }
    
    // 如果已锁定，需要解锁
    if (!privacy.isUnlocked) {
      return false; // 需要外部处理解锁对话框
    }
    
    _isPrivateMode = true;
    notifyListeners();
    return true;
  }
  
  /// 直接进入隐私模式（已解锁状态下）
  void enterPrivateModeDirect() {
    _isPrivateMode = true;
    notifyListeners();
  }
  
  /// 退出隐私模式
  void exitPrivateMode() {
    _isPrivateMode = false;
    notifyListeners();
  }
  
  /// 切换隐私模式
  Future<bool> togglePrivateMode(BuildContext context) async {
    if (_isPrivateMode) {
      exitPrivateMode();
      return true;
    } else {
      return await enterPrivateMode(context);
    }
  }
  
  /// 重置状态（用于应用重启等场景）
  void reset() {
    _isPrivateMode = false;
    notifyListeners();
  }
}
