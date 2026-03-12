import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:notesync_app/widgets/common/dialogs/add_category_dialog.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:animations/animations.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../utils/app_feedback.dart';
import '../../../../utils/toast_utils.dart';
import 'note_editor_page.dart';
import '../widgets/note_card.dart';
import '../widgets/dialogs/note_options_sheet.dart';

import '../widgets/note_search_bar.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isFabExtended = true;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  int _calculateCrossAxisCount(double width) {
    if (width > 1600) return 5;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    return 2;
  }

  bool _handleScrollNotification(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.reverse) {
      if (_isFabExtended) setState(() => _isFabExtended = false);
    } else if (notification.direction == ScrollDirection.forward) {
      if (!_isFabExtended) setState(() => _isFabExtended = true);
    }
    return true;
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        context.read<NotesProvider>().setSearchQuery(query);
      }
    });
  }

  void _showSortMenu(BuildContext context) {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final currentSort = provider.sortOption;
    final theme = Theme.of(context);

    showMenu<NoteSortOption>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 80, 0, 0),
      items: NoteSortOption.values.map((option) {
        return PopupMenuItem(
          value: option,
          child: Row(
            children: [
              Icon(
                currentSort == option ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: currentSort == option ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(option.label),
            ],
          ),
        );
      }).toList(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ).then((value) {
      if (value != null) provider.changeSortOption(value);
    });
  }

  void _handleAddCategory(BuildContext context) async {
    final provider = context.read<NotesProvider>();

    final String? newCategory = await showAddCategoryDialog(context);

    if (newCategory != null && newCategory.isNotEmpty) {
      await provider.addCategory(newCategory);
      provider.selectCategory(newCategory);
      AppFeedback.light();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 600;

    // 🟢 布局修复：使用 SafeArea 包裹 Scaffold 的 body 内容
    // 并且确保 Column 占据最大高度，Expanded 才能生效
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // 确保横向占满
          children: [
            // 1. 顶部栏 (固定高度，不滚动)
            if (isDesktop)
              _buildDesktopHeader(context, theme)
            else
              _buildMobileHeader(context, theme),


            Expanded(
              child: NotificationListener<UserScrollNotification>(
                onNotification: _handleScrollNotification,
                child: _buildScrollableContent(context, theme, isDesktop),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isDesktop
          ? null
          : OpenContainer(
        transitionType: ContainerTransitionType.fadeThrough,
        openBuilder: (BuildContext context, VoidCallback _) => const NoteEditorPage(),
        closedElevation: 6.0,
        closedShape: _isFabExtended
            ? const StadiumBorder()
            : const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        closedColor: theme.colorScheme.primaryContainer,
        transitionDuration: const Duration(milliseconds: 500),
        closedBuilder: (BuildContext context, VoidCallback openContainer) {
          return FloatingActionButton.extended(
            elevation: 0,
            onPressed: openContainer,
            backgroundColor: Colors.transparent,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            isExtended: _isFabExtended,
            label: const Text('写笔记', style: TextStyle(fontWeight: FontWeight.bold)),
            icon: const Icon(Icons.edit_rounded),
          );
        },
      ),
    );
  }

  Widget _buildScrollableContent(BuildContext context, ThemeData theme, bool isDesktop) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = _calculateCrossAxisCount(screenWidth);

    final scrollView = CustomScrollView(
      // 🟢 修复 3：强制开启始终可滚动，确保内容很少或为空时，也能触发下拉刷新
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        if (!isDesktop)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: NoteSearchBar(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                onClear: () {
                  AppFeedback.light();
                  context.read<NotesProvider>().setSearchQuery('');
                  _searchFocusNode.unfocus();
                },
              ),
            ),
          ),

        SliverToBoxAdapter(
          child: Consumer<NotesProvider>(
            builder: (context, provider, _) {
              final categories = provider.categories;
              final selectedCategory = provider.selectedCategory;

              // 🟢 修复 1：删除了这里的 if (categories.isEmpty) return const SizedBox.shrink();
              // 确保无论有没有分类，“全部”和“+”按钮永远存在！

              return Container(
                height: 50,
                margin: const EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  children: [
                    _buildCategoryChip(theme, '全部', selectedCategory == null, () => provider.selectCategory(null)),
                    ...categories.map((category) => _buildCategoryChip(
                      theme,
                      category,
                      selectedCategory == category,
                          () => provider.selectCategory(selectedCategory == category ? null : category),
                    )),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ActionChip(
                        onPressed: () => _handleAddCategory(context),
                        tooltip: "添加分类",
                        label: const Icon(Icons.add_rounded, size: 18),
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        side: BorderSide.none,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        Consumer<NotesProvider>(
          builder: (context, provider, _) {
            final notes = provider.filteredNotes;
            final searchQuery = provider.searchQuery;

            if (notes.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(theme, provider.searchQuery.isNotEmpty, provider.selectedCategory),
              );
            }

            return SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 12, vertical: 12),
              sliver: AnimationLimiter(
                child: SliverMasonryGrid.count(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childCount: notes.length,
                  itemBuilder: (context, index) {
                    final note = notes[index];
                    return AnimationConfiguration.staggeredGrid(
                      position: index,
                      duration: const Duration(milliseconds: 375),
                      columnCount: crossAxisCount,
                      child: ScaleAnimation(
                        scale: 0.9,
                        child: FadeInAnimation(
                          child: OpenContainer(
                            clipBehavior: Clip.antiAlias,
                            transitionType: ContainerTransitionType.fadeThrough,
                            closedShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                              side: BorderSide(
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            closedElevation: 0,
                            closedColor: theme.colorScheme.surfaceContainerLow,
                            openShape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                            openColor: theme.colorScheme.surface,
                            openElevation: 0,
                            transitionDuration: const Duration(milliseconds: 600),
                            openBuilder: (context, _) => NoteEditorPage(note: note),
                            closedBuilder: (context, openContainer) {
                              return NoteCard(
                                note: note,
                                searchQuery: searchQuery,
                                onTap: openContainer,
                                onLongPress: () => showNoteOptionsSheet(context, note),
                                onSecondaryTap: () => showNoteOptionsSheet(context, note),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );

    // 🟢 为移动端包裹下拉刷新组件 (Pull-to-Refresh)
    if (!isDesktop) {
      return RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          await context.read<NotesProvider>().syncWithCloud();
        },
        child: scrollView,
      );
    }

    return scrollView;
  }

  Widget _buildDesktopHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
      color: theme.colorScheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("我的笔记", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Selector<NotesProvider, int>(
                selector: (_, provider) => provider.filteredNotes.length,
                builder: (_, count, __) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "$count",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Center(
              child: NoteSearchBar(
                controller: _searchController,
                focusNode: _searchFocusNode,
                maxWidth: 500,
                backgroundColor: theme.colorScheme.surfaceContainerLow,
                onChanged: _onSearchChanged,
                onClear: () {
                  AppFeedback.light();
                  context.read<NotesProvider>().setSearchQuery('');
                  _searchFocusNode.unfocus();
                },
              ),
            ),
          ),
          const SizedBox(width: 24),
          const SizedBox(width: 8),
          const SyncStatusIndicator(),
          // 🟢 桌面端新增：手动同步按钮
          IconButton.filledTonal(
            onPressed: () async {
              await context.read<NotesProvider>().syncWithCloud();
              if (context.mounted) {
                ToastUtils.showSuccess(context, '已与云端同步最新数据');
              }
            },
            icon: const Icon(Icons.sync_rounded),
            tooltip: "同步",
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),

          IconButton.filledTonal(
            onPressed: () => _showSortMenu(context),
            icon: const Icon(Icons.sort_rounded),
            tooltip: "排序",
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          Text("我的笔记", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          const SyncStatusIndicator(),
          const Spacer(),
          IconButton(
            onPressed: () => _showSortMenu(context),
            icon: const Icon(Icons.sort_rounded),
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.trash),
            icon: const Icon(Icons.auto_delete_outlined),
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(ThemeData theme, String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        selectedColor: theme.colorScheme.primaryContainer,
        labelStyle: TextStyle(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isSearching, String? selectedCategory) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dashboard_customize_outlined, size: 64, color: theme.colorScheme.outline.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            isSearching
                ? '未找到相关笔记'
                : (selectedCategory == null ? '暂无笔记' : '该分类下暂无笔记'),
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline),

          ),
        ],
      ),
    );
  }
}
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotesProvider>(
      builder: (context, provider, child) {
        final state = provider.syncState;
        final theme = Theme.of(context);

        Widget icon;
        String tooltip;

        switch (state) {
          case SyncState.unauthenticated:
          // 🟢 未登录状态：灰色的云朵带个锁或者斜杠
            icon = Icon(Icons.cloud_off_rounded, color: theme.colorScheme.outlineVariant, size: 20);
            tooltip = "未登录，仅保存在本地";
            break;
          case SyncState.syncing:
          // 正在同步：旋转的云朵
            icon = SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
            );
            tooltip = "正在与云端同步...";
            break;
          case SyncState.success:
          // 同步成功：绿色对勾小云朵
            icon = const Icon(Icons.cloud_done_rounded, color: Colors.green, size: 20);
            tooltip = "已保存到云端";
            break;
          case SyncState.error:
          // 同步失败：红色警告云朵
            icon = Icon(Icons.cloud_off_rounded, color: theme.colorScheme.error, size: 20);
            tooltip = "同步失败，请检查网络";
            break;
          case SyncState.idle:
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
              return ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child));
            },
            child: KeyedSubtree(
              key: ValueKey<SyncState>(state),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: icon,
              ),
            ),
          ),
        );
      },
    );
  }
}