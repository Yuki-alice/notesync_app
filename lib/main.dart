import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'; // 保持 Quill 本地化
import 'core/providers/app_providers.dart';
import 'core/repositories/note_repository.dart';
import 'core/repositories/todo_repository.dart';
import 'app/main_screen.dart';
import 'models/note.dart';
import 'models/todo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive 初始化
  await Hive.initFlutter();
  Hive.registerAdapter(NoteAdapter());
  Hive.registerAdapter(TodoAdapter());

  Box<Note> noteBox;
  Box<Todo> todoBox;

  // 容错打开 Box
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