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
  
  // WebDAV 配置状态
  bool _isWebDAVConfigured = false;
  String? _webDAVUrl;
  String? _webDAVUser;

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
      
      // 加载 WebDAV 配置状态
      _webDAVUrl = prefs.getString('webdav_url');
      _webDAVUser = prefs.getString('webdav_user');
      _isWebDAVConfigured = _webDAVUrl != null && _webDAVUrl!.isNotEmpty &&
                            _webDAVUser != null && _webDAVUser!.isNotEmpty;
    });
  }

  Future<void> _toggleMasterSwitch(bool value) async {
    setState(() => _isAutoSync = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAutoSyncEnabled', value);

    if (!mounted) return;
    if (value) {
      ToastUtils.showSuccess(context, '云端同步已开启');
      context.read<NotesProvider>().syncWithCloud(context: context);
      context.read<TodosProvider>().syncWithCloud(context: context);
    } else {
      ToastUtils.showInfo(context, '同步已关闭，数据仅保留在本地');
      context.read<NotesProvider>().clearTimers();
      context.read<TodosProvider>().clearTimers();
    }
  }

  Future<void> _changeSyncMode(String mode) async {
    // 如果切换到 WebDAV 但未配置，先引导配置
    if (mode == 'webdav' && !_isWebDAVConfigured) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const WebDavConfigPage()),
      );
      
      // 配置完成后刷新状态
      await _loadSyncSettings();
      
      // 如果配置成功，自动切换到 WebDAV 模式
      if (result == true && _isWebDAVConfigured) {
        setState(() => _syncMode = 'webdav');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('sync_mode', 'webdav');
        if (!mounted) return;
        ToastUtils.showSuccess(context, '已切换至 WebDAV 私有云同步');
        if (_isAutoSync) {
          context.read<NotesProvider>().syncWithCloud(context: context);
        }
      }
      return;
    }

    setState(() => _syncMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_mode', mode);

    if (!mounted) return;
    ToastUtils.showSuccess(context, '已切换至 ${mode == 'supabase' ? '官方云' : 'WebDAV 私有云'} 同步');
    if (_isAutoSync) context.read<NotesProvider>().syncWithCloud(context: context);
  }

  Future<void> _openWebDAVConfig() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const WebDavConfigPage()),
    );
    
    // 返回后刷新配置状态
    await _loadSyncSettings();
    
    // 如果配置了 WebDAV 且当前不是 WebDAV 模式，提示切换
    if (result == true && _syncMode != 'webdav' && mounted) {
      _showSwitchToWebDAVDialog();
    }
  }

  void _showSwitchToWebDAVDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('WebDAV 已配置', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('WebDAV 服务器配置成功！是否立即切换到 WebDAV 同步模式？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('保持当前'),
          ),
          FilledButton.tonal(
            onPressed: () async {
              Navigator.pop(ctx);
              await _changeSyncMode('webdav');
            },
            child: const Text('切换并同步'),
          ),
        ],
      ),
    );
  }

  void _clearWebDAVConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('清除配置', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('确定要清除 WebDAV 配置吗？这将不会影响已同步的数据。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.errorContainer),
            child: Text('清除', style: TextStyle(color: Theme.of(ctx).colorScheme.onErrorContainer)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('webdav_url');
      await prefs.remove('webdav_user');
      await prefs.remove('webdav_pwd');
      
      // 如果当前是 WebDAV 模式，切换回官方云
      if (_syncMode == 'webdav') {
        await prefs.setString('sync_mode', 'supabase');
        setState(() => _syncMode = 'supabase');
      }
      
      await _loadSyncSettings();
      if (mounted) ToastUtils.showSuccess(context, 'WebDAV 配置已清除');
    }
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
          // 🌟 1. 核心笔记/待办数据同步总闸
          // ==========================================
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3))
            ),
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
          // 🌟 2. 同步引擎选择
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
                    child: Text('同步引擎', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  
                  // 官方云选项
                  _buildSyncModeCard(
                    theme: theme,
                    icon: Icons.cloud_done_outlined,
                    title: 'NoteSync 官方云',
                    subtitle: '由 NoteSync 提供安全可靠的云端存储',
                    isSelected: _syncMode == 'supabase',
                    onTap: () => _changeSyncMode('supabase'),
                  ),
                  const SizedBox(height: 12),
                  
                  // WebDAV 选项
                  _buildSyncModeCard(
                    theme: theme,
                    icon: Icons.dns_outlined,
                    title: 'WebDAV 私有云',
                    subtitle: _isWebDAVConfigured 
                        ? '已配置: $_webDAVUser@${_extractHost(_webDAVUrl)}'
                        : '使用坚果云、Nextcloud 或自建 NAS',
                    isSelected: _syncMode == 'webdav',
                    onTap: () => _changeSyncMode('webdav'),
                    trailing: _isWebDAVConfigured 
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '已配置',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onTertiaryContainer,
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
          
          // ==========================================
          // 🌟 3. WebDAV 配置卡片（仅当选择 WebDAV 或未配置时显示）
          // ==========================================
          if (_isAutoSync) ...[
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Text('私有云配置', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            _buildWebDAVConfigCard(theme),
          ],

          const SizedBox(height: 32),

          // ==========================================
          // 🌟 4. 设置云漫游开关
          // ==========================================
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 12),
            child: Text('应用偏好', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3))
            ),
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
                        ToastUtils.showSuccess(context, '设置漫游已开启');
                      }
                    } : null,
                    title: Text('设置云漫游', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface, fontSize: 16)),
                    subtitle: Text(
                        isAuth ? '同步主题外观、深浅模式及专业编辑配置' : '请先登录以开启设置漫游',
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

  Widget _buildSyncModeCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isSelected 
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
              : theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                      : theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon, 
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebDAVConfigCard(ThemeData theme) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // 配置状态显示
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isWebDAVConfigured
                        ? theme.colorScheme.tertiaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isWebDAVConfigured ? Icons.check_circle_outline_rounded : Icons.cloud_off_outlined,
                    color: _isWebDAVConfigured
                        ? theme.colorScheme.onTertiaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isWebDAVConfigured ? 'WebDAV 已配置' : '未配置 WebDAV',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isWebDAVConfigured
                            ? '服务器: ${_extractHost(_webDAVUrl)}\n用户: $_webDAVUser'
                            : '配置 WebDAV 服务器以启用私有云同步',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 操作按钮
          Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _openWebDAVConfig,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isWebDAVConfigured ? Icons.edit_rounded : Icons.add_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isWebDAVConfigured ? '修改配置' : '添加配置',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_isWebDAVConfigured) ...[
                Container(width: 1, height: 48, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                Expanded(
                  child: InkWell(
                    onTap: _clearWebDAVConfig,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '清除',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _extractHost(String? url) {
    if (url == null || url.isEmpty) return '未知';
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return url;
    }
  }
}
