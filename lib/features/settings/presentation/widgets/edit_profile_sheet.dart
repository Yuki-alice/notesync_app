import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../utils/toast_utils.dart';
import '../viewmodels/profile_viewmodel.dart';

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key});
  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late TextEditingController _nameController;
  late TextEditingController _bioController; // 🌟 新增：签名控制器
  DateTime? _selectedBirthday;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _nameController = TextEditingController(text: auth.displayName);
    _bioController = TextEditingController(text: auth.bio ?? ''); // 🌟 初始化签名
    if (auth.birthday != null && auth.birthday!.isNotEmpty) {
      _selectedBirthday = DateTime.tryParse(auth.birthday!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose(); // 🌟 记得释放
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

            // 🌟 新增：签名输入框
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