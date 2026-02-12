import 'package:flutter/material.dart';
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
  late TextEditingController _descController;

  // 避免频繁写入数据库，使用 Debounce 或在失去焦点/销毁时保存
  // 这里为了简单直观，采用失去焦点时保存
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _descFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descController = TextEditingController();

    _titleFocus.addListener(_onFocusChange);
    _descFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_titleFocus.hasFocus && !_descFocus.hasFocus) {
      _saveChanges();
    }
  }

  @override
  void dispose() {
    _titleFocus.removeListener(_onFocusChange);
    _descFocus.removeListener(_onFocusChange);
    _titleController.dispose();
    _descController.dispose();
    _titleFocus.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  // 获取当前 Todo 数据
  Todo? _getTodo(BuildContext context) {
    final provider = Provider.of<TodosProvider>(context, listen: false);
    try {
      return provider.todos.firstWhere((t) => t.id == widget.todoId);
    } catch (e) {
      return null;
    }
  }

  // 初始化数据填充 (当 todoId 变化时)
  @override
  void didUpdateWidget(covariant TodoDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.todoId != widget.todoId) {
      // 切换了待办，重新加载数据
      final todo = _getTodo(context);
      if (todo != null) {
        _titleController.text = todo.title;
        _descController.text = todo.description;
      }
    }
  }

  void _saveChanges() {
    final todo = _getTodo(context);
    if (todo == null) return;

    final newTitle = _titleController.text.trim();
    final newDesc = _descController.text.trim();

    if (newTitle != todo.title || newDesc != todo.description) {
      final updated = todo.copyWith(
        title: newTitle.isEmpty ? '无标题待办' : newTitle,
        description: newDesc,
        updatedAt: DateTime.now(),
      );
      context.read<TodosProvider>().updateTodo(updated);
    }
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
      // 保留原有时间，或者默认设为 9:00 / 0:00，这里简化处理保留原有时间或设为 00:00
      final newDate = DateTime(picked.year, picked.month, picked.day,
          todo.dueDate?.hour ?? 9, todo.dueDate?.minute ?? 0);

      context.read<TodosProvider>().updateTodo(todo.copyWith(dueDate: newDate));
      AppFeedback.light();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听数据变化以更新 UI
    final provider = context.watch<TodosProvider>();
    Todo? todo;
    try {
      todo = provider.todos.firstWhere((t) => t.id == widget.todoId);
    } catch (e) {
      // 找不到 ID (可能被删除了)，显示空状态
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

    // 只有在获得焦点时才不覆盖输入框内容，否则保持和 Model 同步
    // 这里做一个简单的处理：如果未获得焦点，则强制同步一次，确保切换任务时内容正确
    if (!_titleFocus.hasFocus) _titleController.text = todo.title;
    if (!_descFocus.hasFocus) _descController.text = todo.description;

    final theme = Theme.of(context);
    final isDone = todo.isCompleted;

    return Column(
      children: [
        // 1. 顶部工具栏
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.2))),
            color: theme.colorScheme.surface,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  AppFeedback.medium();
                  context.read<TodosProvider>().toggleTodoStatus(todo!.id);
                },
                tooltip: isDone ? "标记为未完成" : "完成任务",
                icon: Icon(
                  isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                  color: isDone ? theme.colorScheme.primary : theme.colorScheme.outline,
                ),
              ),
              const Spacer(),
              // 日期显示与选择
              TextButton.icon(
                onPressed: () => _pickDate(todo!),
                icon: Icon(Icons.calendar_today_rounded, size: 16,
                    color: todo.dueDate == null ? theme.colorScheme.outline : theme.colorScheme.primary),
                label: Text(
                  todo.dueDate == null
                      ? "设置日期"
                      : DateFormat('MM-dd HH:mm').format(todo.dueDate!),
                  style: TextStyle(
                      color: todo.dueDate == null ? theme.colorScheme.outline : theme.colorScheme.primary
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  AppFeedback.heavy();
                  context.read<TodosProvider>().deleteTodo(todo!.id);
                  widget.onClose(); // 删除后关闭详情
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

        // 2. 编辑区域
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题编辑
                TextField(
                  controller: _titleController,
                  focusNode: _titleFocus,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone ? theme.colorScheme.outline : theme.colorScheme.onSurface,
                  ),
                  decoration: const InputDecoration(
                    hintText: "准备做什么？",
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  onSubmitted: (_) => _saveChanges(), // 回车保存
                ),

                const SizedBox(height: 16),

                // 描述编辑
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _descController,
                    focusNode: _descFocus,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                    decoration: InputDecoration(
                      hintText: "添加详细描述、备注...",
                      hintStyle: TextStyle(color: theme.colorScheme.outline.withOpacity(0.7)),
                      border: InputBorder.none,
                      icon: Icon(Icons.notes_rounded, color: theme.colorScheme.outline),
                    ),
                    maxLines: null,
                    minLines: 5,
                  ),
                ),

                const SizedBox(height: 24),

                // 底部元数据
                Row(
                  children: [
                    Text(
                      "创建于 ${DateFormat('yyyy-MM-dd HH:mm').format(todo.createdAt)}",
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
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