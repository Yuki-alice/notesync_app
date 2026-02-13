import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/providers/notes_provider.dart';
import '../../../../../models/note.dart';


// 🟢 入口方法：根据屏幕宽度自动选择展示方式
void showNoteOptionsSheet(BuildContext context, Note note) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isDesktop = screenWidth >= 600;

  if (isDesktop) {
    // 💻 电脑端：显示为居中弹窗 (Dialog)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        // 限制弹窗宽度，使其精致紧凑
        scrollable: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        // 直接复用内容组件，但限制宽度
        content: SizedBox(
          width: 320,
          child: _NoteOptionsContent(note: note, isDesktop: true),
        ),
      ),
    );
  } else {
    // 📱 手机端：显示为底部抽屉 (BottomSheet)
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: _NoteOptionsContent(note: note, isDesktop: false),
        ),
      ),
    );
  }
}

// 🟢 核心内容组件 (抽离出来，供双端复用)
class _NoteOptionsContent extends StatelessWidget {
  final Note note;
  final bool isDesktop;

  const _NoteOptionsContent({
    required this.note,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<NotesProvider>(context, listen: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. 顶部信息卡片
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withOpacity(0.2),
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
                      note.category ?? '未分类',
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

        // 2. 操作选项列表
        _OptionTile(
          icon: note.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
          title: note.isPinned ? '取消置顶' : '置顶笔记',
          // 使用 Tonal 颜色风格
          color: theme.colorScheme.secondaryContainer,
          onColor: theme.colorScheme.onSecondaryContainer,
          onTap: () {
            Navigator.pop(context);
            provider.togglePin(note.id);
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
              color: theme.colorScheme.onSurface.withOpacity(0.5)
          ),
          onTap: () {
            Navigator.pop(context); // 先关闭当前弹窗
            // 延迟一点显示下一个弹窗，体验更流畅
            Future.delayed(const Duration(milliseconds: 150), () {
              _showMoveCategoryDialog(context, note, provider);
            });
          },
        ),

        const SizedBox(height: 12),

        _OptionTile(
          icon: Icons.delete_rounded,
          title: '删除笔记',
          color: theme.colorScheme.errorContainer.withOpacity(0.5),
          onColor: theme.colorScheme.error,
          onTap: () async {
            // 电脑端直接显示确认框在当前层级之上可能体验更好，但为了逻辑简单，先关闭当前层
            Navigator.pop(context);
            final confirm = await _confirmDelete(context, note);
            if (confirm == true) {
              await provider.deleteNote(note.id);
              if (context.mounted) _showSnackBar(context, '已移至回收站');
            }
          },
        ),
      ],
    );
  }

  // 内部辅助方法：移动分类弹窗
  void _showMoveCategoryDialog(BuildContext context, Note note, NotesProvider provider) {
    final theme = Theme.of(context);
    final categories = provider.categories;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('移动到...'),
        content: SizedBox(
          width: 300, // 限制宽度
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.folder_off_outlined, size: 18),
                  label: const Text('未分类'),
                  onPressed: () async {
                    await provider.updateNote(note.copyWith(clearCategory: true));
                    if (ctx.mounted) { Navigator.pop(ctx); _showSnackBar(context, '已移出分类'); }
                  },
                  backgroundColor: theme.colorScheme.surface,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                ),
                ...categories.map((category) {
                  final isCurrent = note.category == category;
                  return FilterChip(
                    label: Text(category),
                    selected: isCurrent,
                    onSelected: (_) async {
                      await provider.updateNote(note.copyWith(category: category));
                      if (ctx.mounted) { Navigator.pop(ctx); _showSnackBar(context, '已移动到 "$category"'); }
                    },
                    checkmarkColor: theme.colorScheme.onPrimaryContainer,
                    selectedColor: theme.colorScheme.primaryContainer,
                    backgroundColor: theme.colorScheme.surface,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ],
      ),
    );
  }

  // 内部辅助方法：确认删除
  Future<bool?> _confirmDelete(BuildContext context, Note note) async {
    final theme = Theme.of(context);
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: theme.colorScheme.errorContainer.withOpacity(0.3), shape: BoxShape.circle),
          child: Icon(Icons.delete_rounded, size: 28, color: theme.colorScheme.error),
        ),
        title: const Text('确认删除?'),
        content: const Text('笔记将被移至回收站，\n你可以在那里随时还原。', textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: theme.colorScheme.onError),
            child: const Text('移除'),
          ),
        ],
      ),
    );
  }

  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        width: 400, // 电脑端限制宽度，居中显示
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// 🟢 统一的操作按钮样式
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