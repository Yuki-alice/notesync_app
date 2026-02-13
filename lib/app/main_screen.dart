import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  // 🟢 改为可空，以便重建
  PageController? _pageController;

  // 🟢 新增：记录上一次的布局状态
  bool? _wasDesktop;

  final List<Widget> _pages = const [
    NotesPage(),
    TodosPage(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController?.dispose();
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // 判断当前是否为桌面模式
        final isDesktop = constraints.maxWidth >= 600;

        // 🟢 核心修复逻辑：
        // 如果布局模式发生了变化（从桌面切到手机，或反之），
        // 销毁旧控制器，创建新控制器，并强制 initialPage 为当前页面索引。
        if (_wasDesktop != null && _wasDesktop != isDesktop) {
          _pageController?.dispose();
          _pageController = PageController(initialPage: _currentIndex);
        }
        _wasDesktop = isDesktop; // 更新状态记录

        if (!isDesktop) {
          // --- 手机模式 ---
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
          // --- 桌面模式 ---
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
    );
  }
}