import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:notesync_app/widgets/common/search_highlight_text.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:animations/animations.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../models/note.dart';
import '../../../../utils/app_feedback.dart';
import 'note_editor_page.dart';
import '../../../../core/services/image_storage_service.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final TextEditingController _searchController = TextEditingController();

  bool _isFabExtended = true;

  bool _handleScrollNotification(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.reverse) {
      if (_isFabExtended) setState(() => _isFabExtended = false);
    } else if (notification.direction == ScrollDirection.forward) {
      if (!_isFabExtended) setState(() => _isFabExtended = true);
    }
    return true;
  }

  void _openEditor(BuildContext context, {Note? note}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NoteEditorPage(note: note)),
    );
  }

  void _showStyleSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color:
                  isError ? theme.colorScheme.error : theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  color:
                      isError
                          ? theme.colorScheme.onErrorContainer
                          : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor:
            isError
                ? theme.colorScheme.errorContainer
                : theme.colorScheme.surfaceContainerHighest,
        elevation: 6,
        showCloseIcon: false,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<bool?> _confirmDelete(BuildContext context, Note note) async {
    final theme = Theme.of(context);
    return await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            icon: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_rounded,
                size: 32,
                color: theme.colorScheme.error,
              ),
            ),
            title: Text(
              '移入回收站?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            content: Text(
              '笔记 "${note.title.isEmpty ? '未命名' : note.title}" 将被移至回收站，\n你可以在那里随时还原。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text('移除'),
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }

  void _showNoteOptions(BuildContext context, Note note) {
    final theme = Theme.of(context);
    final provider = Provider.of<NotesProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha:0.3,),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.description,
                          color: theme.colorScheme.primary,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.title.isEmpty ? '无标题' : note.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                note.category ?? '未分类',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      provider.togglePin(note.id);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            note.isPinned
                                ? Icons.push_pin_outlined
                                : Icons.push_pin_rounded,
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            note.isPinned ? '取消置顶' : '置顶笔记',
                            style: TextStyle(
                              color: theme.colorScheme.onTertiaryContainer,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      _showMoveCategoryDialog(context, note);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.drive_file_move_rounded,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '移动到其他分类',
                            style: TextStyle(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      Navigator.pop(ctx);
                      final confirm = await _confirmDelete(context, note);
                      if (confirm == true) {
                        await provider.deleteNote(note.id);
                        if (context.mounted)
                          _showStyleSnackBar(context, '已移至回收站');
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withValues(alpha: 0.4,),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_rounded,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '删除笔记',
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
    );
  }

  void _showMoveCategoryDialog(BuildContext context, Note note) {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final categories = provider.categories;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
            title: const Text('移动到...'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.folder_off_outlined, size: 18),
                      label: const Text('未分类'),
                      onPressed: () async {
                        await provider.updateNote(
                          note.copyWith(clearCategory: true),
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          _showStyleSnackBar(context, '已移出分类');
                        }
                      },
                      backgroundColor: theme.colorScheme.surface,
                      side: BorderSide.none,
                      shape: const StadiumBorder(),
                    ),
                    ...categories.map((category) {
                      final isCurrent = note.category == category;
                      return FilterChip(
                        label: Text(category),
                        selected: isCurrent,
                        onSelected: (_) async {
                          await provider.updateNote(
                            note.copyWith(category: category),
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            _showStyleSnackBar(context, '已移动到 "$category"');
                          }
                        },
                        checkmarkColor: theme.colorScheme.onPrimaryContainer,
                        selectedColor: theme.colorScheme.primaryContainer,
                        backgroundColor: theme.colorScheme.surface,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
            ],
          ),
    );
  }

  void _showSortMenu(BuildContext context) {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final currentSort = provider.sortOption;
    final theme = Theme.of(context);

    showMenu<NoteSortOption>(
      context: context,
      position: const RelativeRect.fromLTRB(100, 80, 0, 0),
      items:
          NoteSortOption.values.map((option) {
            return PopupMenuItem(
              value: option,
              child: Row(
                children: [
                  Icon(
                    currentSort == option
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color:
                        currentSort == option
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    option.label,
                    style: TextStyle(
                      fontWeight:
                          currentSort == option
                              ? FontWeight.bold
                              : FontWeight.normal,
                      color:
                          currentSort == option
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ).then((value) {
      if (value != null) {
        provider.changeSortOption(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: NotificationListener<UserScrollNotification>(
        onNotification: _handleScrollNotification,
        child: SafeArea(
          child: Consumer<NotesProvider>(
            builder: (ctx, provider, _) {
              final notes = provider.filteredNotes;
              final categories = provider.categories;
              final selectedCategory = provider.selectedCategory;
              final searchQuery = provider.searchQuery;

              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    title: const Text(
                      '我的笔记',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    centerTitle: false,
                    backgroundColor: theme.colorScheme.surface,
                    surfaceTintColor: Colors.transparent,
                    floating: true,
                    pinned: true,
                    snap: true,
                    actions: [
                      IconButton(
                        onPressed: () => _showSortMenu(context),
                        icon: const Icon(Icons.sort_rounded),
                        tooltip: '排序',
                      ),
                      IconButton(
                        onPressed:
                            () => Navigator.pushNamed(context, AppRoutes.trash),
                        // 🟢 替换
                        icon: const Icon(Icons.auto_delete_outlined),
                        tooltip: '回收站',
                      ),
                      IconButton(
                        onPressed:
                            () => Navigator.pushNamed(
                              context,
                              AppRoutes.settings,
                            ),
                        // 🟢 替换
                        icon: const Icon(Icons.settings_rounded),
                        tooltip: '设置',
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      // 🟢 恢复本地 SearchBar
                      child: SearchBar(
                        controller: _searchController,
                        hintText: '搜索笔记...',
                        leading: const Icon(Icons.search_rounded),
                        elevation: WidgetStateProperty.all(0),
                        backgroundColor: WidgetStateProperty.all(
                          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5,),
                        ),

                        onChanged: (value) {
                          provider.setSearchQuery(value);
                        },

                        trailing:
                            _searchController.text.isNotEmpty
                                ? [
                                  IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                      provider.setSearchQuery('');
                                      AppFeedback.light();
                                    },
                                  ),
                                ]
                                : null,
                      ),
                    ),
                  ),

                  if (categories.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        height: 50,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: const Text('全部'),
                                selected: selectedCategory == null,
                                onSelected: (bool selected) {
                                  if (selected) provider.selectCategory(null);
                                },
                                showCheckmark: false,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                side: BorderSide.none,
                                backgroundColor: theme
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                selectedColor:
                                    theme.colorScheme.primaryContainer,
                                labelStyle: TextStyle(
                                  color:
                                      selectedCategory == null
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface,
                                  fontWeight:
                                      selectedCategory == null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                            ),
                            ...categories.map(
                              (category) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(category),
                                  selected: selectedCategory == category,
                                  onSelected: (bool selected) {
                                    provider.selectCategory(
                                      selected ? category : null,
                                    );
                                  },
                                  showCheckmark: false,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  side: BorderSide.none,
                                  backgroundColor: theme
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  selectedColor:
                                      theme.colorScheme.primaryContainer,
                                  labelStyle: TextStyle(
                                    color:
                                        selectedCategory == category
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurface,
                                    fontWeight:
                                        selectedCategory == category
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (notes.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.dashboard_customize_outlined,
                              size: 64,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              provider.searchQuery.isNotEmpty
                                  ? '未找到相关笔记'
                                  : (selectedCategory == null
                                      ? '暂无笔记'
                                      : '该分类下暂无笔记'),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: AnimationLimiter(
                        child: SliverMasonryGrid.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childCount: notes.length,
                          itemBuilder: (context, index) {
                            final note = notes[index];
                            return AnimationConfiguration.staggeredGrid(
                              position: index,
                              duration: const Duration(milliseconds: 375),
                              columnCount: 2,
                              child: ScaleAnimation(
                                scale: 0.9,
                                child: FadeInAnimation(
                                  child: OpenContainer(
                                    clipBehavior: Clip.antiAlias,

                                    transitionType:
                                        ContainerTransitionType.fadeThrough,

                                    // 🟢 闭合状态（卡片）样式
                                    closedShape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      // 加大一点圆角，效果更明显
                                      side: BorderSide(
                                        color: theme.colorScheme.outlineVariant
                                            .withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    closedElevation: 0,
                                    closedColor:
                                        theme.colorScheme.surfaceContainerLow,

                                    // 🟢 展开状态（编辑器）样式
                                    openShape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.zero,
                                    ),
                                    // 展开后变成直角
                                    openColor: theme.colorScheme.surface,
                                    // 确保背景色平滑过渡
                                    openElevation: 0,

                                    // 🟢 稍微调慢一点，让肉眼能看清“变圆”到“变方”的过程
                                    transitionDuration: const Duration(
                                      milliseconds: 600,
                                    ),

                                    // 打开的页面
                                    openBuilder:
                                        (context, _) =>
                                            NoteEditorPage(note: note),

                                    // 关闭的内容
                                    closedBuilder: (context, openContainer) {
                                      return _NoteGridCard(
                                        note: note,
                                        searchQuery: searchQuery,
                                        onTap: openContainer,
                                        onLongPress:
                                            () =>
                                                _showNoteOptions(context, note),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: OpenContainer(
        transitionType: ContainerTransitionType.fadeThrough,
        openBuilder: (BuildContext context, VoidCallback _) {
          return const NoteEditorPage();
        },
        closedElevation: 6.0,
        closedShape:
            _isFabExtended
                ? const StadiumBorder()
                : const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
        closedColor: theme.colorScheme.primaryContainer,
        transitionDuration: const Duration(milliseconds: 500),
        closedBuilder: (BuildContext context, VoidCallback openContainer) {
          return FloatingActionButton.extended(
            elevation: 0,
            onPressed: openContainer,
            backgroundColor: Colors.transparent,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            isExtended: _isFabExtended,
            label: const Text(
              '写笔记',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.edit_rounded),
          );
        },
      ),
    );
  }
}

class _NoteCoverImage extends StatelessWidget {
  final String imagePath;

  const _NoteCoverImage({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(imagePath);

    if (file.isAbsolute) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder:
            (_, __, ___) => Center(
              child: Icon(
                Icons.broken_image_rounded,
                color: theme.colorScheme.outline,
              ),
            ),
      );
    }

    return FutureBuilder<File?>(
      future: ImageStorageService().getLocalFile(imagePath),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.file(
            snapshot.data!,
            fit: BoxFit.cover,
            errorBuilder:
                (_, __, ___) => Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: theme.colorScheme.outline,
                  ),
                ),
          );
        }
        return Container(color: theme.colorScheme.surfaceContainerHighest);
      },
    );
  }
}

class _NoteGridCard extends StatelessWidget {
  final Note note;
  final String searchQuery;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NoteGridCard({
    super.key,
    required this.note,
    this.searchQuery = '',
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverImage = note.firstImagePath;
    final hasTitle = note.title.isNotEmpty;
    final hasContent = note.plainText.isNotEmpty;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      splashColor: theme.colorScheme.primary.withOpacity(0.1),
      // 这里的 InkWell 不需要圆角，因为它在 OpenContainer 内部，会被 OpenContainer 裁剪
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (coverImage != null)
            Hero(
              tag: 'note_cover_${note.id}',
              child: Container(
                height: 140,
                width: double.infinity,
                // 图片背景
                color: theme.colorScheme.surfaceContainerHighest,
                child: _NoteCoverImage(imagePath: coverImage),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasTitle) ...[
                  SearchHighlightText(
                    note.title,
                    query: searchQuery,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                ],

                if (hasContent) ...[
                  SearchHighlightText(
                    note.plainText,
                    query: searchQuery,
                    maxLines: coverImage != null ? 3 : 6,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (note.category != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(
                            0.6,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          note.category!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ...note.tags.take(2).map((tag) {
                      // 检查标签是否匹配搜索
                      final isMatch =
                          searchQuery.isNotEmpty &&
                          tag.toLowerCase().contains(searchQuery.toLowerCase());
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          // 如果匹配，给一个显眼的黄色背景
                          color:
                              isMatch
                                  ? const Color(0xFFFFF176)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '#$tag',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color:
                                isMatch
                                    ? Colors.black
                                    : theme.colorScheme.secondary, // 匹配时文字变黑
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      );
                    }),
                  ],
                ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      note.formattedUpdatedAt,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
