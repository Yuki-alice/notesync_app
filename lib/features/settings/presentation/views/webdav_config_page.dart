import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../utils/toast_utils.dart';
import 'package:isar/isar.dart';
import '../../../../core/services/webdav_sync_service.dart';

class WebDavConfigPage extends StatefulWidget {
  const WebDavConfigPage({super.key});

  @override
  State<WebDavConfigPage> createState() => _WebDavConfigPageState();
}

class _WebDavConfigPageState extends State<WebDavConfigPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _urlController;
  late TextEditingController _userController;
  late TextEditingController _pwdController;

  bool _isObscure = true;
  bool _isTesting = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _userController = TextEditingController();
    _pwdController = TextEditingController();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _urlController.text = prefs.getString('webdav_url') ?? '';
      _userController.text = prefs.getString('webdav_user') ?? '';
      _pwdController.text = prefs.getString('webdav_pwd') ?? '';
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _pwdController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isTesting = true);

    final service = WebDavSyncService(Isar.getInstance()!);
    final isSuccess = await service.pingConnection(
        _urlController.text.trim(),
        _userController.text.trim(),
        _pwdController.text.trim()
    );

    if (!mounted) return;
    setState(() => _isTesting = false);

    if (isSuccess) {
      ToastUtils.showSuccess(context, '连接成功！服务器响应正常 🎉');
    } else {
      ToastUtils.showError(context, '连接失败，请检查地址、账号或应用授权码');
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('webdav_url', _urlController.text.trim());
    await prefs.setString('webdav_user', _userController.text.trim());
    await prefs.setString('webdav_pwd', _pwdController.text.trim());


    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => _isSaving = false);
      ToastUtils.showSuccess(context, '配置已保存，请手动开启 WebDAV 同步模式');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('WebDAV 配置', style: GoogleFonts.notoSans(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🌟 顶部图标与说明
              Center(
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, shape: BoxShape.circle),
                  child: Icon(Icons.dns_rounded, size: 40, color: theme.colorScheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(height: 16),
              Text('接入私有云', textAlign: TextAlign.center, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('将笔记数据同步到坚果云、Nextcloud 或你自己的 NAS 中，实现绝对的数据主权。', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 32),

              // 🌟 坚果云提示卡片
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: 0.2))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, color: theme.colorScheme.secondary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('如果你使用坚果云，服务器地址请填写：\nhttps://dav.jianguoyun.com/dav/\n密码请填写在坚果云网页端生成的“应用授权码”，而不是你的登录密码。', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSecondaryContainer, height: 1.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 🌟 输入表单
              Text('服务器配置', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _urlController, theme: theme, label: '服务器地址 (URL)', hint: '例如: https://dav.jianguoyun.com/dav/', icon: Icons.link_rounded,
                validator: (v) => (v == null || v.isEmpty) ? '请输入服务器地址' : (!v.startsWith('http') ? '地址必须以 http 或 https 开头' : null),
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _userController, theme: theme, label: '账号 (Username)', hint: '邮箱或用户名', icon: Icons.person_outline_rounded,
                validator: (v) => (v == null || v.isEmpty) ? '请输入账号' : null,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _pwdController, theme: theme, label: '密码 / 授权码 (Password)', hint: '应用专用密码', icon: Icons.lock_outline_rounded,
                isObscure: _isObscure,
                suffixIcon: IconButton(
                  icon: Icon(_isObscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: theme.colorScheme.onSurfaceVariant),
                  onPressed: () => setState(() => _isObscure = !_isObscure),
                ),
                validator: (v) => (v == null || v.isEmpty) ? '请输入密码' : null,
              ),
              const SizedBox(height: 40),

              // 🌟 动作按钮
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isTesting || _isSaving ? null : _testConnection,
                      icon: _isTesting
                          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary))
                          : const Icon(Icons.wifi_protected_setup_rounded),
                      label: Text(_isTesting ? '测通中...' : '测试连接'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isTesting || _isSaving ? null : _saveConfig,
                      icon: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: Text(_isSaving ? '保存中...' : '保存并启用'),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required ThemeData theme, required String label, required String hint, required IconData icon, bool isObscure = false, Widget? suffixIcon, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      validator: validator,
      style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
        prefixIcon: Icon(icon, color: theme.colorScheme.primary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.error, width: 1)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: theme.colorScheme.error, width: 2)),
      ),
    );
  }
}