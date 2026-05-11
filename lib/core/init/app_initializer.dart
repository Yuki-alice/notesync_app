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
import '../services/backup/data_migration_service.dart';
import '../theme/app_fonts.dart';

class AppInitializer {
  // 全局提供 Repository 实例
  static late NoteRepository noteRepo;
  static late TodoRepository todoRepo;
  static late CategoryRepository categoryRepo;
  static late TagRepository tagRepo;

  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. 系统 UI 样式初始化
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    // 2. Supabase 云端初始化（从环境变量读取配置）
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      debugPrint('⚠️ AppInitializer: Supabase 环境变量未配置，云端功能将不可用');
    } else {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      debugPrint('✅ AppInitializer: Supabase 初始化成功');
    }

    // 3. 检查是否需要数据迁移（从旧包名迁移）
    // 注意：需要在数据库初始化前检查，因为迁移会操作数据库文件
    final needsMigration = await DataMigrationService.needsMigration();
    if (needsMigration) {
      debugPrint('📦 AppInitializer: 检测到需要数据迁移');
      // 迁移将在 main.dart 中显示对话框后执行
    }

    // 4. 本地 Isar 数据库初始化
    final dbService = SimpleDatabaseService();
    await dbService.init();

    // 5. 预加载字体（避免首次使用时的网络请求卡顿）
    await AppFonts.preloadFonts();
    debugPrint('✅ AppInitializer: 字体预加载完成');

    // 6. 桌面端窗口初始化
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      await windowManager.ensureInitialized();
      WindowOptions windowOptions = WindowOptions(
        size: const Size(UiConstants.desktopDefaultWidth, UiConstants.desktopDefaultHeight),
        minimumSize: const Size(UiConstants.desktopMinWidth, UiConstants.desktopMinHeight),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }

    // 7. 实例化数据仓库
    noteRepo = NoteRepository(dbService.isar);
    todoRepo = TodoRepository(dbService.isar);
    categoryRepo = CategoryRepository(dbService.isar);
    tagRepo = TagRepository(dbService.isar);

    // 8. 注册隐私空间解锁回调 - 解锁时触发隐私图片同步
    PrivacyService().addOnUnlockListener(() async {
      debugPrint('🔐 AppInitializer: 隐私空间解锁，触发隐私图片同步');
      final syncService = SupabaseSyncService(noteRepo, todoRepo, categoryRepo, tagRepo);
      await syncService.syncPrivateImagesOnly();
    });
  }
}