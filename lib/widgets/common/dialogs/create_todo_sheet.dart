import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../models/todo.dart';


class CreateTodoResult {
  final String title;
  final DateTime? dueDate;
  final List<SubTask> subTasks;
  CreateTodoResult({required this.title, this.dueDate, required this.subTasks});
}

Future<CreateTodoResult?> showCreateTodoSheet(BuildContext context, {Todo? existingTodo}) {
  return showModalBottomSheet<CreateTodoResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (ctx) => _CreateTodoContent(existingTodo: existingTodo),
  );
}

class _CreateTodoContent extends StatefulWidget {
  final Todo? existingTodo;
  const _CreateTodoContent({this.existingTodo});

  @override
  State<_CreateTodoContent> createState() => _CreateTodoContentState();
}

class _CreateTodoContentState extends State<_CreateTodoContent> {
  late TextEditingController _titleController;
  late TextEditingController _inputController;
  final FocusNode _inputFocus = FocusNode();

  DateTime? _selectedDate;
  List<SubTask> _subTasks = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingTodo?.title ?? '');
    _inputController = TextEditingController();
    _selectedDate = widget.existingTodo?.dueDate;

    if (widget.existingTodo != null && widget.existingTodo!.subTasks.isNotEmpty) {
      _subTasks = List.from(widget.existingTodo!.subTasks);
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _inputFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _onSubmitted(String value) {
    if (value.trim().isEmpty) return;

    setState(() {
      _subTasks.add(SubTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: value.trim(),
      ));
      _inputController.clear();
    });

    _inputFocus.requestFocus();
  }

  void _removeSubTask(String id) {
    setState(() => _subTasks.removeWhere((t) => t.id == id));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
      if (time != null && mounted) {
        setState(() {
          _selectedDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
        });
      }
    }
  }

  void _submit() {
    if (_inputController.text.trim().isNotEmpty) {
      _subTasks.add(SubTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _inputController.text.trim(),
      ));
    }

    // 🟢 在保存前，自动过滤掉被用户清空文本的子任务
    List<SubTask> finalSubTasks = _subTasks.where((t) => t.title.trim().isNotEmpty).toList();
    String finalTitle = _titleController.text.trim();

    if (finalTitle.isEmpty && finalSubTasks.isEmpty) {
      Navigator.pop(context);
      return;
    }

    if (finalTitle.isEmpty && finalSubTasks.length == 1) {
      finalTitle = finalSubTasks.first.title;
      finalSubTasks.clear();
    } else if (finalTitle.isEmpty) {
      finalTitle = finalSubTasks.isNotEmpty ? '待办清单' : '未命名待办';
    }

    Navigator.pop(context, CreateTodoResult(
      title: finalTitle,
      dueDate: _selectedDate,
      subTasks: finalSubTasks,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final showTitle = _subTasks.isNotEmpty || _titleController.text.isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16,
          bottom: bottomInset > 0 ? bottomInset + 16 : MediaQuery.of(context).padding.bottom + 16,
        ),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: showTitle
                      ? TextField(
                    controller: _titleController,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: "待办清单",
                      hintStyle: TextStyle(color: theme.colorScheme.outlineVariant, fontWeight: FontWeight.bold),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  )
                      : const SizedBox(width: double.infinity, height: 0),
                ),

                if (showTitle) const SizedBox(height: 12),

                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: SingleChildScrollView(
                    child: Column(
                      children: _subTasks.map((task) => Padding(
                        key: ValueKey(task.id),
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Icon(
                                task.isCompleted ? Icons.check_box_rounded : Icons.crop_square_rounded,
                                size: 22,
                                color: task.isCompleted ? theme.colorScheme.primary : theme.colorScheme.outline
                            ),
                            const SizedBox(width: 12),
                            // 🟢 核心修改：用 TextFormField 替换 Text，实现直接点击修改
                            Expanded(
                              child: TextFormField(
                                initialValue: task.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: task.isCompleted ? theme.colorScheme.outline : theme.colorScheme.onSurface,
                                  decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (val) {
                                  // 静默更新列表中的对应项，不触发 setState 避免闪烁
                                  final index = _subTasks.indexWhere((t) => t.id == task.id);
                                  if (index != -1) {
                                    _subTasks[index] = _subTasks[index].copyWith(title: val);
                                  }
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              color: theme.colorScheme.outlineVariant,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _removeSubTask(task.id),
                            )
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                ),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.crop_square_rounded, size: 22, color: theme.colorScheme.primary.withOpacity(0.5)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        focusNode: _inputFocus,
                        textInputAction: TextInputAction.done,
                        onSubmitted: _onSubmitted,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "准备做什么 (回车连续添加)...",
                          hintStyle: TextStyle(color: theme.colorScheme.outline.withOpacity(0.6), fontSize: 16),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ActionChip(
                      avatar: Icon(Icons.alarm_add_rounded, size: 18, color: _selectedDate != null ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                      label: Text(
                        _selectedDate == null ? "设置提醒" : DateFormat('MM-dd HH:mm').format(_selectedDate!),
                        style: TextStyle(color: _selectedDate != null ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                      ),
                      backgroundColor: _selectedDate != null ? theme.colorScheme.primaryContainer.withOpacity(0.5) : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                      onPressed: _pickDate,
                    ),
                    FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('完成', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}