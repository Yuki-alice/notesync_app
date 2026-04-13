import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../init/app_initializer.dart';
import 'auth_provider.dart';
import 'theme_provider.dart';
import 'notes_provider.dart';
import 'todos_provider.dart';
import '../services/lan_sync_service.dart';

class GlobalProviders extends StatelessWidget {
  final Widget child;
  const GlobalProviders({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) => NotesProvider(
            AppInitializer.noteRepo,
            AppInitializer.categoryRepo,
            AppInitializer.tagRepo,
          ),
        ),
        ChangeNotifierProvider(create: (_) => TodosProvider(AppInitializer.todoRepo)),
        ChangeNotifierProvider(create: (_) => LanSyncService()),
      ],
      child: child,
    );
  }
}