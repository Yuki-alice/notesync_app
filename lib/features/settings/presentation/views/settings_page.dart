import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/theme_provider.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/todos_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../utils/toast_utils.dart';
import '../viewmodels/profile_viewmodel.dart'; // 引入我们刚刚写的 ViewModel

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 极简头部
          SliverAppBar.large(
            title: Text('设置', style: GoogleFonts.notoSans(fontWeight: FontWeight.bold)),
            centerTitle: false,
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context)
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 用户/登录模块
                  _buildProfileSection(context, authProvider, theme),
                  const SizedBox(height: 32),

                  // 2. 外观设置
                  _buildSectionTitle(context, '外观'),
                  _buildSettingGroup(
                    context,
                    children: [
                      SwitchListTile(
                        value: themeProvider.isDarkMode,
                        onChanged: (val) => themeProvider.toggleTheme(),
                        title: const Text('深色模式', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('减轻眼部疲劳'),
                        secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, shape: BoxShape.circle),
                            child: Icon(themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: theme.colorScheme.onPrimaryContainer)
                        ),
                      ),
                      const Divider(height: 1, indent: 64),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('主题颜色', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 48,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: ThemeProvider.presetColors.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 16),
                                itemBuilder: (context, index) {
                                  final color = ThemeProvider.presetColors[index];
                                  final isSelected = themeProvider.themeColor.value == color.value;

                                  return GestureDetector(
                                    onTap: () => themeProvider.setThemeColor(color),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: isSelected ? Border.all(color: theme.colorScheme.onSurface, width: 3) : null,
                                        boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)] : null,
                                      ),
                                      child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 24) : null,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // 3. 笔记管理
                  _buildSectionTitle(context, '笔记'),
                  _buildSettingGroup(
                    context,
                    children: [
                      ListTile(
                        title: const Text('分类管理', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('添加、重命名或删除分类'),
                        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: theme.colorScheme.tertiaryContainer, shape: BoxShape.circle), child: Icon(Icons.category_rounded, color: theme.colorScheme.onTertiaryContainer)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.categories),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // 4. 数据管理
                  _buildSectionTitle(context, '数据'),
                  _buildSettingGroup(
                    context,
                    children: [
                      ListTile(
                        title: const Text('清空回收站', style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('彻底删除回收站内的所有数据'),
                        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: theme.colorScheme.errorContainer, shape: BoxShape.circle), child: Icon(Icons.delete_sweep_rounded, color: theme.colorScheme.error)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _confirmClearAllTrash(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // 5. 退出登录按钮 (仅登录时显示)
                  if (authProvider.isAuthenticated) ...[
                    _buildSettingGroup(
                      context,
                      children: [
                        ListTile(
                          title: Text('退出当前账号', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.error)),
                          leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: theme.colorScheme.errorContainer.withValues(alpha: 0.5), shape: BoxShape.circle),
                              child: Icon(Icons.logout_rounded, color: theme.colorScheme.error)
                          ),
                          onTap: () => _showLogoutConfirmDialog(context, authProvider),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],

                  // 底部版本信息
                  Center(
                    child: Column(
                      children: [
                        Text('NoteSync', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text('Version 1.0.0', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 构建用户模块
  // ==========================================
  Widget _buildProfileSection(BuildContext context, AuthProvider auth, ThemeData theme) {
    if (auth.isAuthenticated) {
      return Material(
        color: theme.colorScheme.surfaceContainerLowest,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: InkWell(
          onTap: () => _showEditProfileSheet(context, auth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                // 动态头像渲染 (🟢 增加了本地私有目录缓存读取，离线秒开)
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primaryContainer),
                  clipBehavior: Clip.hardEdge,
                  child: Builder(
                    builder: (context) {
                      if (auth.localAvatarPath != null && File(auth.localAvatarPath!).existsSync()) {
                        return Image.file(File(auth.localAvatarPath!), fit: BoxFit.cover);
                      } else if (auth.avatarUrl != null) {
                        return Image.network(auth.avatarUrl!, fit: BoxFit.cover);
                      } else {
                        return Center(
                          child: Text(
                              auth.displayName.isNotEmpty ? auth.displayName[0].toUpperCase() : 'N',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(auth.displayName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(auth.currentUser?.email ?? '', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(Icons.edit_rounded, color: theme.colorScheme.outline),
              ],
            ),
          ),
        ),
      );
    } else {
      // ✅ 未登录：由于这里调用的是 _buildSettingGroup，因此直角悬停问题也一并被修复了
      return _buildSettingGroup(
        context,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, shape: BoxShape.circle), child: Icon(Icons.person_outline_rounded, color: theme.colorScheme.primary)),
            title: const Text('未登录', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('登录账号，开启多设备同步'),
            trailing: FilledButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.login), style: FilledButton.styleFrom(shape: const StadiumBorder()), child: const Text('去登录')),
            onTap: () => Navigator.pushNamed(context, AppRoutes.login),
          ),
        ],
      );
    }
  }

  // ==========================================
  // 辅助组件构建
  // ==========================================
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }

  Widget _buildSettingGroup(BuildContext context, {required List<Widget> children}) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(children: children),
    );
  }
  // ==========================================
  // 业务逻辑与弹窗
  // ==========================================
  void _showEditProfileSheet(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChangeNotifierProvider(
        create: (_) => ProfileViewModel(auth),
        child: const EditProfileSheet(),
      ),
    );
  }

  void _showLogoutConfirmDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出登录将清除此设备上的本地缓存数据。\n您的数据已安全保存在云端，下次登录即可恢复。是否继续？'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.errorContainer, foregroundColor: Theme.of(context).colorScheme.onErrorContainer),
            onPressed: () async {
              await authProvider.signOut();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('last_sync_time');
              await prefs.remove('last_todo_sync_time');

              if (ctx.mounted) {
                context.read<NotesProvider>().clearLocalData();
                context.read<TodosProvider>().clearLocalData();
                Navigator.pop(ctx);
              }
            },
            child: const Text('确认退出'),
          ),
        ],
      ),
    );
  }

  void _confirmClearAllTrash(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空回收站'),
        content: const Text('笔记和待办事项的回收站都将被清空，此操作不可恢复。'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<NotesProvider>(context, listen: false).emptyTrash();
              Provider.of<TodosProvider>(context, listen: false).emptyTrash();
              ToastUtils.showError(context, '回收站已清空');
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('全部清空'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 个人资料编辑面板 (包含生日与裁剪)
// ==========================================
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late TextEditingController _nameController;
  DateTime? _selectedBirthday;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _nameController = TextEditingController(text: auth.displayName);
    if (auth.birthday != null && auth.birthday!.isNotEmpty) {
      _selectedBirthday = DateTime.tryParse(auth.birthday!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthday(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary, // 主色调统一
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedBirthday) {
      setState(() => _selectedBirthday = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final vm = context.watch<ProfileViewModel>();
    final auth = context.read<AuthProvider>();

    final birthdayStr = _selectedBirthday != null
        ? "${_selectedBirthday!.year}-${_selectedBirthday!.month.toString().padLeft(2, '0')}-${_selectedBirthday!.day.toString().padLeft(2, '0')}"
        : null;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding + 24),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)))),
          Text('编辑个人资料', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // 🟢 头像区域：点击唤起裁剪器
          Center(
            child: GestureDetector(
              onTap: vm.isLoading ? null : () => vm.pickAndCropImage(context),
              child: Stack(
                children: [
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, shape: BoxShape.circle),
                    clipBehavior: Clip.hardEdge,
                    child: _buildAvatarImage(vm, auth, theme),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle, border: Border.all(color: theme.colorScheme.surface, width: 3)),
                      child: Icon(Icons.camera_alt_rounded, size: 16, color: theme.colorScheme.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // 昵称输入
          TextFormField(
            controller: _nameController,
            enabled: !vm.isLoading,
            decoration: InputDecoration(
                labelText: '用户昵称',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)
            ),
            onChanged: (val) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // 🟢 生日选择器
          InkWell(
            onTap: vm.isLoading ? null : () => _selectBirthday(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.cake_outlined, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('生日', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(
                          birthdayStr ?? '设置你的生日 ',
                          style: TextStyle(
                              fontSize: 16,
                              color: birthdayStr != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // 提交按钮
          FilledButton(
            onPressed: vm.isLoading ? null : () async {
              final errorMsg = await vm.saveProfile(_nameController.text, birthdayStr);
              if (!context.mounted) return;

              if (errorMsg == null) {
                Navigator.pop(context);
                ToastUtils.showSuccess(context,'个人资料已完美同步 ✨');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent));
              }
            },
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: vm.isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('保存修改', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 🟢 智能头像回显 (本地优先 -> 云端优先 -> 默认)
  Widget _buildAvatarImage(ProfileViewModel vm, AuthProvider auth, ThemeData theme) {
    if (vm.localSelectedImage != null) {
      return Image.file(vm.localSelectedImage!, fit: BoxFit.cover);
    }
    // 优先读取本地永久缓存，实现真正的离线可用
    if (auth.localAvatarPath != null && File(auth.localAvatarPath!).existsSync()) {
      return Image.file(File(auth.localAvatarPath!), fit: BoxFit.cover);
    }
    if (auth.avatarUrl != null) {
      return Image.network(auth.avatarUrl!, fit: BoxFit.cover);
    }
    return Center(
      child: Text(
        _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'N',
        style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
      ),
    );
  }
}