import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🟢 引入 services 以使用快捷键
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/providers/notes_provider.dart';
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

  final List<Widget> _pages = const [
    NotesPage(),
    TodosPage(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        if (mounted) {
          context.read<NotesProvider>().syncWithCloud();
          context.read<TodosProvider>().syncWithCloud();
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _authStateSubscription?.cancel();
    super.dispose();
  }

  void _onNavigationChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController?.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onFabPressed() async {
    if (_currentIndex == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NoteEditorPage()),
      );
    } else if (_currentIndex == 1) {
      AppFeedback.selection();
      final result = await showCreateTodoDialog(context: context);

      if (result != null && mounted) {
        await context.read<TodosProvider>().addTodo(
          title: result.title,
          description: result.description,
          dueDate: result.dueDate,
        );
        AppFeedback.medium();
      }
    }
  }

  void _onSettingsTap() {
    Navigator.pushNamed(context, AppRoutes.settings);
  }

  void _onTrashTap() {
    Navigator.pushNamed(context, AppRoutes.trash);
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 包裹一层 CallbackShortcuts 实现全局快捷键
    return CallbackShortcuts(
      bindings: {
        // Ctrl + N (或 Cmd + N) 触发新建操作
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _onFabPressed,
      },
      child: Focus( // 添加一个 Focus 节点确保快捷键能被捕获
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 600;

            if (_wasDesktop != null && _wasDesktop != isDesktop) {
              _pageController?.dispose();
              _pageController = PageController(initialPage: _currentIndex);
            }
            _wasDesktop = isDesktop;

            if (!isDesktop) {
              return MainLayoutMobile(
                selectedIndex: _currentIndex,
                onDestinationSelected: _onNavigationChanged,
                body: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  physics: const BouncingScrollPhysics(),
                  children: _pages,
                ),
              );
            } else {
              return MainLayoutDesktop(
                selectedIndex: _currentIndex,
                onDestinationSelected: _onNavigationChanged,
                onFabPressed: _onFabPressed,
                onSettingsTap: _onSettingsTap,
                onTrashTap: _onTrashTap,
                body: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  physics: const NeverScrollableScrollPhysics(),
                  children: _pages,
                ),
              );
            }
          },
        ),
      ),
    );
  }
}