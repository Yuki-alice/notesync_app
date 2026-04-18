import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/privacy_service.dart';
import '../../../../widgets/common/dialogs/privacy_unlock_dialog.dart';

/// 隐私模式切换按钮
/// 
/// 用于在笔记页面切换隐私笔记显示
class PrivacyToggleButton extends StatelessWidget {
  final bool isPrivateMode;
  final VoidCallback? onToggle;
  final bool showBadge;

  const PrivacyToggleButton({
    super.key,
    required this.isPrivateMode,
    this.onToggle,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLocked = !PrivacyService().isUnlocked;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleTap(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isPrivateMode
                ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrivateMode
                  ? theme.colorScheme.error.withValues(alpha: 0.3)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isPrivateMode
                      ? (isLocked ? Icons.lock : Icons.lock_open)
                      : Icons.lock_outline,
                  key: ValueKey('${isPrivateMode}_$isLocked'),
                  size: 20,
                  color: isPrivateMode
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isPrivateMode ? '私密' : '普通',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isPrivateMode
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (showBadge) ...[
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    HapticFeedback.lightImpact();

    if (isPrivateMode) {
      // 当前是隐私模式，切换到普通模式
      onToggle?.call();
    } else {
      // 当前是普通模式，尝试切换到隐私模式
      // 1. 检查是否已设置密码
      final hasPassword = await PrivacyService().hasPassword();
      
      if (!hasPassword) {
        // 首次使用，引导设置密码
        final setupSuccess = await showPrivacySetupDialog(context);
        if (setupSuccess) {
          onToggle?.call();
        }
        return;
      }

      // 2. 已设置密码，检查是否已解锁
      if (PrivacyService().isUnlocked) {
        onToggle?.call();
        return;
      }

      // 3. 需要解锁
      final unlockSuccess = await showPrivacyUnlockDialog(context);
      if (unlockSuccess) {
        onToggle?.call();
      }
    }
  }
}

/// 隐私笔记指示器（用于笔记卡片）
class PrivacyNoteIndicator extends StatelessWidget {
  final bool isLocked;

  const PrivacyNoteIndicator({
    super.key,
    this.isLocked = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLocked ? Icons.lock : Icons.lock_open,
            size: 12,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 2),
          Text(
            '私密',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
