import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 触感反馈
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart'; // 动画库
import '../../../../core/providers/todos_provider.dart';
import '../../../../utils/app_feedback.dart';
import '../../../../widgets/common/dialogs/create_todo_dialog.dart';
import '../../../../models/todo.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../widgets/common/app_empty_state.dart'; // 通用空状态
import '../../../../widgets/common/search_highlight_text.dart'; // 搜索高亮

class TodosPage extends StatefulWidget {
  const TodosPage({super.key});

  @override
  State<TodosPage> createState() => _TodosPageState();
}

class _TodosPageState extends State<TodosPage> {
  final TextEditingController _searchController = TextEditingController();

  // 用于计算进度的辅助变量
  double _calculateProgress(int completed, int total) {
    if (total == 0) return 0.0;
    return completed / total;
  }

  void _openTodoDialog(BuildContext context, {Todo? todo}) async {
    AppFeedback.selection(); // 轻微触感
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
        AppFeedback.medium(); // 创建成功反馈
      } else {
        await provider.updateTodo(result);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Consumer<TodosProvider>(
          builder: (ctx, provider, _) {
            final todos = provider.filteredTodos;
            final incomplete = todos.where((t) => !t.isCompleted).toList();
            final completed = todos.where((t) => t.isCompleted).toList();
            final isSearching = provider.searchQuery.isNotEmpty;

            final totalCount = todos.length;
            final completedCount = completed.length;
            final progress = _calculateProgress(completedCount, totalCount);

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1. 顶部栏 (AppBar)
                SliverAppBar(
                  title: const Text('我的待办', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  centerTitle: false,
                  backgroundColor: theme.colorScheme.surface,
                  surfaceTintColor: Colors.transparent,
                  pinned: true,
                  floating: false,
                  actions: [
                    IconButton(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.trash),
                      icon: const Icon(Icons.auto_delete_outlined),
                      tooltip: '回收站',
                    ),
                    IconButton(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
                      icon: const Icon(Icons.settings_rounded),
                      tooltip: '设置',
                    ),
                    const SizedBox(width: 8),
                  ],
                ),

                // 2. 搜索栏 (本地搜索)
                SliverAppBar(
                  backgroundColor: theme.colorScheme.surface,
                  surfaceTintColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  primary: false,
                  pinned: false,
                  floating: true,
                  snap: true,
                  toolbarHeight: 70,
                  title: SearchBar(
                    controller: _searchController,
                    hintText: '搜索待办...',
                    leading: const Icon(Icons.search_rounded),
                    elevation: WidgetStateProperty.all(0),
                    backgroundColor: WidgetStateProperty.all(theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
                    // 🟢 恢复本地搜索逻辑
                    onChanged: (value) => provider.setSearchQuery(value),
                    trailing: _searchController.text.isNotEmpty
                        ? [
                      IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            provider.setSearchQuery('');
                            AppFeedback.light();
                          }
                      )
                    ]
                        : null,
                  ),
                ),

                // 3. 进度仪表盘 (仅当非搜索状态且有任务时显示，避免干扰搜索)
                if (!isSearching && totalCount > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: _ProgressHeaderCard(
                        progress: progress,
                        completedCount: completedCount,
                        totalCount: totalCount,
                      ),
                    ),
                  ),

                // 4. 内容列表区域
                if (todos.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: isSearching
                        ? const AppEmptyState(message: '未找到相关待办', icon: Icons.search_off_rounded)
                        : const AppEmptyState(
                      message: '暂无待办事项',
                      subMessage: '点击右下角按钮创建你的第一个任务',
                      icon: Icons.task_alt_rounded,
                    ),
                  )
                else ...[
                  // --- 进行中 ---
                  if (incomplete.isNotEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      sliver: SliverToBoxAdapter(
                        child: Text('进行中  ${incomplete.length}', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      // 搜索时禁用拖拽排序 (因为索引会乱)
                      sliver: isSearching
                          ? SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (ctx, i) => _TodoCard(
                            key: ValueKey(incomplete[i].id),
                            todo: incomplete[i],
                            index: i,
                            searchQuery: provider.searchQuery, // 传入搜索词用于高亮
                            onTap: () => _openTodoDialog(context, todo: incomplete[i]),
                            onToggle: () => provider.toggleTodoStatus(incomplete[i].id),
                            onDelete: () => provider.deleteTodo(incomplete[i].id),
                            isReorderable: false,
                          ),
                          childCount: incomplete.length,
                        ),
                      )
                          : SliverReorderableList(
                        itemCount: incomplete.length,
                        onReorder: (oldIndex, newIndex) {
                          AppFeedback.selection();
                          provider.reorderTodos(oldIndex, newIndex);
                        },
                        itemBuilder: (ctx, i) => _TodoCard(
                          key: ValueKey(incomplete[i].id),
                          todo: incomplete[i],
                          index: i,
                          searchQuery: provider.searchQuery,
                          onTap: () => _openTodoDialog(context, todo: incomplete[i]),
                          onToggle: () {
                            AppFeedback.medium();
                            provider.toggleTodoStatus(incomplete[i].id);
                          },
                          onDelete: () {
                            AppFeedback.heavy();
                            provider.deleteTodo(incomplete[i].id);
                          },
                          isReorderable: true,
                        ),
                        proxyDecorator: (child, index, animation) => Material(
                          elevation: 6,
                          color: Colors.transparent,
                          shadowColor: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          child: child,
                        ),
                      ),
                    ),
                  ],

                  // --- 已完成 ---
                  if (completed.isNotEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Text('已完成  ${completed.length}', style: TextStyle(color: theme.colorScheme.outline, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(width: 12),
                            Expanded(child: Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
                          ],
                        ),
                      ),
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: AnimationLimiter(
                        child: SliverList(
                          delegate: SliverChildBuilderDelegate(
                                (ctx, i) {
                              return AnimationConfiguration.staggeredList(
                                position: i,
                                duration: const Duration(milliseconds: 375),
                                child: SlideAnimation(
                                  verticalOffset: 50.0,
                                  child: FadeInAnimation(
                                    child: _TodoCard(
                                      key: ValueKey(completed[i].id),
                                      todo: completed[i],
                                      index: i,
                                      searchQuery: provider.searchQuery,
                                      onTap: () => _openTodoDialog(context, todo: completed[i]),
                                      onToggle: () => provider.toggleTodoStatus(completed[i].id),
                                      onDelete: () => provider.deleteTodo(completed[i].id),
                                      isReorderable: false,
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: completed.length,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'todo_fab',
        onPressed: () => _openTodoDialog(context),
        label: const Text('新待办', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_task_rounded),
        elevation: 4,
      ),
    );
  }
}

// 🟢 顶部进度概览卡片
class _ProgressHeaderCard extends StatelessWidget {
  final double progress;
  final int completedCount;
  final int totalCount;

  const _ProgressHeaderCard({
    required this.progress,
    required this.completedCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAllDone = progress == 1.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAllDone ? '太棒了！🎉' : '今日概览',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAllDone ? '所有任务都已完成' : '已完成 $completedCount / $totalCount 项任务',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.5),
                    valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.5),
                  color: theme.colorScheme.primary,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 🟢 优化后的待办卡片 (支持高亮)
class _TodoCard extends StatelessWidget {
  final Todo todo;
  final int index;
  final String searchQuery; // 用于高亮
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final bool isReorderable;

  const _TodoCard({
    super.key,
    required this.todo,
    required this.index,
    required this.searchQuery,
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
    if (isDone) return scheme.outline.withValues(alpha: 0.7);
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
      case _DateStatus.future: return scheme.surfaceContainerHighest.withValues(alpha: 0.5);
      case _DateStatus.none: return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = todo.isCompleted;
    final dateStatus = _getDateStatus(todo.dueDate);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(todo.id),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.25,
          children: [
            CustomSlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: Colors.transparent,
              foregroundColor: theme.colorScheme.error,
              autoClose: true,
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                width: 50, height: 50,
                child: const Icon(Icons.delete_rounded, size: 24),
              ),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDone
                ? theme.colorScheme.surfaceContainer.withValues(alpha: 0.5)
                : theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDone
                ? []
                : [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // 自定义复选框
                    InkWell(
                      onTap: onToggle,
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

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 标题 (支持高亮)
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: theme.textTheme.titleMedium!.copyWith(
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              color: isDone
                                  ? theme.colorScheme.outline
                                  : theme.colorScheme.onSurface,
                              fontWeight: isDone ? FontWeight.normal : FontWeight.bold,
                            ),
                            child: SearchHighlightText(
                              todo.title,
                              query: searchQuery,
                              style: theme.textTheme.titleMedium!.copyWith(
                                decoration: isDone ? TextDecoration.lineThrough : null,
                                color: isDone ? theme.colorScheme.outline : theme.colorScheme.onSurface,
                                fontWeight: isDone ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                          ),

                          // 描述 (支持高亮)
                          if (todo.description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: SearchHighlightText(
                                todo.description,
                                query: searchQuery,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDone ? theme.colorScheme.outline.withValues(alpha: 0.7) : theme.colorScheme.outline,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),

                          // 日期
                          if (todo.dueDate != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getDateBgColor(context, dateStatus, isDone),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                        Icons.calendar_today_rounded,
                                        size: 12,
                                        color: _getDateColor(context, dateStatus, isDone)
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatDateText(todo.dueDate!),
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: _getDateColor(context, dateStatus, isDone),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
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

                    if (isReorderable && !isDone)
                      ReorderableDragStartListener(
                        index: index,
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
        ),
      ),
    );
  }
}

enum _DateStatus { none, future, today, overdue }