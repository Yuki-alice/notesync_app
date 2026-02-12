import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../../../models/todo.dart';
import '../../../../widgets/common/search_highlight_text.dart';

class TodoItem extends StatefulWidget {
  final Todo todo;
  final String searchQuery;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final bool isReorderable;
  final int? index;
  final bool isSelected; // [新增] 是否选中状态

  const TodoItem({
    super.key,
    required this.todo,
    required this.searchQuery,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    this.isReorderable = true,
    this.index,
    this.isSelected = false, // [新增] 默认为 false
  });

  @override
  State<TodoItem> createState() => _TodoItemState();
}

class _TodoItemState extends State<TodoItem> {
  bool _isHovering = false;

  _DateStatus _getDateStatus(DateTime? date) {
    if (date == null) return _DateStatus.none;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    if (date.isBefore(now) && !target.isAtSameMomentAs(today)) return _DateStatus.overdue;
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
      case _DateStatus.overdue: return scheme.error;
      case _DateStatus.today: return scheme.primary;
      case _DateStatus.future: return scheme.onSurfaceVariant;
      case _DateStatus.none: return Colors.transparent;
    }
  }

  Color _getDateBgColor(BuildContext context, _DateStatus status, bool isDone) {
    final scheme = Theme.of(context).colorScheme;
    if (isDone) return Colors.transparent;
    switch (status) {
      case _DateStatus.overdue: return scheme.errorContainer.withOpacity(0.3);
      case _DateStatus.today: return scheme.primaryContainer.withOpacity(0.3);
      case _DateStatus.future: return scheme.surfaceContainerHighest.withOpacity(0.5);
      case _DateStatus.none: return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = widget.todo.isCompleted;
    final dateStatus = _getDateStatus(widget.todo.dueDate);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    // 🟢 选中态逻辑
    final isSelected = widget.isSelected;

    // 卡片内容
    Widget cardContent = Container(
      decoration: BoxDecoration(
        // 🟢 背景色：如果选中，使用带透明度的主色；否则按完成状态显示
        color: isSelected
            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
            : (isDone
            ? theme.colorScheme.surfaceContainer.withOpacity(0.5)
            : theme.colorScheme.surfaceContainerLow),

        borderRadius: BorderRadius.circular(16),

        // 阴影：选中时不显示阴影（扁平化），未选中且未悬停时显示
        boxShadow: isSelected || isDone || (isDesktop && !_isHovering)
            ? []
            : [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],

        // 🟢 边框：选中时显示主色边框
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.5)
              : (isDesktop && _isHovering
              ? theme.colorScheme.primary.withOpacity(0.3)
              : (isDone ? Colors.transparent : theme.colorScheme.outlineVariant.withOpacity(0.2))),
          width: isSelected ? 1.5 : 1, // 选中时边框稍粗
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: widget.onTap,
          onHover: (hovering) => setState(() => _isHovering = hovering),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                // 复选框
                InkWell(
                  onTap: widget.onToggle,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone ? theme.colorScheme.primary : Colors.transparent,
                      border: Border.all(
                        color: isDone
                            ? theme.colorScheme.primary
                            : (dateStatus == _DateStatus.overdue ? theme.colorScheme.error : theme.colorScheme.outline),
                        width: 2,
                      ),
                    ),
                    child: isDone
                        ? Icon(Icons.check, size: 16, color: theme.colorScheme.onPrimary)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),

                // 文本内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: theme.textTheme.titleMedium!.copyWith(
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          decorationColor: theme.colorScheme.outline,
                          color: isDone ? theme.colorScheme.outline : theme.colorScheme.onSurface,
                          fontWeight: isDone ? FontWeight.normal : FontWeight.w600,
                        ),
                        child: SearchHighlightText(
                          widget.todo.title,
                          query: widget.searchQuery,
                          style: theme.textTheme.titleMedium!.copyWith(
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            decorationColor: theme.colorScheme.outline,
                            color: isDone ? theme.colorScheme.outline : theme.colorScheme.onSurface,
                            fontWeight: isDone ? FontWeight.normal : FontWeight.w600,
                          ),
                        ),
                      ),

                      // 描述
                      if (widget.todo.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: SearchHighlightText(
                            widget.todo.description,
                            query: widget.searchQuery,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDone ? theme.colorScheme.outline.withOpacity(0.7) : theme.colorScheme.outline,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              decorationColor: theme.colorScheme.outline.withOpacity(0.5),
                            ),
                          ),
                        ),

                      // 日期
                      if (widget.todo.dueDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getDateBgColor(context, dateStatus, isDone),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 10, color: _getDateColor(context, dateStatus, isDone)),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDateText(widget.todo.dueDate!),
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

                // 桌面端悬停按钮
                if (isDesktop)
                  AnimatedOpacity(
                    opacity: _isHovering || isSelected ? 1.0 : 0.0, // 🟢 选中时也常驻显示按钮
                    duration: const Duration(milliseconds: 200),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: widget.onTap,
                          style: IconButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                            hoverColor: theme.colorScheme.surfaceContainerHigh,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20),
                          onPressed: widget.onDelete,
                          style: IconButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            hoverColor: theme.colorScheme.errorContainer.withOpacity(0.2),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (widget.isReorderable && !isDone && widget.index != null)
                  ReorderableDragStartListener(
                    index: widget.index!,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.drag_handle_rounded, color: theme.colorScheme.outlineVariant, size: 20),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    // 桌面端不包裹 Slidable，直接加 Padding
    if (isDesktop) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8), // 🟢 这里的 Padding 现在在卡片(Decorated Box)外面，所以背景色不会溢出
        child: cardContent,
      );
    }

    // 手机端圆形侧滑删除
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(widget.todo.id),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.25,
          children: [
            CustomSlidableAction(
              onPressed: (_) => widget.onDelete(),
              backgroundColor: Colors.transparent,
              foregroundColor: theme.colorScheme.error,
              autoClose: true,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ]
                ),
                child: Center(
                  child: Icon(Icons.delete_rounded, size: 24, color: theme.colorScheme.error),
                ),
              ),
            ),
          ],
        ),
        child: cardContent,
      ),
    );
  }
}

enum _DateStatus { none, future, today, overdue }