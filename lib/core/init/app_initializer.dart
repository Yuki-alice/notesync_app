import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import '../database/simple_database_service.dart';
import '../repositories/category_repository.dart';
import '../repositories/note_repository.dart';
import '../repositories/tag_repository.dart';
import '../repositories/todo_repository.dart';
import '../constants/ui_constants.dart';
import '../services/security/privacy_service.dart';
import '../services/sync/supabase_sync_service.dart';
import '../theme/app_fonts.dart';

class AppInitializer {
  static late NoteRepository noteRepo;
  static late TodoRepository todoRepo;
  static late CategoryRepository categoryRepo;
  static late TagRepository tagRepo;

  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    await Future.wait([
      _initSupabase(supabaseUrl, supabaseAnonKey),
      _initDatabase(),
      AppFonts.preloadFonts(),
    ]);

    final dbService = SimpleDatabaseService();
    noteRepo = NoteRepository(dbService.isar);
    todoRepo = TodoRepository(dbService.isar);
    categoryRepo = CategoryRepository(dbService.isar);
    tagRepo = TagRepository(dbService.isar);

    PrivacyService().addOnUnlockListener(() async {
      debugPrint('🔐 AppInitializer: 隐私空间解锁，触发隐私图片同步');
      final syncService = SupabaseSyncService(noteRepo, todoRepo, categoryRepo, tagRepo);
      await syncService.syncPrivateImagesOnly();
    });

    _initDesktopWindow();
  }

  static Future<void> _initSupabase(String url, String anonKey) async {
    if (url.isEmpty || anonKey.isEmpty) {
      debugPrint('️ AppInitializer: Supabase 环境变量未配置，云端功能将不可用');
      return;
    }
    await Supabase.initialize(url: url, anonKey: anonKey);
    debugPrint('✅ AppInitializer: Supabase 初始化成功');
  }

  static Future<void> _initDatabase() async {
    final dbService = SimpleDatabaseService();
    await dbService.init();
    debugPrint('✅ AppInitializer: 数据库初始化成功');
  }

  static Future<void> _initDesktopWindow() async {
    if (kIsWeb || !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    final windowOptions = WindowOptions(
      size: const Size(UiConstants.desktopDefaultWidth, UiConstants.desktopDefaultHeight),
      minimumSize: const Size(UiConstants.desktopMinWidth, UiConstants.desktopMinHeight),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    debugPrint('✅ AppInitializer: 桌面窗口初始化成功');
  }
}
