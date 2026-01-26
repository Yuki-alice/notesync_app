import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/todos_provider.dart';
import '../../../../widgets/common/dialogs/create_todo_dialog.dart';
import '../../../../models/todo.dart';

class TodosPage extends StatelessWidget {
  const TodosPage({super.key});

  void _openTodoDialog(BuildContext context, {Todo? todo}) async {
    final result = await showCreateTodoDialog(
      context: context,
      existingTodo: todo,
    );

    if (result != null && context.mounted) {
      final provider = Provider.of<TodosProvider>(context, listen: false);
      if (todo == null) {
        await provider.addTodo(
          title: result.title,
          description: result.description,
          dueDate: result.dueDate,
        );
      } else {
        await provider.updateTodo(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('我的待办', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: theme.colorScheme.surface,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTodoDialog(context),
        label: const Text('新待办'),
        icon: const Icon(Icons.add_task_rounded),
        elevation: 4,
      ),
      body: Consumer<TodosProvider>(
        builder: (ctx, provider, _) {
          final todos = provider.todos;

          if (todos.isEmpty) {
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
                    child: Icon(Icons.checklist_rtl_rounded, size: 64, color: theme.colorScheme.primary.withOpacity(0.5)),
                  ),
                  const SizedBox(height: 24),
                  Text('暂无待办事项', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.outline)),
                  const SizedBox(height: 8),
                  Text('点击右下角按钮添加', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outlineVariant)),
                ],
              ),
            );
          }

          final incomplete = todos.where((t) => !t.isCompleted).toList();
          final completed = todos.where((t) => t.isCompleted).toList();

          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: incomplete.length,
            header: Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4, top: 8),
              child: Row(
                children: [
                  Icon(Icons.pending_actions_rounded, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '进行中  ${incomplete.length}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            footer: completed.isNotEmpty ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
                  child: Row(
                    children: [
                      Icon(Icons.task_alt_rounded, size: 18, color: theme.colorScheme.outline),
                      const SizedBox(width: 8),
                      Text(
                        '已完成  ${completed.length}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.outline,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.5), thickness: 1)),
                    ],
                  ),
                ),
                ...completed.map((todo) => _TodoCard(
                  key: ValueKey(todo.id),
                  todo: todo,
                  onTap: () => _openTodoDialog(context, todo: todo),
                  onToggle: () => provider.toggleTodoStatus(todo.id),
                  onDelete: () => provider.deleteTodo(todo.id),
                  isReorderable: false,
                )),
              ],
            ) : null,

            onReorder: (oldIndex, newIndex) {
              provider.reorderTodos(oldIndex, newIndex);
            },

            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (BuildContext context, Widget? child) {
                  final animValue = Curves.easeInOut.transform(animation.value);
                  final elevation = lerpDouble(0, 6, animValue);
                  return Material(
                    elevation: elevation ?? 0,
                    color: Colors.transparent,
                    shadowColor: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    child: child,
                  );
                },
                child: child,
              );
            },

            itemBuilder: (context, index) {
              final todo = incomplete[index];
              return _TodoCard(
                key: ValueKey(todo.id),
                todo: todo,
                onTap: () => _openTodoDialog(context, todo: todo),
                onToggle: () => provider.toggleTodoStatus(todo.id),
                onDelete: () => provider.deleteTodo(todo.id),
                isReorderable: true,
              );
            },
          );
        },
      ),
    );
  }
}

class _TodoCard extends StatelessWidget {
  final Todo todo;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final bool isReorderable;

  const _TodoCard({
    super.key,
    required this.todo,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    this.isReorderable = true,
  });

  _DateStatus _getDateStatus(DateTime? date) {
    if (date == null) return _DateStatus.none;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    if (date.isBefore(now)) return _DateStatus.overdue;
    if (target.isAtSameMomentAs(today)) return _DateStatus.today;
    return _DateStatus.future;
  }

