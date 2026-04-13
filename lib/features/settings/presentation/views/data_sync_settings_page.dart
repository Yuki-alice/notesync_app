import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/todos_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../utils/toast_utils.dart';
import '../../../../widgets/common/dialogs/app_dialog.dart';
import '../../../../core/services/local_backup_service.dart';
import 'webdav_config_page.dart';

class DataSyncSettingsPage extends StatefulWidget {
  const DataSyncSettingsPage({super.key});

  @override
  State<DataSyncSettingsPage> createState() => _DataSyncSettingsPageState();
}

class _DataSyncSettingsPageState extends State<DataSyncSettingsPage> {
  bool _isAutoSync = false;
  String _syncMode = 'supabase';
  String _storageUsage = '计算中...'; // 🌟 存储占用状态

  @override
  void initState() {
    super.initState();
    _loadSyncSettings();
    _calculateStorageUsage(); // 🌟 页面加载时计算存储大小
  }

  Future<void> _loadSyncSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAutoSync = prefs.getBool('isAutoSyncEnabled') ?? false;
      _syncMode = prefs.getString('sync_mode') ?? 'supabase';
    });
  }

  // 🌟 核心新功能：精准计算本地数据库和图片文件夹的真实占用体积
  Future<void> _calculateStorageUsage() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      int totalBytes = 0;

      // 1. 计算 Isar 数据库大小
      final isarDbFile = File(p.join(appDir.path, 'default.isar'));
      if (await isarDbFile.exists()) {
        totalBytes += await isarDbFile.length();
      }

      // 2. 计算本地图片缓存大小
      final imgDir = Directory(p.join(appDir.path, 'note_images'));
      if (await imgDir.exists()) {
        await for (var entity in imgDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            totalBytes += await entity.length();
          }
        }
      }

      if (!mounted) return;
      setState(() {
        if (totalBytes == 0) {
          _storageUsage = '0 B';
        } else if (totalBytes < 1024 * 1024) {
          _storageUsage = '${(totalBytes / 1024).toStringAsFixed(1)} KB';
        } else {
          _storageUsage = '${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _storageUsage = '未知');
    }
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
    context.read<NotesProvider>().syncWithCloud();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backupService = LocalBackupService(Isar.getInstance()!);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('数据与同步', style: GoogleFonts.notoSans(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [

          // ==========================================
          // 模块 1：云端同步引擎管理
          // ==========================================
          _buildSectionHeader(theme, '云端同步服务'),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: _buildCardDecoration(theme),
            child: Column(
              children: [
                SwitchListTile(
                  value: _isAutoSync,
                  onChanged: _toggleMasterSwitch,
                  title: Text('开启自动同步', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                  subtitle: Text('后台静默同步笔记与待办', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  secondary: Icon(Icons.cloud_sync_rounded, color: theme.colorScheme.primary),
                ),
                if (_isAutoSync) ...[
                  Divider(height: 1, indent: 64, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('引擎选择', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                        const SizedBox(height: 12),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'supabase', label: Text('官方云'), icon: Icon(Icons.cloud_done_outlined)),
                            ButtonSegment(value: 'webdav', label: Text('私有云 (BYOD)'), icon: Icon(Icons.dns_outlined)),
                          ],
                          selected: {_syncMode},
                          onSelectionChanged: (set) => _changeSyncMode(set.first),
                          showSelectedIcon: false,
                          style: SegmentedButton.styleFrom(selectedBackgroundColor: theme.colorScheme.primaryContainer),
                        ),
                      ],
                    ),
                  ),
                  if (_syncMode == 'webdav') ...[
                    Divider(height: 1, indent: 64, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                    ListTile(
                      contentPadding: const EdgeInsets.only(left: 64, right: 16),
                      title: Text('配置 WebDAV 服务器', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface)),
                      subtitle: Text('接入坚果云、NAS 等', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                      trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WebDavConfigPage())),
                    ),
                  ]
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ==========================================
          // 模块 2：本地数据与存储
          // ==========================================
          _buildSectionHeader(theme, '数据与存储'),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: _buildCardDecoration(theme),
            child: Column(
              children: [
                // 🌟 新增：存储占用查看
                ListTile(
                  title: Text('存储位置与占用', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                  subtitle: Text('本地数据库与图片缓存', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  leading: Icon(Icons.storage_rounded, color: theme.colorScheme.primary),
                  trailing: Text(
                      _storageUsage,
                      style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 14)
                  ),
                  onTap: () {
                    ToastUtils.showInfo(context, '正在重新扫描存储空间...');
                    _calculateStorageUsage();
                  },
                ),
                Divider(height: 1, indent: 56, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),

                // 原有的备份与恢复
                ListTile(
                  title: Text('备份与还原', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                  subtitle: Text('导出 ZIP 快照或从本地恢复', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  leading: Icon(Icons.save_alt_rounded, color: theme.colorScheme.primary),
                  trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
                  onTap: () => _showBackupBottomSheet(context, backupService),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ==========================================
          // 模块 3：数据安全
          // ==========================================
          _buildSectionHeader(theme, '安全与恢复'),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: _buildCardDecoration(theme),
            child: ListTile(
              title: Text('回收站', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
              subtitle: Text('查看或恢复已删除的内容', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              leading: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.primary),
              trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
              onTap: () => Navigator.pushNamed(context, AppRoutes.trash),
            ),
          ),
        ],
      ),
    );
  }

  // 辅助 UI 积木：小节标题
  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Text(title, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  // 辅助 UI 积木：卡片样式
  BoxDecoration _buildCardDecoration(ThemeData theme) {
    return BoxDecoration(
      color: theme.colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
    );
  }

  // 备份与还原底部弹窗
  void _showBackupBottomSheet(BuildContext context, LocalBackupService backupService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('本地数据快照', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.upload_rounded), title: const Text('打包导出至 ZIP'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final auth = context.read<AuthProvider>();
                  await backupService.exportData(auth.displayName.isNotEmpty ? auth.displayName : 'LocalUser');
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded, color: Colors.red), title: const Text('从 ZIP 覆盖恢复', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await AppDialog.showConfirm(context: context, title: '警告', content: '将覆盖所有本地数据！', icon: Icons.warning_amber_rounded, isDestructive: true);
                  if (confirm == true) {
                    bool success = await backupService.importData();
                    if (success && context.mounted) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('last_sync_time'); await prefs.remove('last_todo_sync_time');
                      context.read<NotesProvider>().loadNotes(); context.read<TodosProvider>().loadTodos();
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}