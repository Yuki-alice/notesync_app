import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../utils/toast_utils.dart';

class AboutSettingsPage extends StatefulWidget {
  const AboutSettingsPage({super.key});

  @override
  State<AboutSettingsPage> createState() => _AboutSettingsPageState();
}

class _AboutSettingsPageState extends State<AboutSettingsPage> {

  // 🌟 模拟网页跳转逻辑 (实际项目中可替换为 url_launcher)
  void _launchUrl(String url, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('即将跳转', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text('正在离开应用，前往 $title 网页：\n$url'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx), child: const Text('前往')),
        ],
      ),
    );
  }

  // 🌟 检查更新交互
  Future<void> _checkForUpdates() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Row(
          children: [
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(width: 20),
            const Text('正在检查新版本...', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('已是最新版本', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('当前版本 NoteSync v2.2.0 已是最新。'),
        actions: [
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx), child: const Text('我知道了')),
        ],
      ),
    );
  }

  // 🌟 通用文档展示面板 (用于展示更新日志、隐私协议)
  void _showScrollableSheet(String title, String content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.7, maxChildSize: 0.9,
        builder: (ctx, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                children: [
                  Text(content, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.7, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('关于与帮助', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // 品牌区域
          Center(
            child: Column(
              children: [
                Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 12))],
                  ),
                  child: const Icon(Icons.edit_document, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text('NoteSync', style: GoogleFonts.notoSans(fontSize: 24, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                  child: Text('Version 2.2.0 (Build 204)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // ==========================================
          // 模块 1：更新与支持
          // ==========================================
          _buildSectionHeader(theme, '更新与服务'),
          _buildGroupContainer(theme, [
            _buildMenuRow(theme, icon: Icons.update_rounded, title: '检查更新', onTap: _checkForUpdates),
            _buildDivider(theme),
            _buildMenuRow(theme, icon: Icons.assignment_outlined, title: '更新说明', onTap: () => _showScrollableSheet('更新日志', 'v2.2.0 更新内容：\n\n• [优化] 全新设计的设置界面与统计面板\n• [修复] 解决 WebDAV 在特定环境下同步失败的问题\n• [新增] 笔记冗余图片一键清理功能\n• [美化] 完善了全平台的悬停与点击反馈')),
            _buildDivider(theme),
            _buildMenuRow(theme, icon: Icons.forum_outlined, title: '反馈建议', isExternal: true, onTap: () => _launchUrl('https://feedback.notesync.com', '反馈中心')),
            _buildDivider(theme),
            _buildMenuRow(theme, icon: Icons.language_rounded, title: '官方网站', isExternal: true, onTap: () => _launchUrl('https://www.notesync.com', '官方主页')),
          ]),
          const SizedBox(height: 32),

          // ==========================================
          // 模块 2：关于与法律 (🌟 整合隐私协议)
          // ==========================================
          _buildSectionHeader(theme, '关于与法律'),
          _buildGroupContainer(theme, [
            _buildMenuRow(theme, icon: Icons.code_rounded, title: '开源代码 (GitHub)', isExternal: true, onTap: () => _launchUrl('https://github.com/notesync/app', 'GitHub')),
            _buildDivider(theme),
            _buildMenuRow(theme, icon: Icons.verified_user_outlined, title: '隐私政策与用户协议', onTap: () => _showScrollableSheet('隐私政策与服务协议', '1. 隐私声明\n我们高度重视您的隐私。您的所有本地笔记均加密存储，不会上传至任何未授权的服务器。\n\n2. 服务协议\n使用本应用即代表您同意我们通过 WebDAV 或 Supabase 提供的同步服务条款...\n\n3. 数据所有权\n用户拥有对其创作内容的绝对所有权。')),
          ]),
          const SizedBox(height: 48),

          // 底部信息
          Center(
            child: Column(
              children: [
                Text('© 2026 NoteSync Studio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.outlineVariant)),
                const SizedBox(height: 4),
                Text('Made with ❤️ & Flutter', style: TextStyle(fontSize: 11, color: theme.colorScheme.outlineVariant)),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // 🌟 物理切圆角，完美解决水波纹溢出
  Widget _buildGroupContainer(ThemeData theme, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.02), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias, // 🔪 关键：裁切溢出的 Hover 效果
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Text(title, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 60, right: 20),
      child: Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
    );
  }

  Widget _buildMenuRow(ThemeData theme, {required IconData icon, required String title, required VoidCallback onTap, bool isExternal = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
            Icon(isExternal ? Icons.open_in_new_rounded : Icons.chevron_right_rounded, size: 18, color: theme.colorScheme.outlineVariant),
          ],
        ),
      ),
    );
  }
}