import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/app_dimens.dart';

class AppEmptyState extends StatelessWidget {
  final String message;
  final String? subMessage;
  final IconData icon;
  final String? svgAsset;
  final Widget? action;

  const AppEmptyState({
    super.key,
    required this.message,
    this.subMessage,
    this.icon = Icons.inbox_rounded,
    this.svgAsset,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (svgAsset != null)
              SvgPicture.asset(
                svgAsset!,
                height: 120, // 适当的高度
                width: 120,
              )
            else
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                    icon,
                    size: AppDimens.emptyStateIconSize,
                    color: theme.colorScheme.outline.withValues(alpha: 0.5)
                ),
              ),

            const SizedBox(height: 24),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (subMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                subMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outlineVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}