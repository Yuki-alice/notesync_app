import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../models/todo.dart';

class CalendarCard extends StatefulWidget {
  final List<Todo> todos;
  final String? selectedTodoId;
  final DateTime focusedDay;
  final ValueChanged<DateTime> onDaySelected;

  const CalendarCard({
    super.key,
    required this.todos,
    this.selectedTodoId,
    required this.focusedDay,
    required this.onDaySelected,
  });

  @override
  State<CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<CalendarCard> {
  late DateTime _currentFocus;

  @override
  void initState() {
    super.initState();
    _currentFocus = widget.focusedDay;
  }

  @override
  void didUpdateWidget(covariant CalendarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusedDay != oldWidget.focusedDay) {
      _currentFocus = widget.focusedDay;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final monthStart = DateTime(_currentFocus.year, _currentFocus.month, 1);
    final daysInMonth = DateTime(_currentFocus.year, _currentFocus.month + 1, 0).day;
    final firstWeekday = monthStart.weekday; // 1=Mon, 7=Sun
    final leadingSpaces = firstWeekday - 1;

    // 查找选中任务的日期
    DateTime? selectedTaskDate;
    if (widget.selectedTodoId != null) {
      try {
        final todo = widget.todos.firstWhere((t) => t.id == widget.selectedTodoId);
        selectedTaskDate = todo.dueDate;
      } catch (_) {}
    }

    // 构建日期网格数据
    List<Widget> rows = [];
    List<Widget> currentWeek = [];

    // 填充空白
    for (int i = 0; i < leadingSpaces; i++) {
      currentWeek.add(const Expanded(child: SizedBox()));
    }

    // 填充日期
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentFocus.year, _currentFocus.month, day);
      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

      final isSelectedTaskDay = selectedTaskDate != null &&
          date.year == selectedTaskDate.year &&
          date.month == selectedTaskDate.month &&
          date.day == selectedTaskDate.day;

      final hasTodo = widget.todos.any((t) =>
      t.dueDate != null &&
          t.dueDate!.year == date.year &&
          t.dueDate!.month == date.month &&
          t.dueDate!.day == date.day &&
          !t.isCompleted
      );

      currentWeek.add(Expanded(
        child: InkWell(
          onTap: () {
            // 可选：点击日期筛选任务，目前暂不实现复杂逻辑
          },
          child: Container(
            height: 38, // 🟢 固定高度，防止宽屏下变高
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isSelectedTaskDay
                  ? theme.colorScheme.primary
                  : (isToday ? theme.colorScheme.primaryContainer.withOpacity(0.3) : null),
              border: isToday && !isSelectedTaskDay
                  ? Border.all(color: theme.colorScheme.primary, width: 1)
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  "$day",
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelectedTaskDay
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                    fontWeight: isToday || isSelectedTaskDay ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (hasTodo && !isSelectedTaskDay)
                  Positioned(
                    bottom: 4,
                    child: Container(
                      width: 4, height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
              ],
            ),
          ),
        ),
      ));

      if (currentWeek.length == 7) {
        rows.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: List.from(currentWeek)),
        ));
        currentWeek = [];
      }
    }

    // 补齐最后一行
    if (currentWeek.isNotEmpty) {
      while (currentWeek.length < 7) {
        currentWeek.add(const Expanded(child: SizedBox()));
      }
      rows.add(Row(children: currentWeek));
    }

    // 如果行数少于6行，补齐空行以保持高度稳定（可选，为了美观可以不补）
    // 这里我们选择自适应，少一行就更省空间

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // 高度包裹内容
        children: [
          // 头部
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child:
              Row(
                children: [
                  Icon(Icons.calendar_month_rounded, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('yyyy年 MMMM', 'zh_CN').format(_currentFocus),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _currentFocus = DateTime(_currentFocus.year, _currentFocus.month - 1)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.today_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                    tooltip: "回到今天",
                    onPressed: () => setState(() => _currentFocus = DateTime.now()),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _currentFocus = DateTime(_currentFocus.year, _currentFocus.month + 1)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 星期表头
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['一', '二', '三', '四', '五', '六', '日'].map((day) =>
                Expanded(child: Center(child: Text(day, style: TextStyle(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.bold,
                    fontSize: 12
                ))))
            ).toList(),
          ),
          const SizedBox(height: 8),

          // 日期网格 (使用 Column + Row)
          ...rows,
        ],
      ),
    );
  }
}