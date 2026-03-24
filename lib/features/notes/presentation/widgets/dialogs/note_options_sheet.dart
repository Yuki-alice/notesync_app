import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/providers/notes_provider.dart';
import '../../../../../models/note.dart';
import '../../../../../utils/toast_utils.dart';
import '../../../../../widgets/common/dialogs/app_dialog.dart';

void showNoteOptionsSheet(BuildContext parentContext, Note note) {
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
          child: _NoteOptionsContent(
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
          child: _NoteOptionsContent(
            note: note,
            isDesktop: false,
            parentContext: parentContext,
          ),
        ),
      ),
    );
  }
}

class _NoteOptionsContent extends StatelessWidget {
  final Note note;
  final bool isDesktop;
  final BuildContext parentContext;

  const _NoteOptionsContent({
    required this.note,
    this.isDesktop = false,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<NotesProvider>(context, listen: false);

    // 🌟 V2: 翻译顶部显示的分类名字
    final realCategory = provider.getCategoryById(note.categoryId);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                    Icons.description_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
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
                      realCategory?.name ?? '未分类', // 🌟 显示翻译后的名字
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        _OptionTile(
          icon: note.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
          title: note.isPinned ? '取消置顶' : '置顶笔记',
          color: theme.colorScheme.secondaryContainer,
          onColor: theme.colorScheme.onSecondaryContainer,
          onTap: () {
            Navigator.pop(context);
            provider.togglePin(note.id);
            if (parentContext.mounted) {
              ToastUtils.showInfo(parentContext, note.isPinned ? '已取消置顶' : '已置顶 ');
            }
          },
        ),

        const SizedBox(height: 12),

        _OptionTile(
          icon: Icons.drive_file_move_rounded,
          title: '移动分类',
          color: theme.colorScheme.surfaceContainerHighest,
          onColor: theme.colorScheme.onSurface,
          trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5)
          ),
          onTap: () {
            Navigator.pop(context);
            Future.delayed(const Duration(milliseconds: 150), () {
              _showMoveCategoryDialog(parentContext, note, provider);
            });
          },
        ),

        const SizedBox(height: 12),

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

  void _showMoveCategoryDialog(BuildContext parentContext, Note note, NotesProvider provider) {
    final theme = Theme.of(parentContext);
    final categories = provider.categories; // 🌟 List<Category>

    AppDialog.showCustom(
      context: parentContext,
      title: '移动分类',
      icon: Icons.drive_file_move_rounded,
      contentWidget: SizedBox(
        width: 360,
        child: Wrap(
          spacing: 8, runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            ActionChip(
              avatar: const Icon(Icons.folder_off_outlined, size: 18),
              label: const Text('未分类'),
              onPressed: () async {
                Navigator.pop(parentContext);
                await provider.updateNote(note.copyWith(clearCategory: true));
                if (parentContext.mounted) ToastUtils.showSuccess(parentContext, '已移出分类 ✨');
              },
              backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              side: BorderSide.none,
              shape: const StadiumBorder(),
            ),
            ...categories.map((category) {
              final isCurrent = note.categoryId == category.id; // 🌟 比较 ID
              return FilterChip(
                label: Text(category.name), // 🌟 显示 name
                selected: isCurrent,
                onSelected: (_) async {
                  Navigator.pop(parentContext);
                  await provider.updateNote(note.copyWith(categoryId: category.id)); // 🌟 更新时存入 ID
                  if (parentContext.mounted) ToastUtils.showSuccess(parentContext, '已移动到 "${category.name}" ✨');
                },
                checkmarkColor: theme.colorScheme.onPrimaryContainer,
                selectedColor: theme.colorScheme.primaryContainer,
                backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                side: BorderSide.none,
                shape: const StadiumBorder(),
              );
            }),
          ],
        ),
      ),
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