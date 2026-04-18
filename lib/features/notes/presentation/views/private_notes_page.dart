import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:animations/animations.dart';

import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/privacy_mode_provider.dart';
import '../../../../core/services/privacy_service.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../utils/app_feedback.dart';
import '../../../../utils/toast_utils.dart';
import '../../../../widgets/common/dialogs/add_category_dialog.dart';
import '../../../../widgets/common/dialogs/privacy_unlock_dialog.dart';
import 'note_editor_page.dart';
import '../widgets/note_card.dart';
import '../widgets/dialogs/note_options_sheet.dart';
import '../widgets/note_search_bar.dart';

/// 隐私笔记页面
/// 
/// 独立的隐私笔记空间，进入需要解锁
/// 样式与 NotesPage 保持一致
class PrivateNotesPage extends StatefulWidget {
  const PrivateNotesPage({super.key});

  @override
  State<PrivateNotesPage> createState() => _PrivateNotesPageState();
}

class _PrivateNotesPageState extends State<PrivateNotesPage> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  bool _isUnlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 🌟 页面加载时只检查是否已解锁，不自动弹窗
    _checkInitialUnlockStatus();
  }

  /// 🌟 初始状态检查 - 只检查是否已解锁，不自动弹窗
  Future<void> _checkInitialUnlockStatus() async {
    final privacy = PrivacyService();
    
    // 如果已经解锁，刷新笔记并显示
    if (privacy.isUnlocked) {
      await context.read<NotesProvider>().loadNotes();
      if (mounted) {
        setState(() => _isUnlocked = true);
      }
    }
    // 如果未解锁，保持锁定状态显示，等待用户点击"解锁"按钮
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当应用从后台回到前台时刷新笔记
    if (state == AppLifecycleState.resumed && _isUnlocked) {
      context.read<NotesProvider>().loadNotes();
    }
  }

  /// 检查解锁状态 - 与电脑端逻辑保持一致
  Future<void> _checkUnlockStatus() async {
    final privacy = PrivacyService();

    // 如果已经解锁，刷新笔记并显示
    if (privacy.isUnlocked) {
      await context.read<NotesProvider>().loadNotes();
      setState(() => _isUnlocked = true);
      return;
    }

    // 如果未设置密码，引导设置密码
    if (!await privacy.hasPassword()) {
      if (!mounted) return;
      final result = await showPrivacySetupDialog(context);
      if (result && mounted) {
        await context.read<NotesProvider>().loadNotes();
        setState(() => _isUnlocked = true);
        context.read<PrivacyModeProvider>().enterPrivateModeDirect();
      }
      return;
    }

    // 已设置密码，需要解锁
    if (!mounted) return;
    final unlocked = await showPrivacyUnlockDialog(context);
    if (unlocked && mounted) {
      // 🌟 解锁成功后刷新笔记，解密隐私笔记内容
      await context.read<NotesProvider>().loadNotes();
      setState(() => _isUnlocked = true);
      // 更新全局隐私模式状态
      context.read<PrivacyModeProvider>().enterPrivateModeDirect();
    }
  }

  /// 重新锁定
  void _lockAndExit() {
    PrivacyService().lock();
    context.read<PrivacyModeProvider>().exitPrivateMode();
    Navigator.pop(context);
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
                    ? theme.colorScheme.error
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
                child: !_isUnlocked
                    ? _buildLockedState(theme)
                    : _buildMainContent(context, theme, isDesktop),
              ),
            ],
          ),
        ),
        floatingActionButton: isDesktop || !_isUnlocked
            ? null
            : _buildMobileFAB(),
      ),
    );
  }

  /// 锁定状态显示 - 与电脑端一致，添加修改密码功能
  Widget _buildLockedState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline,
              size: 40,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '隐私空间已锁定',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '需要验证身份才能访问',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _checkUnlockStatus,
            icon: const Icon(Icons.lock_open),
            label: const Text('解锁'),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          // 🌟 添加修改密码按钮
          FutureBuilder<bool>(
            future: PrivacyService().hasPassword(),
            builder: (context, snapshot) {
              if (snapshot.data == true) {
                return TextButton.icon(
                  onPressed: _showChangePasswordDialog,
                  icon: Icon(
                    Icons.key,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  label: Text(
                    '修改密码',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  /// 🌟 显示修改密码对话框
  Future<void> _showChangePasswordDialog() async {
    final privacy = PrivacyService();
    
    // 先验证旧密码
    final unlocked = await showPrivacyUnlockDialog(context);
    if (!unlocked || !mounted) return;

    // 显示修改密码对话框
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ChangePasswordDialog(
        onSuccess: () {
          // 修改成功后保持解锁状态
          setState(() => _isUnlocked = true);
          context.read<PrivacyModeProvider>().enterPrivateModeDirect();
        },
      ),
    );
  }

  /// 构建手机端 FAB
  Widget _buildMobileFAB() {
    return Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 100),
      child: OpenContainer(
        transitionType: ContainerTransitionType.fadeThrough,
        openBuilder: (BuildContext context, VoidCallback _) =>
            const NoteEditorPage(isPrivate: true),
        closedElevation: 4.0,
        closedShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
        closedColor: Theme.of(context).colorScheme.errorContainer,
        transitionDuration: const Duration(milliseconds: 500),
        closedBuilder: (BuildContext context, VoidCallback openContainer) {
          return SizedBox(
            width: 56,
            height: 56,
            child: FloatingActionButton(
              elevation: 0,
              onPressed: openContainer,
              backgroundColor: Colors.transparent,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              child: const Icon(
                Icons.lock,
                size: 28,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, ThemeData theme, bool isDesktop) {
    return Consumer<NotesProvider>(
      builder: (context, provider, _) {
        // 只显示隐私笔记
        final notes = provider.filteredNotes.where((n) => n.isPrivate).toList();
        final currentKey = '${provider.selectedCategoryId}_${provider.searchQuery}_private';

        List<Widget> slivers = [];

        if (!isDesktop) {
          slivers.add(
              SliverAppBar(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock,
                      color: theme.colorScheme.error,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '隐私笔记',
                      style: TextStyle(
                        fontWeight: FontWeight.w800, 
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.95),
                surfaceTintColor: Colors.transparent,
                pinned: false,
                floating: true,
                snap: true,
                shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.1),
                leading: IconButton(
                  onPressed: _lockAndExit,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: '退出并锁定',
                ),
                actions: [
                  IconButton(
                    onPressed: () => _showSortMenu(context), 
                    icon: const Icon(Icons.sort_rounded),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.settings), 
                    icon: const Icon(Icons.settings_outlined),
                  ),
                  const SizedBox(width: 8),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(60),
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
                          hintText: '搜索隐私笔记...',
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
                  child: _buildEmptyState(theme, provider.searchQuery.isNotEmpty),
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
                                    color: theme.colorScheme.error.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                closedElevation: 0,
                                closedColor: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                                openShape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                openColor: theme.colorScheme.surface,
                                openElevation: 0,
                                transitionDuration: const Duration(milliseconds: 600),
                                openBuilder: (context, _) => NoteEditorPage(note: note, isPrivate: true),
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
              IconButton(
                onPressed: _lockAndExit,
                icon: const Icon(Icons.arrow_back),
                tooltip: '退出并锁定',
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.lock,
                color: theme.colorScheme.error,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                  "隐私笔记",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.error,
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
                  hintText: '搜索隐私笔记...',
                ),
              ),

              const SizedBox(width: 16),
              _SyncStatusIndicator(),
              IconButton(
                onPressed: () async {
                  await context.read<NotesProvider>().syncWithCloud();
                  if (context.mounted) ToastUtils.showSuccess(context, '已与云端同步最新数据');
                },
                icon: const Icon(Icons.sync_rounded, size: 22),
                tooltip: "同步",
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showSortMenu(context),
                icon: const Icon(Icons.sort_rounded, size: 22),
                tooltip: "排序",
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NoteEditorPage(isPrivate: true),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('新建隐私笔记'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isSearching) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 64, 
            color: theme.colorScheme.error.withValues(alpha: 0.5)
          ),
          const SizedBox(height: 16),
          Text(
            isSearching
                ? '未找到相关隐私笔记'
                : '暂无私密笔记',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.error.withValues(alpha: 0.7),
            ),
          ),
          if (!isSearching) ...[
            const SizedBox(height: 8),
            Text(
              '点击 + 创建私密笔记',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 同步状态指示器（隐私模式样式）
class _SyncStatusIndicator extends StatelessWidget {
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
              child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.error),
            );
            tooltip = "正在与云端同步...";
            break;
          case SyncState.success:
            icon = Icon(Icons.cloud_done_rounded, color: theme.colorScheme.error, size: 20);
            tooltip = "已保存到云端";
            break;
          case SyncState.error:
            icon = Icon(Icons.cloud_off_rounded, color: theme.colorScheme.error, size: 20);
            tooltip = "同步失败，请检查网络";
            break;
          case SyncState.idle:
          default:
            icon = Icon(Icons.cloud_queue_rounded, color: theme.colorScheme.error.withValues(alpha: 0.7), size: 20);
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

/// 🌟 修改密码对话框
class _ChangePasswordDialog extends StatefulWidget {
  final VoidCallback onSuccess;

  const _ChangePasswordDialog({required this.onSuccess});

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty) {
      setState(() => _errorText = '请输入新密码');
      return;
    }

    if (newPassword.length < 4) {
      setState(() => _errorText = '密码至少4位');
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _errorText = '两次输入的密码不一致');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      // 需要先锁定再重新设置密码
      PrivacyService().lock();
      await PrivacyService().setupPassword(newPassword);

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ToastUtils.showSuccess(context, '密码修改成功');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorText = '修改密码失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.key, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          const Text('修改密码'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '请输入新密码',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _newPasswordController,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: '新密码',
              hintText: '至少4位',
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              errorText: _errorText,
            ),
            onSubmitted: (_) => _changePassword(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: '确认密码',
              hintText: '再次输入新密码',
              prefixIcon: const Icon(Icons.lock_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) => _changePassword(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _changePassword,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('确认修改'),
        ),
      ],
    );
  }
}
