import 'package:flutter/material.dart';

import '../features/notes/presentation/views/notes_page.dart';
import '../features/todos/presentation/views/todos_page.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // 页面列表
  final List<Widget> _pages = const [
    NotesPage(),
    TodosPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 🔴 这是一个纯净的脚手架，只负责底部导航
    // AppBar, FAB, Drawer 等都下放到了具体的 Page 中
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,

      // 使用 IndexedStack 保持页面状态（切换 tab 时不重绘）
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      // MD3 风格底部导航栏
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: theme.colorScheme.surface,
        indicatorColor: theme.colorScheme.secondaryContainer,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description_rounded),
            label: '笔记',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined), // 待办图标
            selectedIcon: Icon(Icons.task_alt_rounded),
            label: '待办',
          ),
        ],
      ),
    );
  }
}