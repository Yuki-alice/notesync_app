import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/todos_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../utils/toast_utils.dart';
import '../../../../widgets/common/dialogs/app_dialog.dart';
import '../../../../core/services/local_backup_service.dart';
import '../../../../models/note.dart'; // 🌟 需要引入 Note 模型来解析图片路径

class StorageSettingsPage extends StatefulWidget {
  const StorageSettingsPage({super.key});

  @override
  State<StorageSettingsPage> createState() => _StorageSettingsPageState();
}

class _StorageSettingsPageState extends State<StorageSettingsPage> {
  bool _isCalculating = true;
  int _isarBytes = 0;
  int _imgBytes = 0;
  String _appDirPath = "获取中..."; // 🌟 新增：存储真实路径

  @override
  void initState() {
    super.initState();
    _calculateStorageUsage();
  }

  Future<void> _calculateStorageUsage() async {
    setState(() => _isCalculating = true);
    try {
      final appDir = await getApplicationDocumentsDirectory();
      int isarSize = 0;
      int imgSize = 0;

      final isarDbFile = File(p.join(appDir.path, 'default.isar'));
      if (await isarDbFile.exists()) isarSize = await isarDbFile.length();

      final imgDir = Directory(p.join(appDir.path, 'note_images'));
      if (await imgDir.exists()) {
        await for (var entity in imgDir.list(recursive: true, followLinks: false)) {
          if (entity is File) imgSize += await entity.length();
        }
      }

      if (mounted) {
        setState(() {
          _appDirPath = appDir.path; // 🌟 记录路径
          _isarBytes = isarSize;
          _imgBytes = imgSize;
          _isCalculating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  // 🌟 核心新功能：真正的冗余图片清理引擎
  Future<void> _cleanRedundantImages() async {
    ToastUtils.showInfo(context, "正在扫描无用图片...");
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imgDir = Directory(p.join(appDir.path, 'note_images'));
      if (!await imgDir.exists()) {
        ToastUtils.showSuccess(context, "空间很干净，没有需要清理的图片");
        return;
      }

      // 1. 提取所有笔记中仍在被引用的图片文件名
      final notesProvider = context.read<NotesProvider>();
      Set<String> usedImageNames = {};
      for (var note in notesProvider.filteredNotes) {
        final rawPaths = Note.extractAllImagePaths(note.content ?? '');
        for (var rawPath in rawPaths) {
          usedImageNames.add(p.basename(rawPath.replaceAll('\\', '/')));
        }
      }

      // 2. 遍历本地图片文件夹，揪出没被使用的“孤儿图片”
      int deletedCount = 0;
      int freedBytes = 0;

      await for (var entity in imgDir.list(recursive: false)) {
        if (entity is File) {
          final fileName = p.basename(entity.path);
          if (!usedImageNames.contains(fileName)) {
            freedBytes += await entity.length();
            await entity.delete(); // 咔嚓掉
            deletedCount++;
          }
        }
      }

      if (!mounted) return;

      if (deletedCount > 0) {
        ToastUtils.showSuccess(context, "清理完成！删除了 $deletedCount 张无用图片，释放 ${_formatBytes(freedBytes)} 空间");
        _calculateStorageUsage(); // 重新计算看板容量
      } else {
        ToastUtils.showSuccess(context, "检查完毕，所有的图片都在被使用中");
      }
    } catch (e) {
      if (mounted) ToastUtils.showError(context, "清理过程发生异常");
    }
  }

  String _formatBytes(int bytes) {
    if (bytes == 0) return '0 B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backupService = LocalBackupService(Isar.getInstance()!);
    final auth = context.watch<AuthProvider>();
    final totalBytes = _isarBytes + _imgBytes;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('存储与备份', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 0.5)),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _calculateStorageUsage,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重新计算',
          )
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ==========================================
          // 模块 1：本地存储空间
          // ==========================================
          _buildSectionHeader(theme, '本地存储空间', Icons.pie_chart_rounded),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: theme.colorScheme.shadow.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 🌟 说人话：结构化数据 -> 笔记文本
                    _buildMiniStat(theme, '笔记文本', _formatBytes(_isarBytes), theme.colorScheme.primary),
                    _buildMiniStat(theme, '图片与附件', _formatBytes(_imgBytes), theme.colorScheme.secondary),
                  ],
                ),
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 10,
                    child: Row(
                      children: [
                        if (totalBytes == 0) Expanded(child: Container(color: theme.colorScheme.surfaceContainerHighest)),
                        if (totalBytes > 0) Expanded(flex: (_isarBytes > 0 ? _isarBytes : 1), child: Container(color: theme.colorScheme.primary)),
                        if (totalBytes > 0) Expanded(flex: (_imgBytes > 1 ? _imgBytes : 1), child: Container(color: theme.colorScheme.secondary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'App 当前占用总计 ${_formatBytes(totalBytes)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
                ),

                // 🌟 新增：展示设备上的真实物理存储路径
                if (!_isCalculating) ...[
                  const SizedBox(height: 16),
                  Divider(height: 1, color: theme.colorScheme.outlineVariant.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text('数据保存在设备路径：', style: TextStyle(fontSize: 11, color: theme.colorScheme.outline)),
                  const SizedBox(height: 4),
                  Text(_appDirPath, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: theme.colorScheme.outline)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ==========================================
          // 模块 2：本地备份与恢复
          // ==========================================
          _buildSectionHeader(theme, '本地备份与恢复', Icons.auto_awesome_motion_rounded),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: theme.colorScheme.shadow.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              children: [
                _buildActionRow(
                  theme,
                  icon: Icons.cloud_upload_rounded,
                  title: '导出本地备份',
                  subtitle: '将笔记和图片打包成 ZIP 保存到本地',
                  onTap: () async {
                    final name = auth.displayName.isNotEmpty ? auth.displayName : 'LocalUser';
                    await backupService.exportData(name);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: theme.colorScheme.outlineVariant.withOpacity(0.2)),
                ),
                _buildActionRow(
                  theme,
                  icon: Icons.cloud_download_rounded,
                  title: '从备份中恢复',
                  color: theme.colorScheme.error,
                  subtitle: '选择 ZIP 恢复数据（会覆盖现有内容）',
                  onTap: () async {
                    final confirm = await AppDialog.showConfirm(
                        context: context,
                        title: '危险操作',
                        content: '恢复备份将彻底擦除并覆盖当前设备上的所有数据。建议操作前先执行一次导出备份。',
                        icon: Icons.warning_amber_rounded,
                        isDestructive: true
                    );
                    if (confirm == true) {
                      bool success = await backupService.importData();
                      if (success && context.mounted) {
                        _calculateStorageUsage();
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ==========================================
          // 模块 3：空间清理 (🌟 真功能实装)
          // ==========================================
          _buildSectionHeader(theme, '空间清理', Icons.cleaning_services_rounded),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: theme.colorScheme.secondary.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.delete_sweep_rounded, color: theme.colorScheme.secondary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('清理无用图片', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.colorScheme.onSurface)),
                      const SizedBox(height: 2),
                      Text('找出并删除那些已不在笔记里的残留图片', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, height: 1.3)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: _cleanRedundantImages, // 🌟 绑定真正的清理方法
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary.withOpacity(0.15),
                    foregroundColor: theme.colorScheme.secondary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('清理', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(ThemeData theme, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionRow(ThemeData theme, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap, Color? color}) {
    final activeColor = color ?? theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: activeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: activeColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: activeColor)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outlineVariant),
        ],
      ),
    );
  }
}