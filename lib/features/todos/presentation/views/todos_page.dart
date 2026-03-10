// 文件路径: lib/features/todos/presentation/views/todos_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/todos_provider.dart';
import '../../../../utils/app_feedback.dart';
import '../../../../widgets/common/dialogs/create_todo_dialog.dart';
import '../../../../models/todo.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../widgets/common/app_empty_state.dart';

import '../widgets/todo_item.dart';
import '../widgets/todo_overview_card.dart';
import '../widgets/calendar_card.dart';
import 'todo_detail_view.dart';

class TodosPage extends StatefulWidget {
  const TodosPage({super.key});

  @override
  State<TodosPage> createState() => _TodosPageState();
}

class _TodosPageState extends State<TodosPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String? _selectedTodoId;
  DateTime _focusedDay = DateTime.now();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  double _calculateProgress(int completed, int total) {
    if (total == 0) return 0.0;
    return completed / total;
  }

  void _handleTodoTap(BuildContext context, Todo todo, bool isDesktop) {
    if (isDesktop) {
      setState(() {
        _selectedTodoId = todo.id;
        if (todo.dueDate != null) {
          _focusedDay = todo.dueDate!;
        }
      });
    } else {
      _openTodoDialog(context, todo: todo);
    }
  }

  void _openTodoDialog(BuildContext context, {Todo? todo}) async {
    AppFeedback.selection();
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
        AppFeedback.medium();
      } else {
        await provider.updateTodo(result);
      }
    }
  }

  Widget _buildTodoItem(BuildContext context, Todo todo, int index, TodosProvider provider, bool isDesktop) {
    final isSelected = isDesktop && todo.id == _selectedTodoId;
    return Container(
      key: ValueKey(todo.id),
      margin: const EdgeInsets.only(bottom: 8),
      child: TodoItem(
        todo: todo,
        index: index,
        searchQuery: provider.searchQuery,
        isSelected: isSelected,
        onTap: () => _handleTodoTap(context, todo, isDesktop),
        onToggle: () => provider.toggleTodoStatus(todo.id),
        onDelete: () {
          provider.deleteTodo(todo.id);
          if (_selectedTodoId == todo.id) {
            setState(() => _selectedTodoId = null);
          }
        },
        isReorderable: true,
      ),
    );
  }

  Widget _buildTodoList(BuildContext context, {required bool isDesktop}) {
    final theme = Theme.of(context);

    return Consumer<TodosProvider>(
      builder: (ctx, provider, _) {
        final todos = provider.filteredTodos;
        final incomplete = todos.where((t) => !t.isCompleted).toList();
        final completed = todos.where((t) => t.isCompleted).toList();
        final isSearching = provider.searchQuery.isNotEmpty;
        final totalCount = todos.length;
        final completedCount = completed.length;
        final progress = _calculateProgress(completedCount, totalCount);

        Widget scrollView = CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. SliverAppBar (加入同步状态和按钮)
            SliverAppBar(
              toolbarHeight: isDesktop ? 70 : 64,
              // 🟢 将标题和状态云朵放在同一个 Row 里
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isDesktop ? '待办清单' : '我的待办',
                    style: isDesktop
                        ? theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
                        : const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  const TodoSyncStatusIndicator(), // 🟢 加入状态云朵
                ],
              ),
              centerTitle: false,
              backgroundColor: theme.colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              actions: isDesktop
                  ? [
                // 🟢 桌面端新增：手动同步按钮
                IconButton.filledTonal(
                  onPressed: () => context.read<TodosProvider>().syncWithCloud(),
                  icon: const Icon(Icons.sync_rounded),
                  tooltip: "手动同步",
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 16),
              ]
                  : [
                // 移动端的按钮保持不变
                IconButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.trash),
                  icon: const Icon(Icons.auto_delete_outlined),
                ),
                IconButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),

            // 2. 搜索栏
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SearchBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  hintText: '搜索待办...',
                  leading: const Icon(Icons.search, size: 20),
                  elevation: WidgetStateProperty.all(0),
                  backgroundColor: WidgetStateProperty.all(
                      theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                  ),
                  onChanged: (value) => provider.setSearchQuery(value),
                  constraints: const BoxConstraints(minHeight: 48, maxHeight: 48),
                  trailing: _searchController.text.isNotEmpty
                      ? [
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchController.clear();
                        provider.setSearchQuery('');
                      },
                    )
                  ]
                      : null,
                ),
              ),
            ),

            if (!isSearching && totalCount > 0 && !isDesktop)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: TodoOverviewCard(
                    progress: progress,
                    completedCount: completedCount,
                    totalCount: totalCount,
                  ),
                ),
              ),

            if (todos.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: isSearching
                    ? const AppEmptyState(message: '未找到相关待办', icon: Icons.search_off)
                    : const AppEmptyState(message: '暂无待办事项', icon: Icons.task_alt),
              )
            else ...[
              // --- 进行中任务列表 ---
              if (incomplete.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  sliver: SliverToBoxAdapter(
                      child: Text('进行中', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold))
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: isSearching
                      ? SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _buildTodoItem(context, incomplete[i], i, provider, isDesktop),
                      childCount: incomplete.length,
                    ),
                  )
                      : SliverReorderableList(
                    itemCount: incomplete.length,
                    onReorder: (oldIndex, newIndex) {
                      AppFeedback.selection();
                      provider.reorderTodos(oldIndex, newIndex);
                    },
                    itemBuilder: (ctx, i) => _buildTodoItem(context, incomplete[i], i, provider, isDesktop),
                    proxyDecorator: (child, index, animation) => Material(
                      elevation: 6,
                      color: Colors.transparent,
                      shadowColor: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      child: child,
                    ),
                  ),
                ),
              ],

              // --- 已完成任务列表 ---
              if (completed.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Text('已完成', style: TextStyle(color: theme.colorScheme.outline, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(child: Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _buildTodoItem(context, completed[i], i, provider, isDesktop),
                      childCount: completed.length,
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ]
          ],
        );

        // 🟢 为移动端包裹下拉刷新组件 (Pull-to-Refresh)
        if (!isDesktop) {
          return RefreshIndicator(
            onRefresh: () async {
              HapticFeedback.mediumImpact();
              await context.read<TodosProvider>().syncWithCloud();
            },
            child: scrollView,
          );
        }

        return scrollView;
      },
    );
  }

  Widget _buildRightContent(BuildContext context, ThemeData theme, List<Todo> todos, int completedCount, double progress) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final isNarrowWidth = width < 750;
        final double estimatedHeaderHeight = isNarrowWidth ? 180 : 350;
        final double minEditorHeight = 400;
        final bool needScroll = height < (estimatedHeaderHeight + minEditorHeight);

        Widget header;
        if (isNarrowWidth) {
          header = Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: TodoOverviewCard(
              progress: progress,
              completedCount: completedCount,
              totalCount: todos.length,
              isDesktop: true,
            ),
          );
        } else {
          header = Container(
            padding: const EdgeInsets.all(24),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: CalendarCard(
                      todos: todos,
                      selectedTodoId: _selectedTodoId,
                      focusedDay: _focusedDay,
                      onDaySelected: (day) => setState(() => _focusedDay = day),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 2,
                    child: TodoOverviewCard(
                      progress: progress,
                      completedCount: completedCount,
                      totalCount: todos.length,
                      isDesktop: true,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        Widget detailView = _selectedTodoId == null
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app_rounded,
                  size: 48,
                  color: theme.colorScheme.outline.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                  "点击左侧任务进行编辑",
                  style: TextStyle(color: theme.colorScheme.outline)
              ),
            ],
          ),
        )
            : TodoDetailView(
          todoId: _selectedTodoId!,
          onClose: () => setState(() => _selectedTodoId = null),
        );

        if (needScroll) {
          return SingleChildScrollView(
            child: Column(
              children: [
                header,
                Container(
                  height: minEditorHeight,
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2))),
                  ),
                  child: detailView,
                ),
              ],
            ),
          );
        } else {
          return Column(
            children: [
              header,
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2))),
                  ),
                  child: detailView,
                ),
              ),
            ],
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    final provider = context.watch<TodosProvider>();
    final todos = provider.todos;
    final completedCount = todos.where((t) => t.isCompleted).length;
    final progress = _calculateProgress(completedCount, todos.length);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: isDesktop
            ? Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 300, maxWidth: 450),
              child: Container(
                width: screenWidth * 0.3,
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2))),
                ),
                child: _buildTodoList(context, isDesktop: true),
              ),
            ),
            Expanded(
              child: Container(
                color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.3),
                child: _buildRightContent(context, theme, todos, completedCount, progress),
              ),
            ),
          ],
        )
            : _buildTodoList(context, isDesktop: false),
      ),
      floatingActionButton: isDesktop
          ? null
          : FloatingActionButton.extended(
        heroTag: 'todo_fab',
        onPressed: () => _openTodoDialog(context),
        label: const Text('新待办', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add_task_rounded),
      ),
    );
  }
}

