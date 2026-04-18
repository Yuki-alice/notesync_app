import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NoteSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onLongPress;
  final String? hintText;
  final Color? backgroundColor;
  final double? maxWidth;

  const NoteSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.focusNode,
    this.onClear,
    this.onLongPress,
    this.hintText,
    this.backgroundColor,
    this.maxWidth,
  });

  @override
  State<NoteSearchBar> createState() => _NoteSearchBarState();
}

class _NoteSearchBarState extends State<NoteSearchBar> {
  Timer? _longPressTimer;

  // 🌟 核心突破：绕过 TextField 原生手势拦截，监听底层物理点击
  void _startLongPressTimer() {
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(milliseconds: 600), () {
      if (widget.onLongPress != null) {
        HapticFeedback.heavyImpact(); // 加入强烈的物理震动反馈
        widget.onLongPress!();
      }
    });
  }

  void _cancelLongPressTimer() {
    _longPressTimer?.cancel();
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = widget.backgroundColor ??
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);

    // 使用 Listener 捕获全局长按事件，包裹原生的 SearchBar
    Widget searchBar = Listener(
      onPointerDown: (_) => _startLongPressTimer(), // 手指按下开始倒计时
      onPointerUp: (_) => _cancelLongPressTimer(),  // 抬起取消
      onPointerCancel: (_) => _cancelLongPressTimer(),
      onPointerMove: (event) {
        if (event.delta.distance > 2) {
          _cancelLongPressTimer(); // 只要手指产生了滑动，就取消长按判定
        }
      },
      child: SearchBar(
        controller: widget.controller,
        focusNode: widget.focusNode,
        hintText: widget.hintText ?? '搜索笔记...',
        leading: Icon(Icons.search, size: 20, color: theme.colorScheme.outline),
        elevation: WidgetStateProperty.all(0),
        backgroundColor: WidgetStateProperty.all(bgColor),
        constraints: const BoxConstraints(minHeight: 48, maxHeight: 48),
        onChanged: widget.onChanged,
        trailing: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, value, child) {
              return AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: value.text.isNotEmpty ? 1.0 : 0.0,
                child: value.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  color: theme.colorScheme.onSurfaceVariant,
                  onPressed: () {
                    widget.controller.clear();
                    widget.onChanged('');
                    widget.onClear?.call();
                  },
                )
                    : const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
    );

    if (widget.maxWidth != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth!),
        child: searchBar,
      );
    }

    return searchBar;
  }
}