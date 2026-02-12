import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../../core/providers/todos_provider.dart';
import '../../../../utils/app_feedback.dart';
import '../../../../widgets/common/dialogs/create_todo_dialog.dart';
import '../../../../models/todo.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../widgets/common/app_empty_state.dart';

// 确保你已经有这两个文件 (如果没有，请告诉我，我会补充提供)
import '../widgets/todo_item.dart';
import 'todo_detail_view.dart';

class TodosPage extends StatefulWidget {
  const TodosPage({super.key});

  @override
  State<TodosPage> createState() => _TodosPageState();
}

class _TodosPageState extends State<TodosPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // 🟢 恢复状态：当前选中的 Todo ID (用于桌面端分栏视图)
  String? _selectedTodoId;

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

  // 🟢 恢复逻辑：桌面端选中，移动端弹窗
  void _handleTodoTap(BuildContext context, Todo todo, bool isDesktop) {
    if (isDesktop) {
      setState(() {
        _selectedTodoId = todo.id;
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

  // 🟢 辅助构建：单个待办卡片
  Widget _buildTodoItem(BuildContext context, Todo todo, int index, TodosProvider provider, bool isDesktop) {
    final isSelected = isDesktop && todo.id == _selectedTodoId;
    final theme = Theme.of(context);

    return Container(
      key: ValueKey(todo.id),
      margin: const EdgeInsets.only(bottom: 8),

      // 使用独立的 TodoItem 组件 (请确保 todo_item.dart 已包含圆形删除按钮的修改)
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
        // 桌面端禁用拖拽，防止与鼠标操作冲突
        isReorderable: !isDesktop,
      ),
    );
  }

  // 🟢 核心构建：待办列表区域
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

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 1. 顶部栏
            SliverAppBar(
              toolbarHeight: isDesktop ? 70 : 64,
              title: isDesktop
                  ? Text('待办清单', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))
                  : const Text('我的待办', style: TextStyle(fontWeight: FontWeight.w800)),
              centerTitle: false,
              backgroundColor: theme.colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              actions: isDesktop
                  ? [] // 桌面端操作入口在侧边栏
                  : [
                IconButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.trash),
                  icon: const Icon(Icons.auto_delete_outlined),
                  tooltip: '回收站',
                ),
                IconButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: '设置',
                ),
              ],
            ),

            // 2. 搜索栏 (🟢 保持 Padding 16，与笔记页对齐)
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

            // 3. 进度卡片 (使用了下方定义的 _TodoHeaderCard)
            if (!isSearching && totalCount > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: _TodoHeaderCard(
                    progress: progress,
                    completedCount: completedCount,
                    totalCount: totalCount,
                  ),
                ),
              ),

            // 4. 列表内容
            if (todos.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: isSearching
                    ? const AppEmptyState(message: '未找到相关待办', icon: Icons.search_off)
                    : const AppEmptyState(message: '暂无待办事项', icon: Icons.task_alt),
              )
            else ...[
              // --- 进行中 ---
              if (incomplete.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  sliver: SliverToBoxAdapter(
                      child: Text('进行中', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold))
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  // 🟢 列表策略：桌面端/搜索时用 List (无拖拽)，移动端用 ReorderableList
                  sliver: (isDesktop || isSearching)
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
                      shadowColor: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      child: child,
                    ),
                  ),
                ),
              ],

              // --- 已完成 ---
              if (completed.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Text('已完成', style: TextStyle(color: theme.colorScheme.outline, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(child: Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.5))),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    // 分栏阈值
    final isDesktop = screenWidth >= 900;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: isDesktop
        // 🟢 恢复桌面端布局：左侧列表 + 右侧详情
            ? Row(
          children: [
            // 左侧：列表区 (固定宽度 400)
            SizedBox(
              width: 400,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.2))),
                ),
                child: _buildTodoList(context, isDesktop: true),
              ),
            ),

            // 右侧：详情区
            Expanded(
              child: Container(
                color: theme.colorScheme.surfaceContainerLow.withOpacity(0.5),
                child: _selectedTodoId == null
                // 空状态
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.format_list_bulleted_rounded, size: 64, color: theme.colorScheme.surfaceContainerHighest),
                      const SizedBox(height: 16),
                      Text("点击左侧任务查看详情", style: TextStyle(color: theme.colorScheme.outline)),
                    ],
                  ),
                )
                // 详情编辑页
                    : TodoDetailView(
                  todoId: _selectedTodoId!,
                  onClose: () => setState(() => _selectedTodoId = null),
                ),
              ),
            ),
          ],
        )
        // 移动端：普通全屏列表
            : _buildTodoList(context, isDesktop: false),
      ),
      // 移动端 FAB
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

// 🟢 内置 Header Card 防止文件缺失错误
class _TodoHeaderCard extends StatelessWidget {
  final double progress;
  final int completedCount;
  final int totalCount;

  const _TodoHeaderCard({
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