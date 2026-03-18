// 文件路径: lib/features/notes/presentation/views/notes_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:animations/animations.dart'; // 新增：用于 OpenContainer

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
        // 🌟 FAB 使用 OpenContainer 实现平滑过渡
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
  // 🌟 NestedScrollView 智能层叠框架（保留原分类切换动画）
  // =========================================================================
  Widget _buildMainContent(BuildContext context, ThemeData theme, bool isDesktop) {
    Widget content = NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        if (!isDesktop)
          SliverAppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('我的笔记',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                const SyncStatusIndicator(),
              ],
            ),
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            elevation: 0,
            actions: [
              IconButton(
                  onPressed: () => _showSortMenu(context),
                  icon: const Icon(Icons.sort_rounded)),
              IconButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.trash),
                  icon: const Icon(Icons.auto_delete_outlined)),
              IconButton(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
                  icon: const Icon(Icons.settings_outlined)),
              const SizedBox(width: 8),
            ],
          ),
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
              return Container(
                height: 50,
                margin: const EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  children: [
                    _buildCategoryChip(
                        theme,
                        '全部',
                        provider.selectedCategory == null,
                            () => provider.selectCategory(null)),
                    ...provider.categories.map((c) => _buildCategoryChip(
                        theme,
                        c,
                        provider.selectedCategory == c,
                            () => provider.selectCategory(
                            provider.selectedCategory == c ? null : c))),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ActionChip(
                        onPressed: () => _handleAddCategory(context),
                        tooltip: "添加分类",
                        label: const Icon(Icons.add_rounded, size: 18),
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        side: BorderSide.none,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(0.5),
                        labelStyle:
                        TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],

      // 🌟 灵魂交叉切换动画 (CrossFade) —— 保留原分类切换动画
      body: Consumer<NotesProvider>(
        builder: (context, provider, _) {
          final notes = provider.filteredNotes;
          final currentKey = '${provider.selectedCategory}_${provider.searchQuery}';

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutQuart,
            switchOutCurve: Curves.easeInQuart,
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: _buildGridBody(
                context, theme, notes, currentKey, provider.searchQuery, isDesktop),
          );
        },
      ),
    );

    if (!isDesktop) {
      return RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          await context.read<NotesProvider>().syncWithCloud();
        },
        child: content,
      );
    }
    return content;
  }

  // 构建带交错动画的瀑布流，并将卡片点击改为 OpenContainer
  Widget _buildGridBody(BuildContext context, ThemeData theme, List<Note> notes,
      String currentKey, String searchQuery, bool isDesktop) {
    if (notes.isEmpty) {
      return KeyedSubtree(
        key: ValueKey('empty_$currentKey'),
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
                child: _buildEmptyState(
                    theme, searchQuery.isNotEmpty, currentKey.split('_')[0]))
          ],
        ),
      );
    }

    // 绝对防重叠密钥
    final gridLayoutKey =
    ValueKey(Object.hashAll(notes.map((n) => Object.hash(n.id, n.updatedAt))));
    final crossAxisCount = _calculateCrossAxisCount(MediaQuery.of(context).size.width);

    return AnimationLimiter(
      key: ValueKey('limiter_$currentKey'), // 确保切换分类时动画重置
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
                left: isDesktop ? 32 : 12,
                right: isDesktop ? 32 : 12,
                top: 12,
                bottom: isDesktop ? 24 : 120),
            sliver: SliverMasonryGrid(
              key: gridLayoutKey,
              gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount),
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
                          // 🌟 使用 OpenContainer 包裹 NoteCard，实现平滑过渡
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
                            openShape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero),
                            openColor: theme.colorScheme.surface,
                            openElevation: 0,
                            transitionDuration: const Duration(milliseconds: 600),
                            openBuilder: (context, _) => NoteEditorPage(note: note),
                            closedBuilder: (context, openContainer) {
                              return NoteCard(
                                note: note,
                                searchQuery: searchQuery,
                                onTap: openContainer, // 触发 OpenContainer 打开
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
          ),
        ],
      ),
    );
  }

  // --- 以下 UI 代码保持不变，仅为了完整性列出 ---
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
              Text("我的笔记",
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Selector<NotesProvider, int>(
                selector: (_, provider) => provider.filteredNotes.length,
                builder: (_, count, __) => Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    "$count",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
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
                      }))),
          const SizedBox(width: 24),
          const SyncStatusIndicator(),
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
                  backgroundColor:
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  foregroundColor: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(width: 8),
          IconButton.filledTonal(
              onPressed: () => _showSortMenu(context),
              icon: const Icon(Icons.sort_rounded),
              tooltip: "排序",
              style: IconButton.styleFrom(
                  backgroundColor:
                  theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  foregroundColor: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(
      ThemeData theme, String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        backgroundColor:
        theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        selectedColor: theme.colorScheme.primaryContainer,
        labelStyle: TextStyle(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildEmptyState(
      ThemeData theme, bool isSearching, String? selectedCategory) {
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
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.outline),
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
            icon = Icon(Icons.cloud_off_rounded,
                color: theme.colorScheme.outlineVariant, size: 20);
            tooltip = "未登录，仅保存在本地";
            break;
          case SyncState.syncing:
            icon = SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: theme.colorScheme.primary),
            );
            tooltip = "正在与云端同步...";
            break;
          case SyncState.success:
            icon = const Icon(Icons.cloud_done_rounded,
                color: Colors.green, size: 20);
            tooltip = "已保存到云端";
            break;
          case SyncState.error:
            icon = Icon(Icons.cloud_off_rounded,
                color: theme.colorScheme.error, size: 20);
            tooltip = "同步失败，请检查网络";
            break;
          case SyncState.idle:
          default:
            icon = Icon(Icons.cloud_queue_rounded,
                color: theme.colorScheme.onSurfaceVariant, size: 20);
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
                  child: FadeTransition(opacity: animation, child: child));
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