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
import '../../../../widgets/common/dialogs/app_dialog.dart';
import '../../../../widgets/common/dialogs/app_sheet.dart';
import '../viewmodels/profile_viewmodel.dart';

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
          SliverAppBar.large(
            title: Text('设置', style: GoogleFonts.notoSans(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            centerTitle: false,
            backgroundColor: theme.colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🌟 1. 个人资料区与数据看板
                  _ProfileSectionWidget(auth: authProvider, theme: theme),
                  const SizedBox(height: 32),

                  // 2. 外观设置
                  _buildSectionTitle(context, '外观'),
                  _buildSettingGroup(
                    context,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                children: [
                                  _buildUniformIcon(context, Icons.brightness_6_rounded),
                                  const SizedBox(width: 12),
                                  Text('深色模式', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: theme.colorScheme.onSurface)),
                                ]
                            ),
                            const SizedBox(height: 16),
                            _ElegantThemeModeToggle(currentMode: themeProvider.themeMode, onChanged: (mode) => themeProvider.setThemeMode(mode)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSettingGroup(
                    context,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                children: [
                                  _buildUniformIcon(context, Icons.palette_rounded),
                                  const SizedBox(width: 12),
                                  Text('个性化主题', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: theme.colorScheme.onSurface)),
                                ]
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 100,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: ThemeProvider.presetThemes.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 12),
                                itemBuilder: (context, index) {
                                  final style = ThemeProvider.presetThemes[index];
                                  final isSelected = themeProvider.currentThemeId == style.id;
                                  BoxDecoration decoration = (style.vibe == ThemeVibe.gradient)
                                      ? BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [style.seedColor.withValues(alpha: 0.6), style.seedColor.withValues(alpha: 0.2)]), shape: BoxShape.circle, boxShadow: isSelected ? [BoxShadow(color: style.seedColor.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))] : null)
                                      : BoxDecoration(color: style.seedColor, shape: BoxShape.circle, boxShadow: isSelected ? [BoxShadow(color: style.seedColor.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))] : null);

                                  return GestureDetector(
                                    onTap: () => themeProvider.setThemeStyle(style.id),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      width: 76,
                                      decoration: BoxDecoration(
                                        color: isSelected ? style.seedColor.withValues(alpha: 0.05) : theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: isSelected ? style.seedColor : theme.colorScheme.outlineVariant.withValues(alpha: 0.3), width: isSelected ? 2 : 1),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(width: 36, height: 36, decoration: decoration, child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null),
                                          const SizedBox(height: 8),
                                          Text(style.name, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, height: 1.2, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? style.seedColor : theme.colorScheme.onSurfaceVariant)),
                                        ],
                                      ),
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
                      const _ProModeSwitchTile(),
                      Divider(height: 1, indent: 64, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                      ListTile(
                        title: Text('分类管理', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                        subtitle: Text('添加、重命名或删除分类', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                        leading: _buildUniformIcon(context, Icons.category_rounded),
                        trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
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
                        title: Text('回收站', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                        subtitle: Text('查看或恢复已删除的内容', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                        leading: _buildUniformIcon(context, Icons.delete_outline_rounded),
                        trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.trash),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // 5. 退出登录
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

                  // 底部信息
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

  Widget _buildUniformIcon(BuildContext context, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
      child: Icon(icon, color: theme.colorScheme.primary, size: 20),
    );
  }

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
      child: Column(children: children),
    );
  }

  void _showLogoutConfirmDialog(BuildContext context, AuthProvider authProvider) async {
    final confirm = await AppDialog.showConfirm(
      context: context,
      title: '退出登录',
      content: '退出登录将清除此设备上的本地缓存数据。\n您的数据已安全保存在云端，下次登录即可恢复。',
      icon: Icons.logout_rounded,
      confirmText: '确认退出',
      isDestructive: true,
    );
    if (confirm == true) {
      await authProvider.signOut();
      if (context.mounted) {
        context.read<NotesProvider>().clearLocalData();
        context.read<TodosProvider>().clearLocalData();
        ToastUtils.showInfo(context, '已安全退出账号');
      }
    }
  }
}

// ==========================================
// 🌟 数据看板区 (带字数统计和个性签名)
// ==========================================
class _ProfileSectionWidget extends StatelessWidget {
  final AuthProvider auth;
  final ThemeData theme;
  const _ProfileSectionWidget({required this.auth, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (!auth.isAuthenticated) {
      return _buildUnauthState(context);
    }

    final user = auth.currentUser;
    int daysJoined = 1;
    if (user?.createdAt != null) {
      final joinDate = DateTime.parse(user!.createdAt);
      daysJoined = DateTime.now().difference(joinDate).inDays;
      if (daysJoined < 1) daysJoined = 1;
    }

    // 🌟 动态计算字数与笔记数
    final notesProvider = context.watch<NotesProvider>();
    final notesCount = notesProvider.filteredNotes.length;

    int totalWords = 0;
    for (var note in notesProvider.filteredNotes) {
      // 如果正文属性叫 text，则改用 note.text?.length
      totalWords += (note.content?.length ?? 0);
    }

    String wordCountStr = totalWords >= 10000
        ? '${(totalWords / 10000).toStringAsFixed(1)}W'
        : totalWords.toString();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primaryContainer),
                  clipBehavior: Clip.hardEdge,
                  child: Builder(
                    builder: (context) {
                      if (auth.localAvatarPath != null && File(auth.localAvatarPath!).existsSync()) return Image.file(File(auth.localAvatarPath!), fit: BoxFit.cover);
                      else if (auth.avatarUrl != null) return Image.network(auth.avatarUrl!, fit: BoxFit.cover);
                      else return Center(child: Text(auth.displayName.isNotEmpty ? auth.displayName[0].toUpperCase() : 'N', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)));
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(auth.displayName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      // 🌟 展示签名
                      Text(
                        (auth.bio != null && auth.bio!.isNotEmpty)
                            ? auth.bio!
                            : (auth.currentUser?.email ?? '记录生活，同步灵感'),
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    AppSheet.show(
                      context: context,
                      desktopMaxWidth: 480,
                      builder: (ctx) => ChangeNotifierProvider(
                        create: (_) => ProfileViewModel(auth),
                        child: const EditProfileSheet(),
                      ),
                    );
                  },
                  icon: Icon(Icons.edit_rounded, color: theme.colorScheme.primary),
                  style: IconButton.styleFrom(backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1)),
                  tooltip: '编辑资料',
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem(context, '陪伴', '$daysJoined', '天'),
                  Container(width: 1, height: 32, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  _buildStatItem(context, '笔记', '$notesCount', '篇'),
                  Container(width: 1, height: 32, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  // 🌟 核心：显示字数统计
                  _buildStatItem(context, '累计', wordCountStr, '字'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, String unit) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(width: 2),
            Text(unit, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
      ],
    );
  }

  Widget _buildUnauthState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5), shape: BoxShape.circle),
            child: Icon(Icons.person_outline_rounded, size: 40, color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 24),
          Text('尚未开启云端同步', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
          const SizedBox(height: 8),
          Text('登录账号，跨设备随时随地访问你的灵感与待办', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('去登录 / 注册', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 🌟 其他子组件
// ==========================================
class _ElegantThemeModeToggle extends StatelessWidget {
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;
  const _ElegantThemeModeToggle({required this.currentMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modes = [
      {'mode': ThemeMode.system, 'icon': Icons.brightness_auto_rounded, 'label': '跟随系统'},
      {'mode': ThemeMode.light, 'icon': Icons.light_mode_rounded, 'label': '浅色'},
      {'mode': ThemeMode.dark, 'icon': Icons.dark_mode_rounded, 'label': '深色'},
    ];

    return Container(
      height: 44,
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(22)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / 3;
          final selectedIndex = modes.indexWhere((m) => m['mode'] == currentMode);

          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic,
                left: selectedIndex * segmentWidth, top: 0, bottom: 0, width: segmentWidth,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Container(decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))])),
                ),
              ),
              Row(
                children: modes.map((m) {
                  final isSelected = m['mode'] == currentMode;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(m['mode'] as ThemeMode),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [Icon(m['icon'] as IconData, size: 16, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant), const SizedBox(width: 6), Text(m['label'] as String)],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProModeSwitchTile extends StatefulWidget { const _ProModeSwitchTile(); @override State<_ProModeSwitchTile> createState() => _ProModeSwitchTileState(); }
class _ProModeSwitchTileState extends State<_ProModeSwitchTile> {
  bool _isProMode = false;
  @override void initState() { super.initState(); _loadPreference(); }
  Future<void> _loadPreference() async { final prefs = await SharedPreferences.getInstance(); setState(() => _isProMode = prefs.getBool('isProMode') ?? false); }
  Future<void> _toggleMode(bool value) async { setState(() => _isProMode = value); final prefs = await SharedPreferences.getInstance(); await prefs.setBool('isProMode', value); }
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SwitchListTile(
      value: _isProMode, onChanged: _toggleMode,
      title: Text('专业编辑模式', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
      subtitle: Text('支持 Markdown 语法 (如 "# " 生成标题)', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
      secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.code_rounded, color: theme.colorScheme.primary)),
    );
  }
}

// 🌟 修改过的资料编辑面板 (带个性签名输入)
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key});
  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}
class _EditProfileSheetState extends State<EditProfileSheet> {
  late TextEditingController _nameController;
  late TextEditingController _bioController; // 签名控制器
  DateTime? _selectedBirthday;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _nameController = TextEditingController(text: auth.displayName);
    _bioController = TextEditingController(text: auth.bio ?? ''); // 加载签名
    if (auth.birthday != null && auth.birthday!.isNotEmpty) {
      _selectedBirthday = DateTime.tryParse(auth.birthday!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthday(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme), child: child!),
    );
    if (picked != null && picked != _selectedBirthday) {
      setState(() => _selectedBirthday = picked);
    }
  }

  Widget _buildAvatarImage(ProfileViewModel vm, AuthProvider auth, ThemeData theme) {
    if (vm.localSelectedImage != null) return Image.file(vm.localSelectedImage!, fit: BoxFit.cover);
    if (auth.localAvatarPath != null && File(auth.localAvatarPath!).existsSync()) return Image.file(File(auth.localAvatarPath!), fit: BoxFit.cover);
    if (auth.avatarUrl != null) return Image.network(auth.avatarUrl!, fit: BoxFit.cover);
    return Center(child: Text(_nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'N', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final vm = context.watch<ProfileViewModel>();
    final auth = context.read<AuthProvider>();

    final birthdayStr = _selectedBirthday != null ? "${_selectedBirthday!.year}-${_selectedBirthday!.month.toString().padLeft(2, '0')}-${_selectedBirthday!.day.toString().padLeft(2, '0')}" : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 24),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Center(child: Text('编辑个人资料', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))),
            const SizedBox(height: 32),

            Center(
              child: GestureDetector(
                onTap: vm.isLoading ? null : () => vm.pickAndCropImage(context),
                child: Stack(
                  children: [
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, shape: BoxShape.circle, border: Border.all(color: theme.colorScheme.surface, width: 4), boxShadow: [BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.1), blurRadius: 10)]),
                      clipBehavior: Clip.hardEdge,
                      child: _buildAvatarImage(vm, auth, theme),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle, border: Border.all(color: theme.colorScheme.surface, width: 3)),
                        child: Icon(Icons.camera_alt_rounded, size: 16, color: theme.colorScheme.onPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            TextFormField(
              controller: _nameController,
              enabled: !vm.isLoading,
              style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: '用户昵称',
                labelStyle: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                prefixIcon: Icon(Icons.person_outline_rounded, color: theme.colorScheme.primary),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
              ),
              onChanged: (val) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // 🌟 签名输入框
            TextFormField(
              controller: _bioController,
              enabled: !vm.isLoading,
              maxLength: 30, // 限制字数以保持界面美观
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: '个性签名',
                hintText: '写下你的座右铭或当前状态...',
                labelStyle: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                prefixIcon: Icon(Icons.edit_note_rounded, color: theme.colorScheme.primary),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
              ),
            ),
            const SizedBox(height: 16),

            InkWell(
              onTap: vm.isLoading ? null : () => _selectBirthday(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Icon(Icons.cake_outlined, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('生日', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(birthdayStr ?? '设置你的生日 (未来会有小惊喜哦)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: birthdayStr != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
                        ],
                      ),
                    ),
                    Icon(Icons.calendar_month_rounded, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            FilledButton(
              onPressed: vm.isLoading ? null : () async {
                // 🌟 将三个属性传给状态管家
                final errorMsg = await vm.saveProfile(_nameController.text, birthdayStr, _bioController.text);
                if (!context.mounted) return;
                if (errorMsg == null) {
                  Navigator.pop(context);
                  ToastUtils.showSuccess(context, '个人资料已更新 ✨');
                } else {
                  ToastUtils.showError(context, errorMsg);
                }
              },
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: vm.isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('保存修改', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}