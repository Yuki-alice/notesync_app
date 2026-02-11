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

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onBottomNavTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400), // 🟢 稍微调慢一点，显得更优雅
      curve: Curves.fastOutSlowIn, // 🟢 使用更符合 Material 的曲线
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(), // 保持这个阻尼效果，体验很好
        children: _pages,
      ),

      // 🟢 升级 NavigationBar 样式
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onBottomNavTapped,
        backgroundColor: theme.colorScheme.surface, // 与背景融合
        indicatorColor: theme.colorScheme.secondaryContainer, // 选中指示器颜色
        height: 72, // 🟢 MD3 标准推荐高度 (默认80有点高，72更精致)
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow, // 总是显示标签
        elevation: 0, // 扁平化设计
        animationDuration: const Duration(milliseconds: 600), // 指示器切换动画时长
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description_rounded),
            label: '笔记',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt_rounded),
            label: '待办',
          ),
        ],
      ),
    );
  }
}