// =================================================================
// 🟢 新增：待办同步状态指示器组件
// =================================================================
class TodoSyncStatusIndicator extends StatelessWidget {
  const TodoSyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TodosProvider>(
      builder: (context, provider, child) {
        final state = provider.syncState;
        final theme = Theme.of(context);

        Widget icon;
        String tooltip;

        switch (state) {
          case TodoSyncState.unauthenticated:
          // 🟢 未登录状态：灰色的云朵带个锁或者斜杠
            icon = Icon(Icons.cloud_off_rounded, color: theme.colorScheme.outlineVariant, size: 20);
            tooltip = "未登录，仅保存在本地";
            break;
          case TodoSyncState.syncing:
          // 正在同步：旋转的云朵圈
            icon = SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
            );
            tooltip = "正在与云端同步...";
            break;
          case TodoSyncState.success:
          // 同步成功：绿色对勾小云朵
            icon = const Icon(Icons.cloud_done_rounded, color: Colors.green, size: 20);
            tooltip = "已保存到云端";
            break;
          case TodoSyncState.error:
          // 同步失败：红色警告云朵
            icon = Icon(Icons.cloud_off_rounded, color: theme.colorScheme.error, size: 20);
            tooltip = "同步失败，请检查网络";
            break;
          case TodoSyncState.idle:
          default:
          // 空闲状态：普通的云朵
            icon = Icon(Icons.cloud_queue_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20);
            tooltip = "已与云端同步";
            break;

        }

        return Tooltip(
          message: tooltip,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child)
              );
            },
            child: KeyedSubtree(
              key: ValueKey<TodoSyncState>(state),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: icon,
              ),
            ),
          ),
        );
      },
    );
  }
}