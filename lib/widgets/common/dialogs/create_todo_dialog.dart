import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../models/todo.dart';
import 'create_todo_sheet.dart'; // 引入手机端的 Sheet 备用降级

// 🌟 统一的标准返回数据结构
class CreateTodoResult {
  final String title;
  final DateTime? dueDate;
  final List<SubTask> subTasks;
  CreateTodoResult({required this.title, this.dueDate, required this.subTasks});
}

// 🟢 架构师级终极入口：智能双端路由
Future<CreateTodoResult?> showAppCreateTodoDialog(BuildContext context, {Todo? existingTodo}) {
  final isDesktop = MediaQuery.of(context).size.width >= 600;

  if (isDesktop) {
    // 💻 电脑端：呼出高级居中悬浮弹窗
    return showDialog<CreateTodoResult>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4), // 柔和的遮罩
      builder: (context) => _DesktopTodoDialog(existingTodo: existingTodo),
    );
  } else {
    // 📱 手机端：降级呼出你之前写好的精致底部抽屉
    return showModalBottomSheet<CreateTodoResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => showCreateTodoSheet(context, existingTodo: existingTodo) as Widget,
    );
  }
}

// =========================================================================
// 💻 桌面端专属高级弹窗实现
// =========================================================================
class _DesktopTodoDialog extends StatefulWidget {
  final Todo? existingTodo;
  const _DesktopTodoDialog({this.existingTodo});

  @override
  State<_DesktopTodoDialog> createState() => _DesktopTodoDialogState();
}

class _DesktopTodoDialogState extends State<_DesktopTodoDialog> {
  late TextEditingController _titleController;
  late TextEditingController _inputController;
  final FocusNode _titleFocus = FocusNode();
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

    // 弹窗出现时，默认让主标题获取焦点（如果是新建的话）
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        if (widget.existingTodo == null) {
          _titleFocus.requestFocus();
        } else {
          _inputFocus.requestFocus();
        }
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _inputController.dispose();
    _titleFocus.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // 响应回车添加子任务
  void _onSubTaskSubmitted(String value) {
    if (value.trim().isEmpty) return;

    setState(() {
      _subTasks.add(SubTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: value.trim(),
      ));
      _inputController.clear();
    });

    _inputFocus.requestFocus(); // 焦点吸附，支持连续敲击回车录入
  }

  void _removeSubTask(String id) {
    setState(() => _subTasks.removeWhere((t) => t.id == id));
  }

  // 桌面端优雅的日期时间选择器
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: _selectedDate != null
            ? TimeOfDay.fromDateTime(_selectedDate!)
            : const TimeOfDay(hour: 9, minute: 0),
      );
      if (pickedTime != null && mounted) {
        setState(() {
          _selectedDate = DateTime(
              pickedDate.year, pickedDate.month, pickedDate.day,
              pickedTime.hour, pickedTime.minute
          );
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

    // 过滤空任务
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 24,
      backgroundColor: theme.colorScheme.surface,
      child: Container(
        width: 500, // 🌟 黄金比例宽度，拒绝无限拉伸
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85, // 防止超出屏幕高度
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 紧凑型包裹
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 头部标题栏 ---
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingTodo == null ? '新建待办' : '编辑待办',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: theme.colorScheme.onSurfaceVariant,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // --- 内容滚动区 ---
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 主标题输入
                    TextField(
                      controller: _titleController,
                      focusNode: _titleFocus,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: "准备做什么？",
                        hintStyle: TextStyle(color: theme.colorScheme.outlineVariant),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onSubmitted: (_) => _inputFocus.requestFocus(), // 回车跳到子任务
                    ),

                    const SizedBox(height: 16),
                    Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3), height: 1),
                    const SizedBox(height: 16),

                    // 2. 子任务列表 (原汁原味移植)
                    if (_subTasks.isNotEmpty)
                      Column(
                        children: _subTasks.map((task) => Padding(
                          key: ValueKey(task.id),
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              Icon(
                                  task.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  size: 20,
                                  color: task.isCompleted ? theme.colorScheme.primary : theme.colorScheme.outline
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  initialValue: task.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: task.isCompleted ? theme.colorScheme.outline : theme.colorScheme.onSurface,
                                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (val) {
                                    final index = _subTasks.indexWhere((t) => t.id == task.id);
                                    if (index != -1) {
                                      _subTasks[index] = _subTasks[index].copyWith(title: val);
                                    }
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                color: theme.colorScheme.outlineVariant,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _removeSubTask(task.id),
                              )
                            ],
                          ),
                        )).toList(),
                      ),

                    // 3. 连续添加栏
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.add_task_rounded, size: 20, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            focusNode: _inputFocus,
                            textInputAction: TextInputAction.done,
                            onSubmitted: _onSubTaskSubmitted,
                            style: const TextStyle(fontSize: 15),
                            decoration: InputDecoration(
                              hintText: "添加子待办 (敲击回车连续添加)...",
                              hintStyle: TextStyle(color: theme.colorScheme.outline.withValues(alpha: 0.6), fontSize: 15),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // --- 底部动作栏 ---
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ActionChip(
                    avatar: Icon(Icons.notifications_active_rounded, size: 16, color: _selectedDate != null ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                    label: Text(
                      _selectedDate == null ? "设置提醒时间" : DateFormat('MM-dd HH:mm').format(_selectedDate!),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _selectedDate != null ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant
                      ),
                    ),
                    backgroundColor: _selectedDate != null
                        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onPressed: _pickDate,
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        child: const Text('保存', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}