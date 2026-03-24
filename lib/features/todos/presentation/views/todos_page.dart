// 文件路径: lib/features/todos/presentation/views/todos_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// 🟢 引入交错动画包
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../../core/providers/todos_provider.dart';
import '../../../../utils/app_feedback.dart';
import '../../../../models/todo.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../widgets/common/dialogs/create_todo_sheet.dart';

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
    final result = await showCreateTodoSheet(
      context,
      existingTodo: todo,
    );

    if (result != null && context.mounted) {
      final provider = Provider.of<TodosProvider>(context, listen: false);
      if (todo == null) {
        await provider.addTodo(
          title: result.title,
          description: '',
          dueDate: result.dueDate,
          subTasks: result.subTasks,
        );
        AppFeedback.medium();
      } else {
        await provider.updateTodo(todo.copyWith(
          title: result.title,
          dueDate: result.dueDate,
          subTasks: result.subTasks,
        ));
      }
    }
  }

  // 🟢 核心改造：将单个待办卡片包裹在交错动画中
  Widget _buildTodoItem(BuildContext context, Todo todo, int index, TodosProvider provider, bool isDesktop, {int animationIndexOffset = 0}) {
    final isSelected = isDesktop && todo.id == _selectedTodoId;

    Widget child = Container(
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

    // 🟢 使用 KeyedSubtree 极其关键：因为 SliverReorderableList 强制要求根节点必须有 Key 才能拖拽！
    return KeyedSubtree(
      key: ValueKey(todo.id),
      child: AnimationConfiguration.staggeredList(
        position: index + animationIndexOffset, // 保证所有元素的出场顺序是连贯的
        duration: const Duration(milliseconds: 375),
        child: SlideAnimation(
          verticalOffset: 50.0,
          child: FadeInAnimation(
            child: RepaintBoundary(
              child: child,
            ),
          ),
        ),
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

        // 动态构建 Slivers，以便精确控制动画索引
        List<Widget> slivers = [];
        int animIndex = 0; // 动画全局排序号

        // 1. 顶部 AppBar (回归克制紧凑风格)
        slivers.add(
            SliverAppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isDesktop ? '待办清单' : '我的待办', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                  const SizedBox(width: 8),
                  const TodoSyncStatusIndicator(),
                ],
              ),
              backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.95), // 顶层轻微半透
              surfaceTintColor: Colors.transparent,
              pinned: true,
              elevation: 0,
              actions: isDesktop
                  ? [
                FilledButton.icon(
                  onPressed: () => _openTodoDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('新待办', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: () => context.read<TodosProvider>().syncWithCloud(),
                  icon: const Icon(Icons.sync_rounded),
                  tooltip: "手动同步",
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha:0.5),
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
                  icon: const Icon(Icons.settings_outlined),
                ),
                const SizedBox(width: 16),
              ]
                  : [
                IconButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.trash),
                  icon: const Icon(Icons.auto_delete_outlined),
                ),
                IconButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
                  icon: const Icon(Icons.settings_outlined),
                ),
                const SizedBox(width: 4),
              ],
            )
        );

        // 2. 搜索栏
        slivers.add(
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
            )
        );

        // 3. 进度概览卡片 (加入出场动画)
        if (!isSearching && totalCount > 0 && !isDesktop) {
          slivers.add(
            SliverToBoxAdapter(
              child: AnimationConfiguration.staggeredList(
                position: animIndex++, // 占据第 0 号动画位
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: TodoOverviewCard(
                        progress: progress,
                        completedCount: completedCount,
                        totalCount: totalCount,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // 4. 空状态 或 列表渲染
        if (todos.isEmpty) {
          slivers.add(
              SliverFillRemaining(
                hasScrollBody: false,
                child: AnimationConfiguration.staggeredList(
                  position: animIndex++,
                  duration: const Duration(milliseconds: 375),
                  child: FadeInAnimation(
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                  isSearching ? Icons.search_off_rounded : Icons.coffee_rounded,
                                  size: 64,
                                  color: theme.colorScheme.primary.withValues(alpha: 0.8)
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              isSearching ? '未找到相关待办' : '今天真是清清爽爽的一天呢~',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isSearching ? '换个关键词试试吧' : '点击下方按钮，敲击回车连贯创建',
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
          );
        } else {
          // 进行中标题 (加入出场动画)
          if (incomplete.isNotEmpty) {
            slivers.add(
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: AnimationConfiguration.staggeredList(
                    position: animIndex++,
                    duration: const Duration(milliseconds: 375),
                    child: FadeInAnimation(
                      child: SlideAnimation(
                        verticalOffset: 20.0,
                        child: Text('进行中', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ),
            );

            // 进行中列表
            final incompleteOffset = animIndex;
            slivers.add(
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: isSearching
                    ? SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _buildTodoItem(context, incomplete[i], i, provider, isDesktop, animationIndexOffset: incompleteOffset),
                    childCount: incomplete.length,
                  ),
                )
                    : SliverReorderableList(
                  itemCount: incomplete.length,
                  onReorder: (oldIndex, newIndex) {
                    AppFeedback.selection();
                    provider.reorderTodos(oldIndex, newIndex);
                  },
                  itemBuilder: (ctx, i) => _buildTodoItem(context, incomplete[i], i, provider, isDesktop, animationIndexOffset: incompleteOffset),
                  proxyDecorator: (child, index, animation) => Material(
                    elevation: 6,
                    color: Colors.transparent,
                    shadowColor: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    child: child,
                  ),
                ),
              ),
            );
            animIndex += incomplete.length;
          }

          // 已完成标题 (加入出场动画)
          if (completed.isNotEmpty) {
            slivers.add(
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: AnimationConfiguration.staggeredList(
                    position: animIndex++,
                    duration: const Duration(milliseconds: 375),
                    child: FadeInAnimation(
                      child: SlideAnimation(
                        verticalOffset: 20.0,
                        child: Row(
                          children: [
                            Text('已完成', style: TextStyle(color: theme.colorScheme.outline, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Expanded(child: Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );

            // 已完成列表
            final completedOffset = animIndex;
            slivers.add(
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _buildTodoItem(context, completed[i], i, provider, isDesktop, animationIndexOffset: completedOffset),
                    childCount: completed.length,
                  ),
                ),
              ),
            );
            animIndex += completed.length;
          }

          // 底部大间距防挡
          slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 120)));
        }

        // 🟢 核心引擎：将整个 CustomScrollView 包裹在 AnimationLimiter 中触发联控动画
        Widget scrollView = AnimationLimiter(
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: slivers,
          ),
        );

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
              Icon(Icons.touch_app_rounded, size: 48, color: theme.colorScheme.outline.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text("点击左侧任务进行编辑", style: TextStyle(color: theme.colorScheme.outline)),
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
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)))),
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
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)))),
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        extendBody: true,
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          bottom: false,
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

        // 🟢 极简悬浮按钮：被安全垫高，避开毛玻璃底部导航栏
        floatingActionButton: isDesktop
            ? null
            : Padding(
          padding: const EdgeInsets.only(right: 12, bottom: 100), // 彻底救出毛玻璃区域
          child: FloatingActionButton(
            heroTag: 'todo_fab',
            onPressed: () {
              AppFeedback.light();
              _openTodoDialog(context);
            },
            elevation: 4,
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.add_task_rounded, size: 28),
          ),
        ),
      ),
    );
  }
}

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
            icon = Icon(Icons.cloud_off_rounded, color: theme.colorScheme.outlineVariant, size: 20);
            tooltip = "未登录，仅保存在本地";
            break;
          case TodoSyncState.syncing:
            icon = SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary));
            tooltip = "正在与云端同步...";
            break;
          case TodoSyncState.success:
            icon = const Icon(Icons.cloud_done_rounded, color: Colors.green, size: 20);
            tooltip = "已保存到云端";
            break;
          case TodoSyncState.error:
            icon = Icon(Icons.cloud_off_rounded, color: theme.colorScheme.error, size: 20);
            tooltip = "同步失败，请检查网络";
            break;
          case TodoSyncState.idle:
          default:
            icon = Icon(Icons.cloud_queue_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20);
            tooltip = "已与云端同步";
            break;
        }

        return Tooltip(
          message: tooltip,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child));
            },
            child: KeyedSubtree(key: ValueKey<TodoSyncState>(state), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4.0), child: icon)),
          ),
        );
      },
    );
  }
}