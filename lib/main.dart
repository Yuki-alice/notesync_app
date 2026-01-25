import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 1. 引入这个
import 'package:flutter_quill/flutter_quill.dart'; // 2. 引入这个 (用于 FlutterQuillLocalizations)
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

  try {
    await Hive.initFlutter();
    Hive.registerAdapter(NoteAdapter());
    Hive.registerAdapter(TodoAdapter());

    Box<Note> noteBox;
    Box<Todo> todoBox;

    try {
      noteBox = await Hive.openBox<Note>('notes');
    } catch (e) {
      await Hive.deleteBoxFromDisk('notes');
      noteBox = await Hive.openBox<Note>('notes');
    }

    try {
      todoBox = await Hive.openBox<Todo>('todos');
    } catch (e) {
      await Hive.deleteBoxFromDisk('todos');
      todoBox = await Hive.openBox<Todo>('todos');
    }

    final noteRepo = NoteRepository(noteBox);
    final todoRepo = TodoRepository(todoBox);

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
  } catch (e, stack) {
    debugPrint('❌ 启动严重错误: $e');
    runApp(ErrorApp(error: e.toString(), stack: stack.toString()));
  }
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

      // 3. 🔴 添加本地化代理配置
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate, // 关键：Quill 的本地化
      ],
      // 4. 🔴 支持的语言
      supportedLocales: FlutterQuillLocalizations.supportedLocales,

      home: const MainScreen(),
    );
  }
}

// ErrorApp 类保持不变...
class ErrorApp extends StatelessWidget {
  final String error;
  final String stack;
  const ErrorApp({super.key, required this.error, required this.stack});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: Text("Error: $error")),
      ),
    );
  }
}