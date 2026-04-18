import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import '../database/simple_database_service.dart';
import '../repositories/category_repository.dart';
import '../repositories/note_repository.dart';
import '../repositories/tag_repository.dart';
import '../repositories/todo_repository.dart';
import '../services/privacy_service.dart';
import '../services/supabase_sync_service.dart';

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

    // 2. Supabase 云端初始化
    await Supabase.initialize(
      url: 'https://mauzvvakcqqhrcphcgmf.supabase.co',
      anonKey: 'sb_publishable_8HmK4iGLBFj3hk2GJ9a1Xw_yDHC6rPj',
    );

    // 3. 本地 Isar 数据库初始化
    final dbService = SimpleDatabaseService();
    await dbService.init();

    // 4. 桌面端窗口初始化
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      await windowManager.ensureInitialized();
      WindowOptions windowOptions = const WindowOptions(
        size: Size(1024, 768),
        minimumSize: Size(360, 600),
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

    // 5. 实例化数据仓库
    noteRepo = NoteRepository(dbService.isar);
    todoRepo = TodoRepository(dbService.isar);
    categoryRepo = CategoryRepository(dbService.isar);
    tagRepo = TagRepository(dbService.isar);

    // 6. 注册隐私空间解锁回调 - 解锁时触发隐私图片同步
    PrivacyService().addOnUnlockListener(() async {
      debugPrint('🔐 AppInitializer: 隐私空间解锁，触发隐私图片同步');
      final syncService = SupabaseSyncService(noteRepo, todoRepo, categoryRepo, tagRepo);
      await syncService.syncPrivateImagesOnly();
    });
  }
}