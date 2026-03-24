// 文件路径: lib/features/todos/presentation/views/todo_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/providers/todos_provider.dart';
import '../../../../models/todo.dart';
import '../../../../utils/app_feedback.dart';

class TodoDetailView extends StatefulWidget {
  final String todoId;
  final VoidCallback onClose;

  const TodoDetailView({
    super.key,
    required this.todoId,
    required this.onClose,
  });

  @override
  State<TodoDetailView> createState() => _TodoDetailViewState();
}

class _TodoDetailViewState extends State<TodoDetailView> {
  late TextEditingController _titleController;
  late TextEditingController _newSubTaskController;
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _newSubTaskFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _newSubTaskController = TextEditingController();
    _titleFocus.addListener(_onTitleFocusChange);
  }

  void _onTitleFocusChange() {
    if (!_titleFocus.hasFocus) {
      _saveTitle();
    }
  }

  @override
  void dispose() {
    _titleFocus.removeListener(_onTitleFocusChange);
    _titleController.dispose();
    _newSubTaskController.dispose();
    _titleFocus.dispose();
    _newSubTaskFocus.dispose();
    super.dispose();
  }

  Todo? _getTodo() {
    try {
      return context.read<TodosProvider>().todos.firstWhere((t) => t.id == widget.todoId);
    } catch (e) {
      return null;
    }
  }

  void _saveTitle() {
    final todo = _getTodo();
    if (todo == null) return;

    final newTitle = _titleController.text.trim();
    if (newTitle != todo.title && newTitle.isNotEmpty) {
      context.read<TodosProvider>().updateTodo(todo.copyWith(
        title: newTitle,
        updatedAt: DateTime.now(),
      ));
    }
  }

  void _addSubTask() {
    final title = _newSubTaskController.text.trim();
    if (title.isEmpty) return;

    final todo = _getTodo();
    if (todo == null) return;

    final newTask = SubTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
    );

    final updatedSubTasks = List<SubTask>.from(todo.subTasks)..add(newTask);

    context.read<TodosProvider>().updateTodo(todo.copyWith(
      subTasks: updatedSubTasks,
      updatedAt: DateTime.now(),
    ));

    _newSubTaskController.clear();
    _newSubTaskFocus.requestFocus();
  }

  void _removeSubTask(SubTask subTask) {
    final todo = _getTodo();
    if (todo == null) return;

    final updatedSubTasks = todo.subTasks.where((t) => t.id != subTask.id).toList();
    context.read<TodosProvider>().updateTodo(todo.copyWith(
      subTasks: updatedSubTasks,
      updatedAt: DateTime.now(),
    ));
  }

  Future<void> _pickDate(Todo todo) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: todo.dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null && mounted) {
      final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
      if (time != null && mounted) {
        final newDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
        context.read<TodosProvider>().updateTodo(todo.copyWith(dueDate: newDate, updatedAt: DateTime.now()));
        AppFeedback.light();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TodosProvider>();
    Todo? todo;
    try {
      todo = provider.todos.firstWhere((t) => t.id == widget.todoId);
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("该待办项不存在或已被删除"),
            const SizedBox(height: 16),
            TextButton(onPressed: widget.onClose, child: const Text("关闭详情"))
          ],
        ),
      );
    }

    if (!_titleFocus.hasFocus) _titleController.text = todo.title;

    final theme = Theme.of(context);
    final isDone = todo.isCompleted;

    return Column(
      children: [
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2))),
            color: theme.colorScheme.surface,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  AppFeedback.medium();
                  final updatedSubTasks = todo!.subTasks.map((t) => t.copyWith(isCompleted: !isDone)).toList();
                  context.read<TodosProvider>().updateTodo(todo.copyWith(
                    isCompleted: !isDone,
                    subTasks: updatedSubTasks,
                    updatedAt: DateTime.now(),
                  ));
                },
                tooltip: isDone ? "标记为未完成" : "完成任务",
                icon: Icon(
                  isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: isDone ? theme.colorScheme.primary : theme.colorScheme.outline,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _pickDate(todo!),
                icon: Icon(Icons.calendar_today_rounded, size: 16, color: todo.dueDate == null ? theme.colorScheme.outline : theme.colorScheme.primary),
                label: Text(
                  todo.dueDate == null ? "设置提醒" : DateFormat('MM-dd HH:mm').format(todo.dueDate!),
                  style: TextStyle(color: todo.dueDate == null ? theme.colorScheme.outline : theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  AppFeedback.heavy();
                  context.read<TodosProvider>().deleteTodo(todo!.id);
                  widget.onClose();
                },
                icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                tooltip: "删除",
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close_rounded),
                tooltip: "关闭详情",
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  focusNode: _titleFocus,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone ? theme.colorScheme.outline : theme.colorScheme.onSurface,
                  ),
                  decoration: const InputDecoration(
                    hintText: "待办清单",
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                  maxLines: null,
                  onSubmitted: (_) => _saveTitle(),
                ),

                const SizedBox(height: 24),

                if (todo.subTasks.isNotEmpty) ...[
                  ...todo.subTasks.map((subTask) {
                    // 🟢 核心修改：使用封装好的专属编辑组件，彻底解决键盘焦点丢失的问题
                    return _EditableSubTaskRow(
                      key: ValueKey(subTask.id),
                      subTask: subTask,
                      theme: theme,
                      onToggle: () {
                        HapticFeedback.lightImpact();
                        final updatedSubTasks = todo!.subTasks.map((t) =>
                        t.id == subTask.id ? t.copyWith(isCompleted: !t.isCompleted) : t
                        ).toList();
                        context.read<TodosProvider>().updateTodo(todo.copyWith(
                            subTasks: updatedSubTasks, updatedAt: DateTime.now()
                        ));
                      },
                      onDelete: () => _removeSubTask(subTask),
                      onTitleChanged: (newTitle) {
                        if (newTitle.isEmpty) {
                          _removeSubTask(subTask); // 文本被清空时直接自动删除
                        } else {
                          final updatedSubTasks = todo!.subTasks.map((t) =>
                          t.id == subTask.id ? t.copyWith(title: newTitle) : t
                          ).toList();
                          context.read<TodosProvider>().updateTodo(todo.copyWith(
                              subTasks: updatedSubTasks, updatedAt: DateTime.now()
                          ));
                        }
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                ],

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.crop_square_rounded, size: 22, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _newSubTaskController,
                        focusNode: _newSubTaskFocus,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addSubTask(),
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "准备做什么 (回车连续添加)...",
                          hintStyle: TextStyle(color: theme.colorScheme.outline.withValues(alpha: 0.6), fontSize: 16),
                          border: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// 🟢 专属封装：防焦点丢失的智能子待办编辑行
class _EditableSubTaskRow extends StatefulWidget {
  final SubTask subTask;
  final ThemeData theme;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final ValueChanged<String> onTitleChanged;

  const _EditableSubTaskRow({
    super.key,
    required this.subTask,
    required this.theme,
    required this.onToggle,
    required this.onDelete,
    required this.onTitleChanged,
  });

  @override
  State<_EditableSubTaskRow> createState() => _EditableSubTaskRowState();
}

class _EditableSubTaskRowState extends State<_EditableSubTaskRow> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.subTask.title);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      final newTitle = _controller.text.trim();
      if (newTitle != widget.subTask.title) {
        widget.onTitleChanged(newTitle);
      }
    }
  }

  @override
  void didUpdateWidget(covariant _EditableSubTaskRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 监听云端同步过来的标题变化（当不在输入状态时更新）
    if (widget.subTask.title != oldWidget.subTask.title && !_focusNode.hasFocus) {
      _controller.text = widget.subTask.title;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDone = widget.subTask.isCompleted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 复选框
          InkWell(
            onTap: widget.onToggle,
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: isDone ? widget.theme.colorScheme.primary : Colors.transparent,
                border: Border.all(
                  color: isDone ? widget.theme.colorScheme.primary : widget.theme.colorScheme.outline.withValues(alpha: 0.6),
                  width: isDone ? 0 : 2,
                ),
              ),
              child: AnimatedScale(
                scale: isDone ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.elasticOut,
                child: Icon(Icons.check, size: 16, color: widget.theme.colorScheme.onPrimary),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // 文本输入区
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: widget.theme.textTheme.titleMedium?.copyWith(
                color: isDone ? widget.theme.colorScheme.outline : widget.theme.colorScheme.onSurface,
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
              decoration: InputDecoration(
                hintText: "子待办内容...",
                hintStyle: TextStyle(color: widget.theme.colorScheme.outlineVariant),
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onSubmitted: (val) {
                final newTitle = val.trim();
                if (newTitle != widget.subTask.title) {
                  widget.onTitleChanged(newTitle);
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: widget.theme.colorScheme.outlineVariant,
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }
}