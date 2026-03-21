// 文件路径: lib/features/notes/presentation/views/notes_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:animations/animations.dart';

import '../../../../core/providers/notes_provider.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../models/note.dart';
import '../../../../utils/app_feedback.dart';
import '../../../../utils/toast_utils.dart';
import '../../../../widgets/common/dialogs/add_category_dialog.dart';
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

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) context.read<NotesProvider>().setSearchQuery(query);
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
                currentSort == option
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: currentSort == option
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
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
    final isDesktop = screenWidth >= 900;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
        theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
        theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        extendBody: true,
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isDesktop) _buildDesktopHeader(context, theme),
              Expanded(
                child: _buildMainContent(context, theme, isDesktop),
              ),
            ],
          ),
        ),
        floatingActionButton: isDesktop
            ? null
            : Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 100),
          child: OpenContainer(
            transitionType: ContainerTransitionType.fadeThrough,
            openBuilder: (BuildContext context, VoidCallback _) =>
            const NoteEditorPage(),
            closedElevation: 4.0,
            closedShape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16))),
            closedColor: theme.colorScheme.primaryContainer,
            transitionDuration: const Duration(milliseconds: 500),
            closedBuilder: (BuildContext context, VoidCallback openContainer) {
              return SizedBox(
                width: 56,
                height: 56,
                child: FloatingActionButton(
                  elevation: 0,
                  onPressed: openContainer,
                  backgroundColor: Colors.transparent,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.edit_rounded, size: 28),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 🌟 架构师重构：废弃 NestedScrollView，完全扁平化 CustomScrollView 解决下拉刷新失效 BUG！
  // =========================================================================
  Widget _buildMainContent(BuildContext context, ThemeData theme, bool isDesktop) {
    return Consumer<NotesProvider>(
      builder: (context, provider, _) {
        final notes = provider.filteredNotes;
        final currentKey = '${provider.selectedCategory}_${provider.searchQuery}';

        // 动态构建 Slivers，把 AppBar 和 Grid 铺平放入同一层
        List<Widget> slivers = [];

        if (!isDesktop) {
          slivers.add(
              SliverAppBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('我的笔记', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    const SizedBox(width: 8),
                    const SyncStatusIndicator(),
                  ],
                ),
                backgroundColor: theme.colorScheme.surface.withOpacity(0.95),
                surfaceTintColor: Colors.transparent,
                pinned: false,
                floating: true,
                snap: true,
                shadowColor: theme.colorScheme.shadow.withOpacity(0.1),
                actions: [
                  IconButton(onPressed: () => _showSortMenu(context), icon: const Icon(Icons.sort_rounded)),
                  IconButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.trash), icon: const Icon(Icons.auto_delete_outlined)),
                  IconButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.settings), icon: const Icon(Icons.settings_outlined)),
                  const SizedBox(width: 8),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(104),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                      Container(
                        height: 36,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.zero,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _buildCategoryChip(theme, '全部', provider.selectedCategory == null, () => provider.selectCategory(null)),
                            ...provider.categories.map((c) => _buildCategoryChip(
                                theme, c, provider.selectedCategory == c,
                                    () => provider.selectCategory(provider.selectedCategory == c ? null : c))),
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: ActionChip(
                                onPressed: () => _handleAddCategory(context),
                                tooltip: "添加分类",
                                label: const Icon(Icons.add_rounded, size: 16),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                side: BorderSide.none,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                                labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
          );
        }

        if (notes.isEmpty) {
          slivers.add(
              SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(theme, provider.searchQuery.isNotEmpty, provider.selectedCategory)
              )
          );
        } else {
          final gridLayoutKey = ValueKey(Object.hashAll(notes.map((n) => Object.hash(n.id, n.updatedAt))));
          final crossAxisCount = _calculateCrossAxisCount(MediaQuery.of(context).size.width);

          slivers.add(
              SliverPadding(
                padding: EdgeInsets.only(
                    left: isDesktop ? 32 : 12,
                    right: isDesktop ? 32 : 12,
                    top: 12,
                    bottom: isDesktop ? 24 : 120),
                sliver: SliverMasonryGrid(
                  key: gridLayoutKey,
                  gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxisCount),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final note = notes[index];
                      return AnimationConfiguration.staggeredGrid(
                        position: index,
                        duration: const Duration(milliseconds: 400),
                        columnCount: crossAxisCount,
                        child: SlideAnimation(
                          verticalOffset: 40.0,
                          curve: Curves.easeOutQuart,
                          child: FadeInAnimation(
                            curve: Curves.easeOutQuart,
                            child: KeyedSubtree(
                              key: ValueKey(note.id),
                              child: OpenContainer(
                                clipBehavior: Clip.antiAlias,
                                transitionType: ContainerTransitionType.fadeThrough,
                                closedShape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  side: BorderSide(
                                    color: theme.colorScheme.outlineVariant.withOpacity(0.3),
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
                                    searchQuery: provider.searchQuery,
                                    onTap: openContainer,
                                    onLongPress: () => showNoteOptionsSheet(context, note),
                                    onSecondaryTap: () => showNoteOptionsSheet(context, note),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: notes.length,
                  ),
                ),
              )
          );
        }

        // 🟢 核心修复：通过 AnimationLimiter 触发交错动画，并注入 AlwaysScrollableScrollPhysics 唤醒下拉刷新！
        Widget scrollView = AnimationLimiter(
          key: ValueKey('limiter_$currentKey'),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: slivers,
          ),
        );

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
      },
    );
  }

  // =========================================================================
  // 🟢 架构师重构：大尺寸标题 + 舒展的搜索框 + 分类标签栏 (桌面端保持不变)
  // =========================================================================
  Widget _buildDesktopHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 16),
      color: theme.colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                  "我的笔记",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: 1.2,
                  )
              ),
              const Spacer(),

              SizedBox(
                width: 280,
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

              const SizedBox(width: 16),
              const SyncStatusIndicator(),
              IconButton(
                onPressed: () async {
                  await context.read<NotesProvider>().syncWithCloud();
                  if (context.mounted) ToastUtils.showSuccess(context, '已与云端同步最新数据');
                },
                icon: const Icon(Icons.sync_rounded, size: 22),
                tooltip: "同步",
                style: IconButton.styleFrom(backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showSortMenu(context),
                icon: const Icon(Icons.sort_rounded, size: 22),
                tooltip: "排序",
                style: IconButton.styleFrom(backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)),
              ),
            ],
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 36,
            child: Consumer<NotesProvider>(
              builder: (context, provider, _) {
                return ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildCategoryChip(theme, '全部', provider.selectedCategory == null, () => provider.selectCategory(null)),
                    ...provider.categories.map((c) => _buildCategoryChip(theme, c, provider.selectedCategory == c, () => provider.selectCategory(provider.selectedCategory == c ? null : c))),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ActionChip(
                        onPressed: () => _handleAddCategory(context),
                        tooltip: "添加分类",
                        label: const Icon(Icons.add_rounded, size: 16),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide.none,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                      ),
                    ),
                  ],
                );
              },
            ),
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
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
          Icon(Icons.dashboard_customize_outlined,
              size: 64, color: theme.colorScheme.outline.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            isSearching
                ? '未找到相关笔记'
                : (selectedCategory == null || selectedCategory == 'null'
                ? '暂无笔记'
                : '该分类下暂无笔记'),
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
            icon = Icon(Icons.cloud_off_rounded, color: theme.colorScheme.outlineVariant, size: 20);
            tooltip = "未登录，仅保存在本地";
            break;
          case SyncState.syncing:
            icon = SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
            );
            tooltip = "正在与云端同步...";
            break;
          case SyncState.success:
            icon = const Icon(Icons.cloud_done_rounded, color: Colors.green, size: 20);
            tooltip = "已保存到云端";
            break;
          case SyncState.error:
            icon = Icon(Icons.cloud_off_rounded, color: theme.colorScheme.error, size: 20);
            tooltip = "同步失败，请检查网络";
            break;
          case SyncState.idle:
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
            child: KeyedSubtree(
              key: ValueKey<SyncState>(state),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: icon),
            ),
          ),
        );
      },
    );
  }
}