import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/todos_provider.dart';
// 引入两个 Model 以便在卡片中使用其方法
import '../../../../models/note.dart';
import '../../../../models/todo.dart';

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
          surfaceTintColor: Colors.transparent, // 移除滚动时的变色
          bottom: TabBar(
            tabs: const [
              Tab(text: '笔记', icon: Icon(Icons.description_outlined)),
              Tab(text: '待办', icon: Icon(Icons.check_circle_outlined)),
            ],
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: theme.colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent, // 移除 TabBar 下划线
          ),
          actions: [
            // 清空按钮：使用 Tonal 风格
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton.tonalIcon(
                onPressed: () => _confirmEmptyTrash(context),
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

  // 🎨 MD3 风格：清空确认弹窗
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

// 笔记回收列表
class _NotesTrashList extends StatelessWidget {
  const _NotesTrashList();

  @override
  Widget build(BuildContext context) {
    return Consumer<NotesProvider>(
      builder: (context, provider, _) {
        final notes = provider.trashNotes;
        if (notes.isEmpty) return const _EmptyTrashView(message: '没有废弃的笔记');

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: notes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final note = notes[index];
            // 使用 Note 模型自带的方法获取格式化时间
            return _TrashItemCard(
              item: note,
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
        if (todos.isEmpty) return const _EmptyTrashView(message: '没有废弃的待办');

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: todos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final todo = todos[index];
            return _TrashItemCard(
              item: todo,
              onRestore: () => provider.restoreTodo(todo.id),
              onDeleteForever: () => provider.deleteTodoForever(todo.id),
            );
          },
        );
      },
    );
  }
}

// 🎨 MD3 风格：通用回收站卡片
class _TrashItemCard extends StatelessWidget {
  final dynamic item; // 接收 Note 或 Todo 对象
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
    // 使用 Model 自带的时间格式化，或手动格式化待办时间
    final timeStr = isNote
        ? (item as Note).formattedUpdatedAt
        : (item as Todo).dueDate != null
        ? DateFormat('yyyy/MM/dd').format((item as Todo).dueDate!)
        : '';

    return Card(
      elevation: 0,
      // 使用次要容器色，表示“非活跃”状态
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        // 加一个浅色边框
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 左侧图标：笔记或待办
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
            // 中间内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? (isNote ? '无标题笔记' : '无标题待办') : title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      decoration: TextDecoration.lineThrough, // 删除线
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
                          '删除于 $timeStr', // 提示删除时间
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    )
                  ]
                ],
              ),
            ),
            // 右侧操作按钮
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 还原按钮
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
                // 永久删除按钮
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

  // 🎨 MD3 风格：单个项目永久删除确认
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
                        onDeleteForever(); // 执行传入的删除回调
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

class _EmptyTrashView extends StatelessWidget {
  final String message;
  const _EmptyTrashView({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_delete_outlined, size: 64, color: theme.colorScheme.outline.withOpacity(0.5)),
          ),
          const SizedBox(height: 24),
          Text(message, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 8),
          Text('回收站的项目会自动保留一段时间', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outlineVariant)),
        ],
      ),
    );
  }
}