  String _formatDateText(DateTime date) {
    final status = _getDateStatus(date);
    final timeStr = DateFormat('HH:mm').format(date);
    if (status == _DateStatus.today) return "今天 $timeStr";
    if (status == _DateStatus.overdue) return "已过期 ${DateFormat('MM-dd').format(date)}";
    return "${DateFormat('MM-dd').format(date)} $timeStr";
  }

  Color _getDateColor(BuildContext context, _DateStatus status, bool isDone) {
    final scheme = Theme.of(context).colorScheme;
    if (isDone) return scheme.outline.withOpacity(0.7);

    switch (status) {
      case _DateStatus.overdue:
        return scheme.error;
      case _DateStatus.today:
        return scheme.primary;
      case _DateStatus.future:
        return scheme.onSurfaceVariant;
      case _DateStatus.none:
        return Colors.transparent;
    }
  }

  Color _getDateBgColor(BuildContext context, _DateStatus status, bool isDone) {
    final scheme = Theme.of(context).colorScheme;
    if (isDone) return Colors.transparent;

    switch (status) {
      case _DateStatus.overdue:
        return scheme.errorContainer.withOpacity(0.3);
      case _DateStatus.today:
        return scheme.primaryContainer.withOpacity(0.4);
      case _DateStatus.future:
        return scheme.surfaceContainerHighest;
      case _DateStatus.none:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = todo.isCompleted;
    final dateStatus = _getDateStatus(todo.dueDate);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        key: ValueKey(todo.id),
        // 🔴 1. 增加比例：0.25 提供了足够宽度，让圆能撑满高度
        // 如果卡片很高，由于宽度不够，圆会被限制在宽度大小内（不会变形，只是不能填满高度）
        // 对于普通单行/双行待办，0.25 足以让圆填满高度。
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.25,
          children: [
            CustomSlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: Colors.transparent,
              foregroundColor: theme.colorScheme.onErrorContainer,
              autoClose: true,
              // 🔴 2. 圆形容器
              child: Container(
                // 极微小间距
                margin: const EdgeInsets.only(left: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  shape: BoxShape.circle, // 强制保持正圆
                ),
                // 🔴 3. 尺寸策略：尝试撑满宽高
                // 实际上因为 shape: circle，它会取 width 和 height 中的较小值作为直径
                // 并居中显示。
                width: double.infinity,
                height: double.infinity,
                child: const Icon(Icons.delete_outline_rounded, size: 28), // 图标加大
              ),
            ),
          ],
        ),

        child: Container(
          decoration: BoxDecoration(
            color: isDone
                ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.3)
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDone ? Colors.transparent : theme.colorScheme.outlineVariant.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Transform.scale(
                      scale: 1.1,
                      child: Checkbox(
                        value: isDone,
                        onChanged: (_) => onToggle(),
                        shape: const CircleBorder(),
                        activeColor: theme.colorScheme.primary,
                        side: BorderSide(
                            color: (!isDone && dateStatus == _DateStatus.overdue)
                                ? theme.colorScheme.error
                                : theme.colorScheme.outline,
                            width: 2
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            todo.title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              decorationColor: theme.colorScheme.outline,
                              color: isDone ? theme.colorScheme.outline : theme.colorScheme.onSurface,
                              fontWeight: isDone ? FontWeight.normal : FontWeight.w600,
                            ),
                          ),

                          if (todo.description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                todo.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                  decorationColor: theme.colorScheme.outline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                          if (todo.dueDate != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getDateBgColor(context, dateStatus, isDone),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                        Icons.access_time_rounded,
                                        size: 12,
                                        color: _getDateColor(context, dateStatus, isDone)
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDateText(todo.dueDate!),
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: _getDateColor(context, dateStatus, isDone),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                        decoration: isDone ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (isReorderable)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double? lerpDouble(num? a, num? b, double t) {
    if (a == null && b == null) return null;
    a ??= 0.0;
    b ??= 0.0;
    return a + (b - a) * t;
  }
}

enum _DateStatus { none, future, today, overdue }