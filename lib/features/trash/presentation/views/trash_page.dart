// 文件路径: lib/features/trash/presentation/views/trash_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/todos_provider.dart';
import '../../../../models/note.dart';
import '../../../../models/todo.dart';
import '../../../../utils/toast_utils.dart';
import '../../../../widgets/common/app_empty_state.dart';

class TrashPage extends StatelessWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: theme.colorScheme.surface,
          // 🟢 1. 回归克制的标准 AppBar，全端居中标题，不再搞花哨的折叠
          appBar: AppBar(
            title: const Text('回收站', style: TextStyle(fontWeight: FontWeight.w600)),
            centerTitle: true,
            backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.95),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            bottom: TabBar(
              tabs: const [
                Tab(text: '笔记', icon: Icon(Icons.description_outlined)),
                Tab(text: '待办', icon: Icon(Icons.check_circle_outlined)),
              ],
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorColor: theme.colorScheme.primary,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              splashBorderRadius: BorderRadius.circular(16),
              onTap: (_) => HapticFeedback.selectionClick(),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _confirmEmptyTrash(context);
                  },
                  icon: Icon(Icons.delete_sweep_rounded, color: theme.colorScheme.error),
                  label: Text('清空', style: TextStyle(color: theme.colorScheme.error)),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ],
          ),
          body: const TabBarView(
            children: [
              _NotesTrashList(),
              _TodosTrashList(),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmEmptyTrash(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: theme.colorScheme.errorContainer.withValues(alpha: 0.3), shape: BoxShape.circle),
          child: Icon(Icons.delete_forever_rounded, size: 32, color: theme.colorScheme.error),
        ),
        title: Text('清空回收站?', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface), textAlign: TextAlign.center),
        content: Text('所有项目将被永久删除，无法恢复。\n确定要继续吗？', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          Row(
            children: [
              Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onSurface, padding: const EdgeInsets.symmetric(vertical: 12)), child: const Text('取消'))),
              const SizedBox(width: 12),
              Expanded(
                  child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        HapticFeedback.mediumImpact();
                        Provider.of<NotesProvider>(context, listen: false).emptyTrash();
                        Provider.of<TodosProvider>(context, listen: false).emptyTrash();
                        ToastUtils.showError(context, '回收站已清空');
                      },
                      style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: theme.colorScheme.onError, padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0),
                      child: const Text('全部清空')
                  )
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AutoCleanBanner extends StatelessWidget {
  const _AutoCleanBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '项目在回收站保留 30 天后将被永久删除。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



// 🟢 删掉 _DesktopConstrainedView 类，我们不再需要死板的居中约束了！

class _NotesTrashList extends StatelessWidget {
  const _NotesTrashList();

  @override
  Widget build(BuildContext context) {
    return Consumer<NotesProvider>(
      builder: (context, provider, _) {
        final notes = provider.trashNotes;
        if (notes.isEmpty) {
          return const AppEmptyState(
            message: '没有废弃的笔记',
            subMessage: '删除的笔记会在这里保留一段时间',
            icon: Icons.note_alt_outlined,
          );
        }

        return AnimationLimiter(
          child: CustomScrollView(
            // 🟢 1. 删除了这里错误的 padding
            slivers: [
              // 2. 给顶部的 Banner 加上 padding
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: _AutoCleanBanner(),
                ),
              ),

              // 🟢 3. 使用 SliverPadding 来包裹网格内容
              SliverPadding(
                padding: EdgeInsets.only(
                  left: 16, right: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 450,
                    mainAxisExtent: 116,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final note = notes[index];
                      return AnimationConfiguration.staggeredGrid(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        columnCount: 3,
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: _TrashItemCard(
                              item: note,
                              onRestore: () {
                                HapticFeedback.lightImpact();
                                provider.restoreNote(note.id);
                              },
                              onDeleteForever: () => provider.deleteNoteForever(note.id),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: notes.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TodosTrashList extends StatelessWidget {
  const _TodosTrashList();

  @override
  Widget build(BuildContext context) {
    return Consumer<TodosProvider>(
      builder: (context, provider, _) {
        final todos = provider.trashTodos;
        if (todos.isEmpty) {
          return const AppEmptyState(
            message: '没有废弃的待办',
            subMessage: '完成或删除的任务可能出现在这里',
            icon: Icons.task_alt_outlined,
          );
        }

        return AnimationLimiter(
          child: CustomScrollView(
            // 🟢 同理，删除了这里的 padding
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: _AutoCleanBanner(),
                ),
              ),

              // 🟢 使用 SliverPadding 包裹
              SliverPadding(
                padding: EdgeInsets.only(
                  left: 16, right: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 450,
                    mainAxisExtent: 116,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final todo = todos[index];
                      return AnimationConfiguration.staggeredGrid(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        columnCount: 3,
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: _TrashItemCard(
                              item: todo,
                              onRestore: () {
                                HapticFeedback.lightImpact();
                                provider.restoreTodo(todo.id);
                              },
                              onDeleteForever: () => provider.deleteTodoForever(todo.id),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: todos.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// 🟢 3. 提取原有的极简卡片，加入 Hover 态和透明度，让它在 PC 端具有桌面软件特有的精致感
// 🟢 替换文件底部的 _TrashItemCard 和 _TrashItemCardState 类
class _TrashItemCard extends StatefulWidget {
  final dynamic item;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  const _TrashItemCard({
    required this.item,
    required this.onRestore,
    required this.onDeleteForever,
  });

  @override
  State<_TrashItemCard> createState() => _TrashItemCardState();
}

class _TrashItemCardState extends State<_TrashItemCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNote = widget.item is Note;
    final title = isNote ? (widget.item as Note).title : (widget.item as Todo).title;

    String subtitle = '';
    if (isNote) {
      subtitle = (widget.item as Note).plainText;
    } else {
      final todo = widget.item as Todo;
      if (todo.subTasks.isNotEmpty) {
        subtitle = '包含 ${todo.subTasks.length} 个子待办';
      }
    }

    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final timeStr = isNote
        ? (widget.item as Note).formattedUpdatedAt
        : (widget.item as Todo).dueDate != null
        ? DateFormat('yyyy/MM/dd').format((widget.item as Todo).dueDate!)
        : '';

    return Opacity(
      opacity: 0.8,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _isHovering
                ? theme.colorScheme.surfaceContainerHigh
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovering
                  ? theme.colorScheme.outlineVariant
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isNote ? Icons.description_outlined : Icons.check_circle_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title.isEmpty ? (isNote ? '无标题笔记' : '无标题待办') : title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (timeStr.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 12, color: theme.colorScheme.outline),
                            const SizedBox(width: 4),
                            // 🟢 核心修复：用 Flexible 包裹文本，彻底防止缩放窗口时溢出！
                            Flexible(
                              child: Text(
                                '删除于 $timeStr',
                                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                                maxLines: 1, // 限制 1 行
                                overflow: TextOverflow.ellipsis, // 空间不够时显示省略号
                              ),
                            ),
                          ],
                        )
                      ]
                    ],
                  ),
                ),
                AnimatedOpacity(
                  opacity: (!isDesktop || _isHovering) ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        onPressed: widget.onRestore,
                        icon: const Icon(Icons.restore_from_trash_rounded),
                        tooltip: '还原',
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          foregroundColor: theme.colorScheme.onSecondaryContainer,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () => _confirmDeleteForever(context),
                        icon: const Icon(Icons.delete_forever_rounded),
                        tooltip: '彻底删除',
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.errorContainer,
                          foregroundColor: theme.colorScheme.error,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteForever(BuildContext context) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: theme.colorScheme.errorContainer.withValues(alpha: 0.3), shape: BoxShape.circle),
          child: Icon(Icons.delete_forever_rounded, size: 32, color: theme.colorScheme.error),
        ),
        title: Text('永久删除?', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface), textAlign: TextAlign.center),
        content: Text('此项目将被永久移除且无法恢复。\n确定要继续吗？', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          Row(
            children: [
              Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), style: TextButton.styleFrom(foregroundColor: theme.colorScheme.onSurface, padding: const EdgeInsets.symmetric(vertical: 12)), child: const Text('取消'))),
              const SizedBox(width: 12),
              Expanded(
                  child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        HapticFeedback.mediumImpact();
                        widget.onDeleteForever();
                        ToastUtils.showError(context,'已永久删除');
                      },
                      style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: theme.colorScheme.onError, padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0),
                      child: const Text('删除')
                  )
              ),
            ],
          ),
        ],
      ),
    );
  }
}