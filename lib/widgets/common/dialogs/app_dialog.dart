import 'package:flutter/material.dart';

class AppDialog {
  /// ==========================================
  /// 1. 标准确认/信息弹窗
  /// ==========================================
  static Future<bool?> showConfirm({
    required BuildContext context,
    required String title,
    required String content,
    required IconData icon,
    Color? iconColor,
    String confirmText = '确定',
    String cancelText = '取消',
    bool isDestructive = false, // 如果是删除等危险操作，设为 true
  }) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.colorScheme.primary;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => _buildBaseDialog(
        context: ctx,
        icon: icon,
        iconColor: isDestructive ? theme.colorScheme.error : color,
        title: title,
        contentWidget: Text(
          content,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelText, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: isDestructive ? theme.colorScheme.errorContainer : null,
              foregroundColor: isDestructive ? theme.colorScheme.error : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(confirmText, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// ==========================================
  /// 2. 文本输入弹窗 (用于新建/修改分类)
  /// ==========================================
  static Future<String?> showInput({
    required BuildContext context,
    required String title,
    String? subtitle,
    required String hintText,
    String initialText = '',
    required IconData icon,
    Color? iconColor,
    String confirmText = '保存',
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _InputDialogContent(
        title: title,
        subtitle: subtitle,
        hintText: hintText,
        initialText: initialText,
        icon: icon,
        iconColor: iconColor,
        confirmText: confirmText,
      ),
    );
  }

  /// ==========================================
  /// 3. 自定义内容弹窗 (用于移动分类等复杂布局)
  /// ==========================================
  static Future<T?> showCustom<T>({
    required BuildContext context,
    required String title,
    required Widget contentWidget,
    IconData? icon,
    Color? iconColor,
    List<Widget>? actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => _buildBaseDialog(
        context: ctx,
        icon: icon,
        iconColor: iconColor ?? Theme.of(context).colorScheme.primary,
        title: title,
        contentWidget: contentWidget,
        actions: actions ?? [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// ==========================================
  /// 核心基类构建器：死死拿捏 MD3 小清新规范！
  /// ==========================================
  static Widget _buildBaseDialog({
    required BuildContext context,
    IconData? icon,
    required Color iconColor,
    required String title,
    required Widget contentWidget,
    required List<Widget> actions,
  }) {
    final theme = Theme.of(context);
    return AlertDialog(
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), // 🌟 MD3 灵魂大圆角
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),

      // 🌟 情绪化小图标
      icon: icon != null ? Container(
        width: 64, height: 64,
        decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: Icon(icon, size: 32, color: iconColor),
      ) : null,

      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      content: contentWidget,
      actions: actions,
    );
  }
}

/// 配合输入框的 Stateful 弹窗组件
class _InputDialogContent extends StatefulWidget {
  final String title, hintText, initialText, confirmText;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;

  const _InputDialogContent({
    required this.title, required this.hintText, required this.initialText,
    required this.icon, required this.confirmText, this.subtitle, this.iconColor,
  });

  @override
  State<_InputDialogContent> createState() => _InputDialogContentState();
}

class _InputDialogContentState extends State<_InputDialogContent> {
  late TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    Future.delayed(const Duration(milliseconds: 100), () => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppDialog._buildBaseDialog(
      context: context,
      icon: widget.icon,
      iconColor: widget.iconColor ?? theme.colorScheme.primary,
      title: widget.title,
      contentWidget: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.subtitle != null) ...[
            Text(widget.subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
            const SizedBox(height: 20),
          ],
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            onSubmitted: (val) => Navigator.pop(context, val.trim()),
            decoration: InputDecoration(
              hintText: widget.hintText,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消', style: TextStyle(fontWeight: FontWeight.bold))),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(widget.confirmText, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}