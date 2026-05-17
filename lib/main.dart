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
import 'core/services/network/network_service.dart';
import 'core/services/network/offline_queue.dart';
import 'core/widgets/splash_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const GlobalProviders(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await AppInitializer.init();
    await Future.wait([
      NetworkService().init(),
      OfflineQueue().init(),
    ]);
    if (mounted) {
      setState(() => _isInitializing = false);
    }
  }

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
      child: AnimatedTheme(
        data: isDarkMode
            ? AppTheme.getTheme(context: context, seedColor: themeProvider.themeColor, isDark: true)
            : AppTheme.getTheme(context: context, seedColor: themeProvider.themeColor, isDark: false),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        child: MaterialApp(
          title: 'Komorebi',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          home: _isInitializing
              ? SplashScreen(onAnimationComplete: _initializeApp)
              : const _HomePageWrapper(),
          theme: AppTheme.getTheme(context: context, seedColor: themeProvider.themeColor, isDark: false),
          darkTheme: AppTheme.getTheme(context: context, seedColor: themeProvider.themeColor, isDark: true),
          builder: (context, child) {
            final isDesktopOS = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
            if (!isDesktopOS) return child!;

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
                                  Text(
                                    'Komorebi',
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
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: FlutterQuillLocalizations.supportedLocales,
        ),
      ),
    );
  }
}

class _HomePageWrapper extends StatelessWidget {
  const _HomePageWrapper();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRoutes.home,
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
