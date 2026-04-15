import 'package:flutter/material.dart';
import '../../../../../../models/tag.dart';

class PremiumPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;
  final VoidCallback? onTap;

  const PremiumPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

class PremiumTagPill extends StatelessWidget {
  final Tag tag;
  final ThemeData theme;
  final VoidCallback? onDelete;

  const PremiumTagPill({
    super.key,
    required this.tag,
    required this.theme,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onDelete,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('# ${tag.name}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.secondary, letterSpacing: 0.3)),
              if (onDelete != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.close_rounded, size: 14, color: theme.colorScheme.secondary.withValues(alpha: 0.6)),
              ]
            ],
          ),
        ),
      ),
    );
  }
}