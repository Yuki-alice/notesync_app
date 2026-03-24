import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/todo.dart';

// 🟢 核心修改：自适应入口函数
Future<Todo?> showCreateTodoDialog({
  required BuildContext context,
  Todo? existingTodo,
}) {
  final isDesktop = MediaQuery.of(context).size.width >= 600;

  if (isDesktop) {
    // 💻 桌面端：显示居中弹窗 (Dialog)
    return showDialog<Todo>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 500, // 限制弹窗宽度
          child: CreateTodoSheet(existingTodo: existingTodo, isDialog: true),
        ),
      ),
    );
  } else {
    // 📱 移动端：显示底部抽屉 (Bottom Sheet)
    return showModalBottomSheet<Todo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => CreateTodoSheet(existingTodo: existingTodo, isDialog: false),
    );
  }
}

class CreateTodoSheet extends StatefulWidget {
  final Todo? existingTodo;
  final bool isDialog; // [新增] 标记是否为弹窗模式

  const CreateTodoSheet({super.key, this.existingTodo, this.isDialog = false});

  @override
  State<CreateTodoSheet> createState() => _CreateTodoSheetState();
}

class _CreateTodoSheetState extends State<CreateTodoSheet> {
  // ... (状态变量保持不变: _titleController, _descController, _selectedDate 等)
  late TextEditingController _titleController;
  late TextEditingController _descController;
  final FocusNode _titleFocus = FocusNode();

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

    if (widget.existingTodo == null) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _titleFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  // ... (保持 _pickDate, _pickTime, _submit 逻辑不变，直接复制之前的代码即可)
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        final oldTime = _selectedTime ?? const TimeOfDay(hour: 9, minute: 0);
        _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            oldTime.hour,
            oldTime.minute
        );
        if (_selectedTime == null) _selectedTime = oldTime;
      });
    }
  }

  // 选择时间
  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? now,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        _selectedTime = pickedTime;
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

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    DateTime? finalDueDate;
    if (_selectedDate != null) {
      final t = _selectedTime ?? const TimeOfDay(hour: 0, minute: 0);
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    // ... (保持 dateText 逻辑不变)
    final hasDate = _selectedDate != null;
    final hasTime = _selectedTime != null;

    String dateText = '';
    if (hasDate) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);

      if (target == today) {
        dateText = '今天';
      } else if (target == today.add(const Duration(days: 1))) {
        dateText = '明天';
      } else {
        dateText = DateFormat('MM月dd日').format(_selectedDate!);
      }

      if (hasTime) {
        dateText += ' ${_selectedTime!.format(context)}';
      }
    }


    return Container(
      // 如果是 Dialog 模式，给一个白色/深色背景，否则是透明的（由 BottomSheet 控制）
      color: widget.isDialog ? theme.colorScheme.surface : null,
      padding: EdgeInsets.only(bottom: widget.isDialog ? 0 : bottomPadding + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🟢 如果是 Dialog，加一个标题栏
            if (widget.isDialog)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Text(
                  widget.existingTodo == null ? '新待办' : '编辑待办',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),

            // 1. 输入区域
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocus,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                      fontSize: 20, // 稍微调小一点字体
                    ),
                    decoration: InputDecoration(
                      hintText: '准备做什么？',
                      hintStyle: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      prefixIcon: Icon(
                          Icons.edit_rounded,
                          color: theme.colorScheme.primary
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    maxLines: 2,
                    minLines: 1,
                    textInputAction: TextInputAction.next,
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _descController,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      height: 1.5,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: '添加详细描述...',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.outline.withValues(alpha: 0.7),
                        fontSize: 16,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      prefixIcon: Icon(
                          Icons.notes_rounded,
                          color: theme.colorScheme.outline
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      isDense: true,
                    ),
                    minLines: 3, // 默认显示多一点行数
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                  ),
                ],
              ),
            ),

            // 2. 底部工具栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.1))),
                color: theme.colorScheme.surface,
              ),
              child: Row(
                children: [
                  _buildToolbarButton(
                    context,
                    icon: Icons.calendar_today_rounded,
                    label: hasDate && !hasTime ? dateText : '日期',
                    isActive: hasDate,
                    onTap: _pickDate,
                  ),

                  const SizedBox(width: 8),

                  _buildToolbarButton(
                    context,
                    icon: Icons.access_time_rounded,
                    label: hasTime ? dateText : '时间',
                    isActive: hasTime,
                    onTap: _pickTime,
                  ),

                  const Spacer(),

                  if (hasDate)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedDate = null;
                          _selectedTime = null;
                        });
                      },
                      icon: const Icon(Icons.notifications_off_outlined),
                      tooltip: '清除提醒',
                      visualDensity: VisualDensity.compact,
                      color: theme.colorScheme.outline,
                    ),

                  const SizedBox(width: 8),

                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('保存', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... (保留 _buildToolbarButton 辅助方法)
  Widget _buildToolbarButton(BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    required String label,
    bool isActive = false,
  }) {
    final theme = Theme.of(context);

    final bgColor = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHigh;

    final fgColor = isActive
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: fgColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: fgColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}