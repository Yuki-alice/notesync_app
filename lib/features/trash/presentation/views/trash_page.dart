import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/todos_provider.dart';

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
          backgroundColor: theme.colorScheme.surface,
          bottom: TabBar(
            tabs: const [
              Tab(text: '笔记'),
              Tab(text: '待办'),
            ],
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: theme.colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.tab,
          ),
          actions: [
            // 清空按钮
            TextButton.icon(
              onPressed: () => _confirmEmptyTrash(context),
              icon: Icon(Icons.delete_sweep_rounded, color: theme.colorScheme.error),
              label: Text('清空', style: TextStyle(color: theme.colorScheme.error)),
            ),
            const SizedBox(width: 8),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空回收站?'),
        content: const Text('所有项目将被永久删除且无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<NotesProvider>(context, listen: false).emptyTrash();
              Provider.of<TodosProvider>(context, listen: false).emptyTrash();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('回收站已清空')));
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

// 笔记回收列表
class _NotesTrashList extends StatelessWidget {
  const _NotesTrashList();

  @override
  Widget build(BuildContext context) {
    return Consumer<NotesProvider>(
      builder: (context, provider, _) {
        final notes = provider.trashNotes;
        if (notes.isEmpty) return const _EmptyTrashView(message: '暂无废弃笔记');

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            return _TrashItemCard(
              title: note.title.isEmpty ? '无标题' : note.title,
              subtitle: note.plainText, // 使用之前优化过的 plainText
              time: DateFormat('yyyy/MM/dd HH:mm').format(note.updatedAt),
              onRestore: () => provider.restoreNote(note.id),
              onDeleteForever: () => provider.deleteNoteForever(note.id),
            );
          },
        );
      },
    );
  }
}

// 待办回收列表
class _TodosTrashList extends StatelessWidget {
  const _TodosTrashList();

  @override
  Widget build(BuildContext context) {
    return Consumer<TodosProvider>(
      builder: (context, provider, _) {
        final todos = provider.trashTodos;
        if (todos.isEmpty) return const _EmptyTrashView(message: '暂无废弃待办');

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: todos.length,
          itemBuilder: (context, index) {
            final todo = todos[index];
            return _TrashItemCard(
              title: todo.title,
              subtitle: todo.description,
              time: todo.dueDate != null ? DateFormat('MM-dd').format(todo.dueDate!) : '',
              isTodo: true,
              onRestore: () => provider.restoreTodo(todo.id),
              onDeleteForever: () => provider.deleteTodoForever(todo.id),
            );
          },
        );
      },
    );
  }
}

// 通用回收站卡片
class _TrashItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final bool isTodo;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  const _TrashItemCard({
    required this.title,
    required this.subtitle,
    required this.time,
    this.isTodo = false,
    required this.onRestore,
    required this.onDeleteForever,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      decoration: TextDecoration.lineThrough, // 删除线效果
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                ],
              ),
            ),
            // 操作按钮区
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filledTonal(
                  onPressed: onRestore,
                  icon: const Icon(Icons.restore_rounded),
                  tooltip: '还原',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: onDeleteForever,
                  icon: const Icon(Icons.delete_forever_rounded),
                  tooltip: '彻底删除',
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.errorContainer,
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTrashView extends StatelessWidget {
  final String message;
  const _EmptyTrashView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_outline_rounded, size: 64, color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }
}