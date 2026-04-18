import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/providers/notes_provider.dart';
import '../../../../../models/note.dart';
import '../../../../../utils/toast_utils.dart';
import '../../../../../widgets/common/dialogs/app_dialog.dart';

/// 私密笔记选项 Sheet
/// 
/// 与普通笔记的区别：
/// - 有置顶、删除、解除私密
/// - 没有移动分类功能
void showPrivateNoteOptionsSheet(BuildContext parentContext, Note note) {
  final screenWidth = MediaQuery.of(parentContext).size.width;
  final isDesktop = screenWidth >= 600;

  if (isDesktop) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(dialogContext).colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        scrollable: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: SizedBox(
          width: 320,
          child: _PrivateNoteOptionsContent(
            note: note,
            isDesktop: true,
            parentContext: parentContext,
          ),
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: parentContext,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(parentContext).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: _PrivateNoteOptionsContent(
            note: note,
            isDesktop: false,
            parentContext: parentContext,
          ),
        ),
      ),
    );
  }
}

class _PrivateNoteOptionsContent extends StatelessWidget {
  final Note note;
  final bool isDesktop;
  final BuildContext parentContext;

  const _PrivateNoteOptionsContent({
    required this.note,
    this.isDesktop = false,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<NotesProvider>(context, listen: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.error.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                    Icons.lock_rounded,
                    color: theme.colorScheme.onErrorContainer,
                    size: 20
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title.isEmpty ? '无标题' : note.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '私密笔记',
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.error
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 置顶/取消置顶
        _OptionTile(
          icon: note.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
          title: note.isPinned ? '取消置顶' : '置顶笔记',
          color: theme.colorScheme.secondaryContainer,
          onColor: theme.colorScheme.onSecondaryContainer,
          onTap: () {
            Navigator.pop(context);
            provider.togglePin(note.id);
            if (parentContext.mounted) {
              ToastUtils.showInfo(parentContext, note.isPinned ? '已取消置顶' : '已置顶');
            }
          },
        ),

        const SizedBox(height: 12),

        // 🌟 解除私密
        _OptionTile(
          icon: Icons.lock_open_rounded,
          title: '解除私密',
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          onColor: theme.colorScheme.onPrimaryContainer,
          onTap: () async {
            Navigator.pop(context);
            final confirm = await _confirmUnsetPrivate(parentContext, note);
            if (confirm == true) {
              await provider.updateNote(note.copyWith(isPrivate: false));
              if (parentContext.mounted) {
                ToastUtils.showSuccess(parentContext, '已解除私密 🔓');
              }
            }
          },
        ),

        const SizedBox(height: 12),

        // 删除
        _OptionTile(
          icon: Icons.delete_rounded,
          title: '删除笔记',
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
          onColor: theme.colorScheme.error,
          onTap: () async {
            Navigator.pop(context);
            final confirm = await _confirmDelete(parentContext, note);
            if (confirm == true) {
              await provider.deleteNote(note.id);
              if (parentContext.mounted) {
                ToastUtils.showError(parentContext, '已移至回收站 🗑️');
              }
            }
          },
        ),
      ],
    );
  }

  /// 确认解除私密对话框
  Future<bool?> _confirmUnsetPrivate(BuildContext parentContext, Note note) async {
    return await AppDialog.showConfirm(
      context: parentContext,
      title: '解除私密?',
      content: '解除后，笔记将变为普通笔记，\n不再加密存储。',
      icon: Icons.lock_open_rounded,
      confirmText: '解除私密',
      isDestructive: false,
    );
  }

  Future<bool?> _confirmDelete(BuildContext parentContext, Note note) async {
    return await AppDialog.showConfirm(
      context: parentContext,
      title: '确认删除?',
      content: '笔记将被移至回收站，\n你可以在那里随时还原。',
      icon: Icons.delete_rounded,
      confirmText: '移至回收站',
      isDestructive: true,
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Color onColor;
  final VoidCallback onTap;
  final Widget? trailing;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onColor,
    required this.onTap,
    this.trailing
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16)
        ),
        child: Row(
          children: [
            Icon(icon, color: onColor, size: 22),
            const SizedBox(width: 16),
            Text(
                title,
                style: TextStyle(
                    color: onColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 15
                )
            ),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
