// 文件路径: lib/utils/toast_utils.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ToastUtils {
  // 🟢 完全还原 login_page.dart 中的极简悬浮风格
  static void _showToast(BuildContext context, String message, IconData icon, Color color) {
    if (!context.mounted) return;

    // 触发轻微的震动反馈，增加高级感
    HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.surface, // 原汁原味的纯净表面色
        elevation: 6, // 真实的物理悬浮阴影
        margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // 16px 圆角
        content: Row(
          children: [
            Icon(icon, color: color), // 极简呈现，不加多余的底座包裹
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==========================================
  // 暴露给外部调用的快捷方法
  // ==========================================

  /// ✨ 成功提示 (主题色)
  static void showInfo(BuildContext context, String message) {
    _showToast(context, message, Icons.check_circle_rounded, Colors.green);
  }

  /// 🥺 错误提示 (原版的红色)
  static void showError(BuildContext context, String message) {
    _showToast(context, message, Icons.error_outline_rounded, Colors.redAccent);
  }

  /// 🎈 信息/普通提示 (原版的绿色)
  static void showSuccess(BuildContext context, String message) {
    _showToast(context, message, Icons.auto_awesome_rounded, Theme.of(context).colorScheme.primary);
  }
}