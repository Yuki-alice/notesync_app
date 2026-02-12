import 'package:flutter/material.dart';
import 'package:notesync_app/widgets/common/dialogs/create_todo_dialog.dart';
import 'package:provider/provider.dart';
import '../features/notes/presentation/views/note_editor_page.dart';
import '../features/notes/presentation/views/notes_page.dart';
import '../features/todos/presentation/views/todos_page.dart';
import '../utils/app_feedback.dart';
import 'layouts/main_layout_desktop.dart';
import 'layouts/main_layout_mobile.dart';
import '../core/routes/app_routes.dart';
import '../core/providers/todos_provider.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late PageController _pageController;

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
    _pageController.dispose();
    super.dispose();
  }

  // 统一的页面切换逻辑：无论是点击底部导航还是侧边栏，都走这里
  void _onNavigationChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onFabPressed() async{
    if (_currentIndex == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const NoteEditorPage()),
      );
    } else if (_currentIndex == 1) {
      AppFeedback.selection();

      final result = await showCreateTodoDialog(
        context: context,);
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
        if (constraints.maxWidth < 600) {
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
    );
  }
}