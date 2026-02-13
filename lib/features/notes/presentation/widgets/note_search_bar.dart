import 'package:flutter/material.dart';

class NoteSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final String? hintText;
  final Color? backgroundColor;
  final double? maxWidth;

  const NoteSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.focusNode,
    this.onClear,
    this.hintText,
    this.backgroundColor,
    this.maxWidth,
  });

  @override
  State<NoteSearchBar> createState() => _NoteSearchBarState();
}

class _NoteSearchBarState extends State<NoteSearchBar> {
  // 不使用 late，避免初始化时序问题
  ValueNotifier<bool>? _showClearNotifier;

  @override
  void initState() {
    super.initState();
    _showClearNotifier = ValueNotifier(widget.controller.text.isNotEmpty);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _showClearNotifier?.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final show = widget.controller.text.isNotEmpty;
    if (_showClearNotifier != null && _showClearNotifier!.value != show) {
      _showClearNotifier!.value = show;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 防御性补救：如果热重载导致 initState 没走，手动初始化
    if (_showClearNotifier == null) {
      _showClearNotifier = ValueNotifier(widget.controller.text.isNotEmpty);
      widget.controller.addListener(_onTextChanged);
    }

    final theme = Theme.of(context);
    final bgColor = widget.backgroundColor ?? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5);

    Widget searchBar = Stack(
      alignment: Alignment.centerRight,
      children: [
        // 1. 输入框
        TextField(
          key: const ValueKey('NoteSearchTextField'),
          controller: widget.controller,
          focusNode: widget.focusNode,
          onChanged: widget.onChanged,
          textAlignVertical: TextAlignVertical.center,
          style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
          cursorColor: theme.colorScheme.primary,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hintText ?? '搜索笔记...',
            hintStyle: TextStyle(color: theme.colorScheme.outline, fontSize: 16),
            prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.outline, size: 24),
            filled: true,
            fillColor: bgColor,
            suffixIcon: null, // 禁用自带 suffix
            contentPadding: const EdgeInsets.only(left: 16, right: 48, top: 12, bottom: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5), width: 1.5)),
          ),
        ),

        // 2. 清除按钮
        // 🟢 修复：Positioned 必须是 Stack 的直接子级
        Positioned(
          right: 4,
          child: ValueListenableBuilder<bool>(
            valueListenable: _showClearNotifier!,
            builder: (context, show, child) {
              return IgnorePointer(
                ignoring: !show, // 不显示时不可点击
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: show ? 1.0 : 0.0,
                  child: child,
                ),
              );
            },
            child: IconButton(
              icon: const Icon(Icons.clear_rounded, size: 18),
              color: theme.colorScheme.onSurfaceVariant,
              style: IconButton.styleFrom(
                hoverColor: theme.colorScheme.onSurface.withOpacity(0.08),
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(32, 32),
              ),
              onPressed: () {
                widget.controller.clear();
                widget.onChanged('');
                widget.onClear?.call();
              },
            ),
          ),
        ),
      ],
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