// 文件路径: lib/widgets/common/dialogs/app_sheet.dart
import 'package:flutter/material.dart';

class AppSheet {
  /// 🟢 统一的 Sheet 调用入口
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    double desktopMaxWidth = 420,
  }) {
    // 响应式判断：宽度大于等于 600 认为是桌面端/平板
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    if (isDesktop) {
      // 💻 电脑端：渲染为居中弹窗 (Dialog)
      return showDialog<T>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Theme.of(ctx).colorScheme.surface,
          surfaceTintColor: Colors.transparent, // Dialog 组件本身支持这个属性，保留以防 MD3 颜色泛紫
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), // MD3 大圆角
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: desktopMaxWidth),
            // 套一层 Clip 确保内部内容不会溢出圆角
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: builder(ctx),
            ),
          ),
        ),
      );
    } else {
      // 📱 手机端：渲染为底部抽屉 (ModalBottomSheet)
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true, // 允许全屏高度 (配合键盘)
        useSafeArea: true, // 避开顶部刘海屏
        showDragHandle: true, // 🌟 开启 MD3 原生的小清新拖拽指示条！
        backgroundColor: Theme.of(context).colorScheme.surface,
        // ❌ 这里删除了不支持的 surfaceTintColor 属性
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (ctx) => builder(ctx),
      );
    }
  }
}