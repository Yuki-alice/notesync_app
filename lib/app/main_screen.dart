import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers/auth_provider.dart';
import '../core/providers/notes_provider.dart';
import '../core/providers/theme_provider.dart';
import '../features/notes/presentation/views/notes_page.dart';
import '../features/todos/presentation/views/todos_page.dart';
import '../features/notes/presentation/views/note_editor_page.dart';
import '../widgets/common/dialogs/create_todo_dialog.dart';
import 'layouts/main_layout_mobile.dart';
import 'layouts/main_layout_desktop.dart';
import '../core/routes/app_routes.dart';
import '../core/providers/todos_provider.dart';
import '../utils/app_feedback.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  PageController? _pageController;
  bool? _wasDesktop;
  StreamSubscription<AuthState>? _authStateSubscription;

  // 🌟 新增：持久化引用 AuthProvider 以便精确监听
  late AuthProvider _authProvider;

  final List<Widget> _pages = const [
    NotesPage(),
    TodosPage(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);

    // 🌟 核心修复 1：挂载监听器
    _authProvider = context.read<AuthProvider>();
    _authProvider.addListener(_onAuthChanged);

    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        if (mounted) {
          // 登录成功时，只触发笔记和待办的同步
          context.read<NotesProvider>().syncWithCloud();
          context.read<TodosProvider>().syncWithCloud();
        }
      }
    });

    // 🌟 首次启动兜底检查
    _checkAndPullSettings();
  }

  // 🌟 核心修复 2：当 AuthProvider 数据刷新完成时，精确触发漫游对齐
  void _onAuthChanged() {
    _checkAndPullSettings();
  }

  void _checkAndPullSettings() {
    // 必须等待 authProvider 真正从数据库拿到了 cloudSettings 字典后，再通知主题引擎对齐！
    if (_authProvider.isAuthenticated && _authProvider.cloudSettings.isNotEmpty) {
      context.read<ThemeProvider>().tryPullSettingsFromCloud(_authProvider);
    }
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged); // 🌟 别忘了注销监听，防止内存泄漏
    _pageController?.dispose();
    _authStateSubscription?.cancel();
    super.dispose();
  }

  void _onNavigationChanged(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.lightImpact();

    setState(() {
      _currentIndex = index;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _pageController?.animateToPage(
          index,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _onPageChanged(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  void _onFabPressed() async {
    if (_currentIndex == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NoteEditorPage()),
      );
    } else if (_currentIndex == 1) {
      AppFeedback.selection();
      final result = await showAppCreateTodoDialog(context);

      if (result != null && mounted) {
        await context.read<TodosProvider>().addTodo(
          title: result.title,
          description: '',
          dueDate: result.dueDate,
          subTasks: result.subTasks,
        );
        AppFeedback.medium();
      }
    }
  }

  void _onSettingsTap() => Navigator.pushNamed(context, AppRoutes.settings);
  void _onTrashTap() => Navigator.pushNamed(context, AppRoutes.trash);

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _onFabPressed,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 600;

            if (_wasDesktop != null && _wasDesktop != isDesktop) {
              _pageController?.dispose();
              _pageController = PageController(initialPage: _currentIndex);
            }
            _wasDesktop = isDesktop;

            final body = PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const BouncingScrollPhysics(),
              children: _pages,
            );

            if (!isDesktop) {
              return MainLayoutMobile(
                selectedIndex: _currentIndex,
                onDestinationSelected: _onNavigationChanged,
                body: body,
              );
            } else {
              return MainLayoutDesktop(
                selectedIndex: _currentIndex,
                onDestinationSelected: _onNavigationChanged,
                onFabPressed: _onFabPressed,
                onSettingsTap: _onSettingsTap,
                onTrashTap: _onTrashTap,
                body: body,
              );
            }
          },
        ),
      ),
    );
  }
}