import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/todos_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../utils/toast_utils.dart';
import 'webdav_config_page.dart';

class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({super.key});

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  bool _isAutoSync = false;
  String _syncMode = 'supabase';

  @override
  void initState() {
    super.initState();
    _loadSyncSettings();
  }

  Future<void> _loadSyncSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAutoSync = prefs.getBool('isAutoSyncEnabled') ?? false;
      _syncMode = prefs.getString('sync_mode') ?? 'supabase';
    });
  }

  Future<void> _toggleMasterSwitch(bool value) async {
    setState(() => _isAutoSync = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAutoSyncEnabled', value);

    if (!mounted) return;
    if (value) {
      ToastUtils.showSuccess(context, '云端同步已开启');
      context.read<NotesProvider>().syncWithCloud();
      context.read<TodosProvider>().syncWithCloud();
    } else {
      ToastUtils.showInfo(context, '同步已关闭，数据仅保留在本地');
      context.read<NotesProvider>().clearTimers();
      context.read<TodosProvider>().clearTimers();
    }
  }

  Future<void> _changeSyncMode(String mode) async {
    setState(() => _syncMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_mode', mode);

    if (!mounted) return;
    ToastUtils.showSuccess(context, '已切换至 ${mode == 'supabase' ? '官方云' : 'WebDAV'} 同步');
    if (_isAutoSync) context.read<NotesProvider>().syncWithCloud();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('云端同步', style: GoogleFonts.notoSans(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          // ==========================================
          // 🌟 1. 数据同步总闸
          // ==========================================
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              value: _isAutoSync,
              onChanged: _toggleMasterSwitch,
              title: Text('开启自动同步', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface, fontSize: 16)),
              subtitle: Text('后台静默同步笔记与待办，跨设备随时访问', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
              secondary: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(Icons.cloud_sync_rounded, color: theme.colorScheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // ==========================================
          // 🌟 2. 引擎选择 (受总闸控制)
          // ==========================================
          IgnorePointer(
            ignoring: !_isAutoSync,
            child: Opacity(
              opacity: _isAutoSync ? 1.0 : 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 12),
                    child: Text('同步引擎配置', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('选择你的数据保险箱', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                              const SizedBox(height: 16),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(value: 'supabase', label: Text('官方云'), icon: Icon(Icons.cloud_done_outlined)),
                                  ButtonSegment(value: 'webdav', label: Text('私有云 (BYOD)'), icon: Icon(Icons.dns_outlined)),
                                ],
                                selected: {_syncMode},
                                onSelectionChanged: (set) => _changeSyncMode(set.first),
                                showSelectedIcon: false,
                                style: SegmentedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  selectedBackgroundColor: theme.colorScheme.primaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // WebDAV 配置入口
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                          child: _syncMode == 'webdav' ? Column(
                            children: [
                              Divider(height: 1, indent: 20, endIndent: 20, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                              ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                title: Text('配置 WebDAV 服务器', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                                subtitle: Text('接入坚果云、NAS 等', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                                leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, shape: BoxShape.circle), child: Icon(Icons.storage_rounded, color: theme.colorScheme.onSecondaryContainer, size: 20)),
                                trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WebDavConfigPage())),
                              ),
                            ],
                          ) : const SizedBox.shrink(),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ==========================================
          // 🌟 3. 个性化偏好漫游 (利用 UserProfiles jsonb 引擎)
          // ==========================================
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text('应用偏好', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(24), border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
            child: Consumer2<ThemeProvider, AuthProvider>(
                builder: (context, themeProvider, authProvider, child) {
                  final isAuth = authProvider.isAuthenticated;

                  return SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    value: themeProvider.syncSettingsToCloud,
                    // 如果未登录，直接禁用开关
                    onChanged: isAuth ? (value) {
                      themeProvider.toggleSyncSettings(value, authProvider);
                      if (value) {
                        ToastUtils.showSuccess(context, '偏好漫游已开启');
                      }
                    } : null,
                    title: Text('设置云漫游', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface, fontSize: 16)),
                    subtitle: Text(
                        isAuth ? '跨设备同步你的深浅模式与主题颜色' : '请先登录以开启配置漫游',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)
                    ),
                    secondary: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: theme.colorScheme.secondary.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: Icon(Icons.palette_rounded, color: theme.colorScheme.secondary),
                    ),
                  );
                }
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}