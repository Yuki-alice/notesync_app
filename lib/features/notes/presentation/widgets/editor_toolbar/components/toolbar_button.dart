import 'package:flutter/material.dart';

class ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;
  final Color? activeColor;
  final Color? inactiveColor;
  final String? tooltip;

  const ToolbarIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.isActive = false,
    this.activeColor,
    this.inactiveColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aColor = activeColor ?? theme.colorScheme.primary;
    final iColor = inactiveColor ?? theme.colorScheme.onSurfaceVariant;

    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isActive ? aColor.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed, icon: Icon(icon), color: isActive ? aColor : iColor,
        iconSize: 22, padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ),
    );

    return tooltip != null ? Tooltip(message: tooltip!, child: button) : button;
  }
}

class ToolbarDivider extends StatelessWidget {
  const ToolbarDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16, width: 1,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}