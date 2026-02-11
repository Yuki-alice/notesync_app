import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🟢 引入触感反馈
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/todos_provider.dart';
import '../../../../models/note.dart';
import '../../../../models/todo.dart';
// 🟢 引入我们刚刚创建的通用空状态组件
// (请确保你已经按照上一条回答创建了 lib/widgets/common/app_empty_state.dart)
import '../../../../widgets/common/app_empty_state.dart';

class TrashPage extends StatelessWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: const Text('回收站', style: TextStyle(fontWeight: FontWeight.w600)),
          centerTitle: true,
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          bottom: TabBar(
            tabs: const [
              Tab(text: '笔记', icon: Icon(Icons.description_outlined)),
              Tab(text: '待办', icon: Icon(Icons.check_circle_outlined)),
            ],
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: theme.colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            splashBorderRadius: BorderRadius.circular(16),
            // 🟢 Tab 切换时增加轻微触感
            onTap: (_) => HapticFeedback.selectionClick(),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton.tonalIcon(
                onPressed: () {
                  // 🟢 点击清空按钮时给予反馈
                  HapticFeedback.lightImpact();
                  _confirmEmptyTrash(context);
                },
                icon: Icon(Icons.delete_sweep_rounded, color: theme.colorScheme.error),
                label: Text('清空', style: TextStyle(color: theme.colorScheme.error)),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.errorContainer.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            _NotesTrashList(),
            _TodosTrashList(),
          ],
        ),
      ),
    );
  }

  void _confirmEmptyTrash(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: theme.colorScheme.errorContainer.withOpacity(0.3), shape: BoxShape.circle),
          child: Icon(Icons.delete_forever_rounded, size: 32, color: theme.colorScheme.error),
        ),
        title: Text('清空回收站?', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface), textAlign: TextAlign.center),
        content: Text('所有项目将被永久删除，无法恢复。\n确定要继续吗？', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          Row(
            children: [
              Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onSurface, padding: const EdgeInsets.symmetric(vertical: 12)), child: const Text('取消'))),
              const SizedBox(width: 12),
              Expanded(
                  child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        // 🟢 执行破坏性操作时给予较强反馈
                        HapticFeedback.mediumImpact();

                        Provider.of<NotesProvider>(context, listen: false).emptyTrash();
                        Provider.of<TodosProvider>(context, listen: false).emptyTrash();

                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: const Text('回收站已清空'),
                                behavior: SnackBarBehavior.floating,
                                width: 200,
                                shape: const StadiumBorder(),
                                backgroundColor: theme.colorScheme.inverseSurface
                            )
                        );
                      },
                      style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: theme.colorScheme.onError, padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0),
                      child: const Text('全部清空')
                  )
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 🟢 笔记回收列表 (带动画 + 新空状态)
class _NotesTrashList extends StatelessWidget {
  const _NotesTrashList();

  @override
  Widget build(BuildContext context) {
    return Consumer<NotesProvider>(
      builder: (context, provider, _) {
        final notes = provider.trashNotes;
        if (notes.isEmpty) {
          // 🟢 使用统一的空状态组件替换原来的 _EmptyTrashView
          return const AppEmptyState(
            message: '没有废弃的笔记',
            subMessage: '删除的笔记会在这里保留一段时间',
            icon: Icons.note_alt_outlined,
          );
        }

        return AnimationLimiter(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final note = notes[index];
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: _TrashItemCard(
                      item: note,
                      onRestore: () {
                        // 🟢 还原操作反馈
                        HapticFeedback.lightImpact();
                        provider.restoreNote(note.id);
                      },
                      onDeleteForever: () => provider.deleteNoteForever(note.id),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// 🟢 待办回收列表 (带动画 + 新空状态)
class _TodosTrashList extends StatelessWidget {
  const _TodosTrashList();

  @override
  Widget build(BuildContext context) {
    return Consumer<TodosProvider>(
      builder: (context, provider, _) {
        final todos = provider.trashTodos;
        if (todos.isEmpty) {
          // 🟢 使用统一的空状态组件
          return const AppEmptyState(
            message: '没有废弃的待办',
            subMessage: '完成或删除的任务可能出现在这里',
            icon: Icons.task_alt_outlined,
          );
        }

        return AnimationLimiter(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: todos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final todo = todos[index];
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: _TrashItemCard(
                      item: todo,
                      onRestore: () {
                        // 🟢 还原操作反馈
                        HapticFeedback.lightImpact();
                        provider.restoreTodo(todo.id);
                      },
                      onDeleteForever: () => provider.deleteTodoForever(todo.id),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _TrashItemCard extends StatelessWidget {
  final dynamic item;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  const _TrashItemCard({
    required this.item,
    required this.onRestore,
    required this.onDeleteForever,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNote = item is Note;
    final title = isNote ? (item as Note).title : (item as Todo).title;
    final subtitle = isNote ? (item as Note).plainText : (item as Todo).description;

    final timeStr = isNote
        ? (item as Note).formattedUpdatedAt
        : (item as Todo).dueDate != null
        ? DateFormat('yyyy/MM/dd').format((item as Todo).dueDate!)
        : '';

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNote ? Icons.description_outlined : Icons.check_circle_outlined,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? (isNote ? '无标题笔记' : '无标题待办') : title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 12, color: theme.colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          '删除于 $timeStr',
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    )
                  ]
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filledTonal(
                  onPressed: onRestore,
                  icon: const Icon(Icons.restore_from_trash_rounded),
                  tooltip: '还原',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    foregroundColor: theme.colorScheme.onSecondaryContainer,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _confirmDeleteForever(context),
                  icon: const Icon(Icons.delete_forever_rounded),
                  tooltip: '彻底删除',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.errorContainer,
                    foregroundColor: theme.colorScheme.error,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteForever(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: theme.colorScheme.errorContainer.withOpacity(0.3), shape: BoxShape.circle),
          child: Icon(Icons.delete_forever_rounded, size: 32, color: theme.colorScheme.error),
        ),
        title: Text('永久删除?', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface), textAlign: TextAlign.center),
        content: Text('此项目将被永久移除且无法恢复。\n确定要继续吗？', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          Row(
            children: [
              Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onSurface, padding: const EdgeInsets.symmetric(vertical: 12)), child: const Text('取消'))),
              const SizedBox(width: 12),
              Expanded(
                  child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        // 🟢 删除反馈
                        HapticFeedback.mediumImpact();
                        onDeleteForever();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('已永久删除'), behavior: SnackBarBehavior.floating, width: 200, shape: const StadiumBorder(), backgroundColor: theme.colorScheme.inverseSurface));
                      },
                      style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: theme.colorScheme.onError, padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0),
                      child: const Text('删除')
                  )
              ),
            ],
          ),
        ],
      ),
    );
  }
}