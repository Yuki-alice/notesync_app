import 'package:flutter/material.dart';
import 'package:notesync_app/features/auth/presentation/views/login_page.dart';

import '../../app/main_screen.dart';
import '../../features/search/presentation/views/global_search_page.dart';
import '../../features/settings/presentation/views/settings_page.dart';
import '../../features/settings/presentation/views/category_management_page.dart';
import '../../features/trash/presentation/views/trash_page.dart';
import '../../features/notes/presentation/views/note_editor_page.dart';
import '../../models/note.dart';
import 'app_routes.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    // 获取参数
    final args = settings.arguments;

    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute(
          builder: (_) => const MainScreen(),
          settings: settings,
        );

      case AppRoutes.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsPage(),
          settings: settings,
        );

      case AppRoutes.login:
        return MaterialPageRoute(
          builder: (_) => const LoginPage(),
          settings: settings,
        );

      case AppRoutes.categories:
        return MaterialPageRoute(
          builder: (_) => const CategoryManagementPage(),
          settings: settings,
        );

      case AppRoutes.trash:
        return MaterialPageRoute(
          builder: (_) => const TrashPage(),
          settings: settings,
        );

      case AppRoutes.noteEditor:
        // 如果传递了 Note 对象，则进入编辑模式；否则进入新建模式
        final note = (args is Note) ? args : null;
        return MaterialPageRoute(
          builder: (_) => NoteEditorPage(note: note),
          settings: settings,
        );

      default:
        return _errorRoute();
    }
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(
      builder: (_) {
        return Scaffold(
          appBar: AppBar(title: const Text('出错了')),
          body: const Center(child: Text('页面未找到')),
        );
      },
    );
  }
}
