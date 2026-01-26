import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/todo.dart';

// 使用底部弹窗代替 Dialog，体验更好
Future<Todo?> showCreateTodoDialog({
  required BuildContext context,
  Todo? existingTodo,
}) {
  return showModalBottomSheet<Todo>(
    context: context,
    isScrollControlled: true, // 允许弹窗全屏或自适应高度
    backgroundColor: Theme.of(context).colorScheme.surface,
    showDragHandle: true, // 显示顶部的拖动条
    useSafeArea: true,
    builder: (context) => CreateTodoSheet(existingTodo: existingTodo),
  );
}

class CreateTodoSheet extends StatefulWidget {
  final Todo? existingTodo;

  const CreateTodoSheet({super.key, this.existingTodo});

  @override
  State<CreateTodoSheet> createState() => _CreateTodoSheetState();
}

class _CreateTodoSheetState extends State<CreateTodoSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    final todo = widget.existingTodo;
    _titleController = TextEditingController(text: todo?.title ?? '');
    _descController = TextEditingController(text: todo?.description ?? '');

    if (todo?.dueDate != null) {
      _selectedDate = todo!.dueDate;
      _selectedTime = TimeOfDay.fromDateTime(todo.dueDate!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // 选择日期
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );

    if (pickedDate != null) {
      setState(() {
        // 如果之前有选具体时间，保留时间部分；否则默认设为当前时间或0点
        final oldTime = _selectedTime ?? TimeOfDay.now();
        _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            oldTime.hour,
            oldTime.minute
        );
        // 如果还没选过时间，自动把时间也选上，方便用户
        _selectedTime ??= oldTime;
      });
    }
  }

  // 选择时间 (精确到分钟)
  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? now,
      builder: (BuildContext context, Widget? child) {
        // 使用 24小时制，根据系统设定调整
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        _selectedTime = pickedTime;
        // 如果还没选日期，默认设为今天
        final baseDate = _selectedDate ?? DateTime.now();
        _selectedDate = DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
      });
    }
  }

  void _clearReminder() {
    setState(() {
      _selectedDate = null;
      _selectedTime = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 动态获取键盘高度，防止输入框被遮挡
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题输入 (大字体，无边框，类似待办清单的自然输入)
          TextField(
            controller: _titleController,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: '准备做什么？',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            autofocus: widget.existingTodo == null, // 新建时自动聚焦
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 12),

          // 描述输入 (小字体)
          TextField(
            controller: _descController,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            decoration: InputDecoration(
              hintText: '添加描述...',
              hintStyle: TextStyle(color: theme.colorScheme.outline),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              icon: Icon(Icons.notes_rounded, size: 20, color: theme.colorScheme.outline),
            ),
            minLines: 1,
            maxLines: 5,
          ),

          const SizedBox(height: 24),

          // 提醒时间选择区 (Chip 风格)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 日期按钮
                ActionChip(
                  avatar: Icon(Icons.calendar_today_rounded, size: 16, color: _selectedDate == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary),
                  label: Text(
                    _selectedDate == null
                        ? '日期'
                        : DateFormat('MM月dd日').format(_selectedDate!),
                    style: TextStyle(
                        color: _selectedDate == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary,
                        fontWeight: _selectedDate == null ? FontWeight.normal : FontWeight.bold
                    ),
                  ),
                  onPressed: _pickDate,
                  backgroundColor: _selectedDate == null ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.primaryContainer.withOpacity(0.3),
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                ),

                const SizedBox(width: 12),

                // 时间按钮
                ActionChip(
                  avatar: Icon(Icons.access_time_rounded, size: 16, color: _selectedTime == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary),
                  label: Text(
                    _selectedTime == null
                        ? '时间'
                        : _selectedTime!.format(context),
                    style: TextStyle(
                        color: _selectedTime == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary,
                        fontWeight: _selectedTime == null ? FontWeight.normal : FontWeight.bold
                    ),
                  ),
                  onPressed: _pickTime,
                  backgroundColor: _selectedTime == null ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.primaryContainer.withOpacity(0.3),
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                ),

                // 清除按钮 (仅当已设置时间时显示)
                if (_selectedDate != null) ...[
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    onPressed: _clearReminder,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                    ),
                  ),
                ]
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 底部保存按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: () {
                  final title = _titleController.text.trim();
                  if (title.isEmpty) return; // 标题为空不做反应

                  // 构造 DateTime 对象
                  DateTime? finalDueDate;
                  if (_selectedDate != null) {
                    final t = _selectedTime ?? const TimeOfDay(hour: 0, minute: 0); // 如果没选时间，默认0点
                    finalDueDate = DateTime(
                      _selectedDate!.year,
                      _selectedDate!.month,
                      _selectedDate!.day,
                      t.hour,
                      t.minute,
                    );
                  }

                  final result = Todo(
                    id: widget.existingTodo?.id ?? '',
                    title: title,
                    description: _descController.text.trim(),
                    dueDate: finalDueDate,
                    isCompleted: widget.existingTodo?.isCompleted ?? false,
                    createdAt: widget.existingTodo?.createdAt ?? DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

                  Navigator.pop(context, result);
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}