import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../models/todo.dart';
import '../../../../widgets/common/search_highlight_text.dart';
import '../../../../core/providers/todos_provider.dart';

class TodoItem extends StatefulWidget {
  final Todo todo;
  final String searchQuery;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final bool isReorderable;
  final int? index;
  final bool isSelected;

  const TodoItem({
    super.key,
    required this.todo,
    required this.searchQuery,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    this.isReorderable = true,
    this.index,
    this.isSelected = false,
  });

  @override
  State<TodoItem> createState() => _TodoItemState();
}

class _TodoItemState extends State<TodoItem>with AutomaticKeepAliveClientMixin {
  bool _isHovering = false;
  bool? _localIsDone;
  bool _isExiting = false;

  // 🟢 核心修复 1：静态内存池，把展开状态刻在内存里，就算列表刷新也绝对不丢！
  static final Map<String, bool> _expandedStates = {};
  late bool _isExpanded;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // 初始化时，去内存池里找这个 ID 的状态，找不到默认展开 (true)
    _isExpanded = _expandedStates[widget.todo.id] ?? true;
  }

  void _handleAction(bool isDelete) {
    if (_isExiting) return;

    bool targetState = false;

    if (isDelete) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
      targetState = !(_localIsDone ?? widget.todo.isCompleted);
      setState(() => _localIsDone = targetState);
    }

    Future.delayed(Duration(milliseconds: isDelete ? 0 : 350), () {
      if (!mounted) return;
      setState(() => _isExiting = true);

      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;

        if (isDelete) {
          widget.onDelete();
        } else {
          final updatedSubTasks = widget.todo.subTasks.map((t) =>
              t.copyWith(isCompleted: targetState)
          ).toList();

          context.read<TodosProvider>().updateTodo(widget.todo.copyWith(
            isCompleted: targetState,
            subTasks: updatedSubTasks,
            updatedAt: DateTime.now(),
          ));
        }

        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) setState(() { _localIsDone = null; _isExiting = false; });
        });
      });
    });
  }

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
    final isAllDay = date.hour == 23 && date.minute == 59;
    final timeStr = isAllDay ? '全天' : DateFormat('HH:mm').format(date);

    if (status == _DateStatus.today) return "今天 $timeStr";
    if (status == _DateStatus.overdue) return "已过期 ${DateFormat('MM-dd').format(date)}";

    return "${DateFormat('MM-dd').format(date)} $timeStr";
  }

  Color _getDateColor(BuildContext context, _DateStatus status, bool isDone) {
    final scheme = Theme.of(context).colorScheme;
    if (isDone) return scheme.outline.withValues(alpha: 0.5);
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
      case _DateStatus.overdue: return scheme.errorContainer.withValues(alpha: 0.3);
      case _DateStatus.today: return scheme.primaryContainer.withValues(alpha: 0.3);
      case _DateStatus.future: return scheme.surfaceContainerHighest.withValues(alpha: 0.3);
      case _DateStatus.none: return Colors.transparent;
    }
  }

  Widget _buildCheckbox({required ThemeData theme, required bool isDone, required bool isError, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 22, height: 22,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: isDone ? theme.colorScheme.primary : Colors.transparent,
          border: Border.all(
            color: isDone
                ? theme.colorScheme.primary
                : (isError ? theme.colorScheme.error.withValues(alpha: 0.7) : theme.colorScheme.outline.withValues(alpha: 0.6)),
            width: isDone ? 0 : 2,
          ),
        ),
        child: AnimatedScale(
          scale: isDone ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.elasticOut,
          child: Icon(Icons.check, size: 16, color: theme.colorScheme.onPrimary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDone = _localIsDone ?? widget.todo.isCompleted;
    final dateStatus = _getDateStatus(widget.todo.dueDate);
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final isSelected = widget.isSelected;

    Widget cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : (isDone ? Colors.transparent : theme.colorScheme.surfaceContainerLowest),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isSelected || isDone || (isDesktop && !_isHovering) ? [] : [
          BoxShadow(color: theme.shadowColor.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : (isDesktop && _isHovering
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : (isDone ? theme.colorScheme.outlineVariant.withValues(alpha: 0.15) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onTap,
          onHover: (hovering) => setState(() => _isHovering = hovering),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildCheckbox(
                      theme: theme,
                      isDone: isDone,
                      isError: dateStatus == _DateStatus.overdue,
                      onTap: () => _handleAction(false),
                    ),
                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 300),
                                  style: theme.textTheme.titleMedium!.copyWith(
                                    decoration: isDone ? TextDecoration.lineThrough : null,
                                    decorationColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    decorationThickness: 2.0,
                                    color: isDone ? theme.colorScheme.outline : theme.colorScheme.onSurface,
                                    fontWeight: isDone ? FontWeight.normal : FontWeight.w600,
                                  ),
                                  child: SearchHighlightText(
                                    widget.todo.title, query: widget.searchQuery,
                                    style: theme.textTheme.titleMedium!.copyWith(
                                      decoration: isDone ? TextDecoration.lineThrough : null,
                                      decorationColor: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                      decorationThickness: 2.0,
                                      color: isDone ? theme.colorScheme.outline : theme.colorScheme.onSurface,
                                      fontWeight: isDone ? FontWeight.normal : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              if (widget.todo.subTasks.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text(
                                    '${widget.todo.subTasks.where((t) => t.isCompleted).length} / ${widget.todo.subTasks.length}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.outline,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _isExpanded = !_isExpanded;
                                      // 🟢 核心修复 2：每次点击折叠/展开，都将其记录在静态内存池中
                                      _expandedStates[widget.todo.id] = _isExpanded;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: AnimatedRotation(
                                      turns: _isExpanded ? 0.5 : 0.0,
                                      duration: const Duration(milliseconds: 200),
                                      child: Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.outlineVariant),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          if (widget.todo.dueDate != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
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
                                    Flexible(
                                      child: Text(
                                        _formatDateText(widget.todo.dueDate!),
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: _getDateColor(context, dateStatus, isDone),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                          decoration: isDone ? TextDecoration.lineThrough : null,
                                          decorationColor: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (isDesktop) ...[
                      AnimatedOpacity(
                        opacity: _isHovering || isSelected ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20), onPressed: widget.onTap, tooltip: '编辑',
                              style: IconButton.styleFrom(shape: const CircleBorder(), foregroundColor: theme.colorScheme.onSurfaceVariant, hoverColor: theme.colorScheme.surfaceContainerHigh),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20), onPressed: () => _handleAction(true), tooltip: '删除',
                              style: IconButton.styleFrom(shape: const CircleBorder(), foregroundColor: theme.colorScheme.error, hoverColor: theme.colorScheme.errorContainer.withValues(alpha: 0.3)),
                            ),
                          ],
                        ),
                      ),
                      if (widget.isReorderable && !isDone && widget.index != null)
                        ReorderableDragStartListener(index: widget.index!, child: MouseRegion(cursor: SystemMouseCursors.grab, child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.drag_indicator_rounded, color: theme.colorScheme.outlineVariant, size: 20)))),
                    ] else if (widget.isReorderable && !isDone && widget.index != null)
                      ReorderableDragStartListener(index: widget.index!, child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.drag_handle_rounded, color: theme.colorScheme.outlineVariant, size: 20))),
                  ],
                ),

                if (widget.todo.subTasks.isNotEmpty)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    child: _isExpanded
                        ? Padding(
                      padding: const EdgeInsets.only(top: 12.0, left: 38.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.todo.subTasks.map((subTask) {
                          final subIsDone = _localIsDone ?? subTask.isCompleted;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _buildCheckbox(
                                  theme: theme,
                                  isDone: subIsDone,
                                  isError: false,
                                  onTap: isDone ? () {} : () {
                                    HapticFeedback.lightImpact();
                                    final updatedSubTasks = widget.todo.subTasks.map((t) =>
                                    t.id == subTask.id ? t.copyWith(isCompleted: !t.isCompleted) : t
                                    ).toList();
                                    context.read<TodosProvider>().updateTodo(
                                        widget.todo.copyWith(subTasks: updatedSubTasks, updatedAt: DateTime.now())
                                    );
                                  },
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 300),
                                    style: theme.textTheme.bodyMedium!.copyWith(
                                      color: subIsDone ? theme.colorScheme.outline : theme.colorScheme.onSurfaceVariant,
                                      decoration: subIsDone ? TextDecoration.lineThrough : null,
                                      decorationColor: theme.colorScheme.outline,
                                    ),
                                    child: Text(subTask.title),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    )
                        : const SizedBox(width: double.infinity, height: 0),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    Widget finalCard = isDesktop
        ? Padding(padding: const EdgeInsets.only(bottom: 8), child: cardContent)
        : Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(widget.todo.id),
        endActionPane: ActionPane(
          motion: const ScrollMotion(), extentRatio: 0.22,
          children: [
            CustomSlidableAction(
              onPressed: (_) => _handleAction(true), backgroundColor: Colors.transparent, foregroundColor: theme.colorScheme.error, autoClose: true,
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: theme.colorScheme.errorContainer.withValues(alpha: 0.8), shape: BoxShape.circle),
                child: Center(child: Icon(Icons.delete_rounded, size: 22, color: theme.colorScheme.error)),
              ),
            ),
          ],
        ),
        child: cardContent,
      ),
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _isExiting ? 0.0 : 1.0,
        child: _isExiting ? const SizedBox(width: double.infinity, height: 0) : finalCard,
      ),
    );
  }
}

enum _DateStatus { none, future, today, overdue }