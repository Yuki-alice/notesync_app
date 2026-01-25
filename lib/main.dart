import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/providers/app_providers.dart';
import 'core/repositories/note_repository.dart';
import 'core/repositories/todo_repository.dart';
import 'app/main_screen.dart';
import 'models/note.dart';
import 'models/todo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化Hive
  await Hive.initFlutter();
  Hive.registerAdapter(NoteAdapter());
  Hive.registerAdapter(TodoAdapter());

  // 初始化仓库
  final noteRepo = NoteRepository();
  final todoRepo = TodoRepository();

  runApp(
    MultiProvider(
      providers: [
        // 主题提供者
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // 笔记提供者
        ChangeNotifierProvider(
          create: (_) => NotesProvider(noteRepo),
        ),
        // 待办提供者
        ChangeNotifierProvider(
          create: (_) => TodosProvider(todoRepo),
        ),
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
      home: const MainScreen(),
    );
  }
}