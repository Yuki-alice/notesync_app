import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'core/database/simple_database_service.dart';
import 'core/providers/app_providers.dart';
import 'core/repositories/note_repository.dart';
import 'core/repositories/todo_repository.dart';
import 'app/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化数据库服务
  final dbService = SimpleDatabaseService();

  try {
    await dbService.init();
  } catch (e) {
    // 如果数据库遭遇无法修复的错误，启动错误页面
    runApp(ErrorApp(error: e.toString()));
    return;
  }

  // 2. 注入依赖
  // 使用 dbService 提供的 Box 实例来创建 Repository
  final noteRepo = NoteRepository(dbService.noteBox);
  final todoRepo = TodoRepository(dbService.todoBox);

  // 3. 启动应用
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NotesProvider(noteRepo)),
        ChangeNotifierProvider(create: (_) => TodosProvider(todoRepo)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: '笔记同步',
      theme: themeProvider.currentTheme,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: FlutterQuillLocalizations.supportedLocales,
      home: const MainScreen(),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red[50],
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  "应用启动失败",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 8),
                Text(
                  "本地数据库发生严重错误，请尝试重装应用。\n\n技术细节:\n$error",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.brown),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}