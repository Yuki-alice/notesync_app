import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:window_manager/window_manager.dart';
import 'core/database/simple_database_service.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/notes_provider.dart';
import 'core/providers/todos_provider.dart';
import 'core/repositories/note_repository.dart';
import 'core/repositories/todo_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/routes/app_routes.dart';
import 'core/routes/app_router.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // 状态栏背景全透明
      statusBarIconBrightness: Brightness.dark, // 状态栏图标和字体设为深色
    ),
  );
  //初始化 Supabase
  await Supabase.initialize(
    url: 'https://mauzvvakcqqhrcphcgmf.supabase.co',
    anonKey: 'sb_publishable_8HmK4iGLBFj3hk2GJ9a1Xw_yDHC6rPj',
  );

  // 1. 初始化数据库
  final dbService = SimpleDatabaseService();

  try {
    await dbService.init();
  } catch (e) {
    runApp(ErrorApp(error: e.toString()));
    return;
  }


  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1024, 768),
      minimumSize: Size(400, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final noteRepo = NoteRepository(dbService.noteBox);
  final todoRepo = TodoRepository(dbService.todoBox);

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
    final seedColor = themeProvider.themeColor;
    final textTheme =GoogleFonts.notoSansScTextTheme(Theme.of(context).textTheme);

    return MaterialApp(
      title: '笔记同步',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,

      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRouter.onGenerateRoute,


      theme: ThemeData(
        textTheme: textTheme,
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
          surfaceTint: seedColor.withValues(alpha: 0.05),
        ),
        scaffoldBackgroundColor: const Color(0xFFFDFDFD),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),

      darkTheme: ThemeData(
        textTheme: textTheme,
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
          surfaceTint: seedColor.withValues(alpha: 0.1),
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1C1E),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: FlutterQuillLocalizations.supportedLocales,
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
        backgroundColor: Colors.red[900],
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                const Text("应用启动失败", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text("错误详情:\n$error", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}