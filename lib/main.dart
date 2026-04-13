import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:window_manager/window_manager.dart';

import 'core/init/app_initializer.dart';
import 'core/providers/global_providers.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_routes.dart';
import 'core/routes/app_router.dart';

void main() async {
  try {
    // 1. 执行全局底层初始化 (数据库、云端、窗口)
    await AppInitializer.init();

    // 2. 注入全局 Provider 并运行 App
    runApp(const GlobalProviders(child: MyApp()));
  } catch (e) {
    runApp(ErrorApp(error: e.toString()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    final isDarkMode = themeProvider.themeMode == ThemeMode.dark ||
        (themeProvider.themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      ),
      child: MaterialApp(
        title: 'NoteSync',
        debugShowCheckedModeBanner: false,
        themeMode: themeProvider.themeMode,
        initialRoute: AppRoutes.home,
        onGenerateRoute: AppRouter.onGenerateRoute,

        // 生成深浅两套解耦的主题
        theme: AppTheme.getTheme(context: context, seedColor: themeProvider.themeColor, isDark: false),
        darkTheme: AppTheme.getTheme(context: context, seedColor: themeProvider.themeColor, isDark: true),

        // 全局窗口包裹器：为桌面端统一添加控制栏
        builder: (context, child) {
          final isDesktopOS = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
          if (!isDesktopOS) return child!; // 手机平板直接原样返回

          final theme = Theme.of(context);
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            body: Column(
              children: [
                SizedBox(
                  height: 38,
                  child: Row(
                    children: [
                      Expanded(
                        child: DragToMoveArea(
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.only(left: 16),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Icon(Icons.auto_awesome_rounded, size: 16, color: theme.colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'NoteSync',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (!Platform.isMacOS)
                        SizedBox(
                          width: 138,
                          child: WindowCaption(brightness: theme.brightness, backgroundColor: Colors.transparent),
                        ),
                    ],
                  ),
                ),
                Expanded(child: ClipRect(child: child!)),
              ],
            ),
          );
        },

        // 国际化支持
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: FlutterQuillLocalizations.supportedLocales,
      ),
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
                const Icon(Icons.error_outline_rounded, size: 64, color: Colors.white),
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