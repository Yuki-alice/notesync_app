import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

class TrayService {
  static final TrayService _instance = TrayService._internal();
  factory TrayService() => _instance;
  TrayService._internal();

  final SystemTray _systemTray = SystemTray();
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      await _systemTray.initSystemTray(
        title: 'Komorebi',
        iconPath: _getTrayIconPath(),
        toolTip: 'Komorebi - 光隙笔记',
      );

      final menu = [
        MenuItem(
          label: '打开主窗口',
          onClicked: _showWindow,
        ),
        MenuSeparator(),
        MenuItem(
          label: '退出',
          onClicked: _exitApp,
        ),
      ];

      await _systemTray.setContextMenu(menu);

      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == 'leftMouseUp') {
          _showWindow();
        } else if (eventName == 'rightMouseUp') {
          _systemTray.popUpContextMenu();
        }
      });

      _initialized = true;
      debugPrint('✅ TrayService: 系统托盘初始化成功');
    }
  }

  String _getTrayIconPath() {
    if (Platform.isWindows) {
      return 'assets/icons/windows/app_icon.ico';
    }
    return 'assets/icons/komorebi_icon_1024.png';
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _exitApp() async {
    await windowManager.setPreventClose(false);
    await windowManager.close();
    exit(0);
  }

  Future<void> dispose() async {
    if (_initialized) {
      _initialized = false;
    }
  }
}
