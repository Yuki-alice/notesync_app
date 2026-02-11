
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppFeedback {

  const AppFeedback._();

  static void light() {
    HapticFeedback.lightImpact();
  }

  static void medium() {
    HapticFeedback.mediumImpact();
  }

  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  static void selection() {
    HapticFeedback.selectionClick();
  }

  static void show(BuildContext context, String message, {bool isError = false}) {
    final theme = Theme.of(context);

    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: isError ? theme.colorScheme.error : theme.colorScheme.onInverseSurface,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError ? theme.colorScheme.error : theme.colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? theme.colorScheme.errorContainer : theme.colorScheme.inverseSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
        elevation: 4,
      ),
    );
  }
}