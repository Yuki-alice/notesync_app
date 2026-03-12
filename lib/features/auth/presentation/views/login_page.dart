// 文件路径: lib/features/auth/presentation/views/login_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../utils/toast_utils.dart';
import '../viewmodels/login_viewmodel.dart'; // 🟢 引入 ViewModel

// 🟢 入口处注入 ViewModel
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginViewModel(),
      child: const _LoginPageView(),
    );
  }
}

class _LoginPageView extends StatefulWidget {
  const _LoginPageView();

  @override
  State<_LoginPageView> createState() => _LoginPageViewState();
}

class _LoginPageViewState extends State<_LoginPageView> {
  // UI 层只保留 UI 相关的控制器和状态（表单校验等）
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }


  // 🟢 极其清爽的交互逻辑：把脏活累活全丢给 ViewModel
  Future<void> _handleAuthAction() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    // 从 Provider 获取 ViewModel
    final vm = context.read<LoginViewModel>();

    // 调用 ViewModel 的认证方法
    final errorMsg = await vm.authenticate(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (errorMsg == 'SIGNUP_SUCCESS') {
      ToastUtils.showSuccess(context,'🎉 账号创建成功！请直接点击登录');
      _passwordController.clear(); // 贴心细节：注册完清空密码框让用户重输一次更安全，或者保留也可以
    } else if (errorMsg == null) {
      ToastUtils.showSuccess(context,'✨ 登录成功，欢迎回来！');
      Navigator.pop(context); // 登录成功退出页面
    } else {
      ToastUtils.showError(context,errorMsg); // 报错
    }
  }

  void _openForgotPasswordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // 将当前的 ViewModel 传递给弹窗，让弹窗也能复用网络请求逻辑
      builder: (ctx) => ChangeNotifierProvider.value(
        value: context.read<LoginViewModel>(),
        child: ForgotPasswordSheet(initialEmail: _emailController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) return _buildDesktopLayout(context);
          return _buildMobileLayout(context);
        },
      ),
    );
  }

  // --- 以下为纯 UI 渲染层 (与之前基本一致，只需把 state 替换为 ViewModel 的 getter) ---
  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        // 1. 底部的左右分栏布局
        Row(
          children: [
            Expanded(flex: 5, child: Container(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5), child: _buildIllustrationArea())),
            Expanded(flex: 4, child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: _buildFormContent()))),
          ],
        ),

        // 2. 🟢 叠加上方的返回按钮 (左上角)
        Positioned(
          top: 32, // 桌面端顶部留出一点呼吸感
          left: 32,
          child: IconButton.filledTonal(
            padding: const EdgeInsets.all(12), // 稍微放大一点按钮触控区
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned(top: 0, left: 0, right: 0, height: MediaQuery.of(context).size.height * 0.45, child: Container(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4), child: _buildIllustrationArea())),
        Positioned(top: MediaQuery.of(context).padding.top + 8, left: 16, child: IconButton.filledTonal(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context))),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.65,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
              boxShadow: [BoxShadow(color: theme.colorScheme.shadow.withValues(alpha: 0.08), blurRadius: 30, spreadRadius: 2, offset: const Offset(0, -5))],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [SliverFillRemaining(hasScrollBody: false, child: Padding(padding: const EdgeInsets.fromLTRB(32, 48, 32, 32), child: _buildFormContent()))],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIllustrationArea() {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.auto_awesome_rounded, size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 20),
        Text('NoteSync', style: GoogleFonts.quicksand(textStyle: theme.textTheme.displaySmall, fontWeight: FontWeight.w900, color: theme.colorScheme.primary, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Text('记录生活，捕捉星光', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, letterSpacing: 4)),
      ],
    );
  }

  Widget _buildFormContent() {
    final theme = Theme.of(context);
    // 🟢 监听 ViewModel 的状态变化
    final vm = context.watch<LoginViewModel>();

    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              vm.isSignUp ? '开启新旅程 ✨' : '欢迎回来呀 🎈',
              key: ValueKey(vm.isSignUp),
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: 1.2, color: theme.colorScheme.onSurface, fontSize: 28),
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(height: 40),

          TextFormField(
            controller: _emailController,
            focusNode: _emailFocus,
            enabled: !vm.isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return '邮箱不可以为空哦';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return '请输入正确的邮箱格式';
              return null;
            },
            decoration: InputDecoration(
              labelText: '邮箱地址',
              prefixIcon: const Icon(Icons.email_outlined),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            enabled: !vm.isLoading,
            obscureText: vm.obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleAuthAction(),
            validator: (value) {
              if (value == null || value.isEmpty) return '忘记输入密码啦';
              if (value.length < 6) return '密码太短，至少需要6位';
              return null;
            },
            decoration: InputDecoration(
              labelText: '密码',
              prefixIcon: const Icon(Icons.lock_outline),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              suffixIcon: IconButton(
                icon: Icon(vm.obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: theme.colorScheme.onSurfaceVariant),
                onPressed: vm.togglePasswordVisibility, // 🟢 调用 ViewModel 方法
              ),
            ),
          ),

          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: vm.isSignUp ? 16 : 48,
            alignment: Alignment.centerRight,
            child: vm.isSignUp
                ? const SizedBox.shrink()
                : TextButton(onPressed: vm.isLoading ? null : _openForgotPasswordSheet, child: Text('忘记密码?', style: TextStyle(color: theme.colorScheme.primary))),
          ),

          if (vm.isSignUp) const SizedBox(height: 16),

          FilledButton(
            onPressed: vm.isLoading ? null : _handleAuthAction, // 🟢 统一处理
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: vm.isLoading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(vm.isSignUp ? '立即注册' : '登 录', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
          ),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(vm.isSignUp ? '已经有账号啦？' : '还没有账号？', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              TextButton(
                onPressed: vm.isLoading ? null : () {
                  vm.toggleSignUpMode(); // 🟢 调用 ViewModel 方法
                  _formKey.currentState?.reset();
                },
                child: Text(vm.isSignUp ? '直接登录' : '立即注册', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 找回密码面板 (也享受解耦的福利)
// ==========================================
class ForgotPasswordSheet extends StatefulWidget {
  final String initialEmail;
  const ForgotPasswordSheet({super.key, required this.initialEmail});

  @override
  State<ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<ForgotPasswordSheet> {
  late TextEditingController _emailController;
  bool _isSent = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitReset() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) return;

    final vm = context.read<LoginViewModel>();
    final errorMsg = await vm.resetPassword(email);

    if (!mounted) return;

    if (errorMsg == null) {
      setState(() => _isSent = true); // 成功，仅在此处维护局部UI状态
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final vm = context.watch<LoginViewModel>();

    return Container(
      padding: EdgeInsets.fromLTRB(32, 32, 32, bottomPadding + 32),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: Container(width: 40, height: 5, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)))),
          if (_isSent) ...[
            Icon(Icons.mark_email_read_rounded, size: 64, color: Colors.green.shade400),
            const SizedBox(height: 16),
            Text('魔法信件已送达 🕊️', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('请检查你的邮箱，点击邮件内的链接即可重设密码', textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 32),
            FilledButton.tonal(onPressed: () => Navigator.pop(context), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text('我知道啦')),
          ] else ...[
            Text('找回密码 🗝️', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('不用担心，输入你注册时的邮箱，我们会发一封密码重置邮件给你。', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 24),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(labelText: '注册邮箱', prefixIcon: const Icon(Icons.email_outlined), filled: true, fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: vm.isLoading ? null : _submitReset,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: vm.isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('发送重置链接', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ]
        ],
      ),
    );
  }
}