// 文件路径: lib/features/auth/presentation/views/login_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 🟢 1. 引入表单全局 Key，用于严格校验
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // 🟢 2. 引入焦点控制，优化键盘交互
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true; // 密码是否隐藏

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // 🟢 3. 商业级报错翻译引擎
  String _translateAuthError(String message) {
    final msg = message.toLowerCase();
    if (msg.contains('invalid login credentials')) return '邮箱或密码错误，请重试';
    if (msg.contains('user already registered')) return '该邮箱已注册，请直接登录';
    if (msg.contains('password should be at least')) return '密码安全性太弱，不能少于 6 位';
    if (msg.contains('unable to validate email')) return '请输入有效的邮箱地址';
    if (msg.contains('rate limit')) return '操作太频繁了，请稍后再试';
    return '验证失败，请稍后再试 ($message)';
  }

  Future<void> _authenticate() async {
    // 触发 Form 的 validator 校验，如果不通过直接拦截
    if (!_formKey.currentState!.validate()) return;

    // 隐藏软键盘
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        // 注册新用户
        await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🎉 账号创建成功！'), backgroundColor: Colors.green),
          );
        }

        // Supabase 注册后如果不强制邮箱验证，会自动登录。我们判断一下：
        if (mounted && Supabase.instance.client.auth.currentUser != null) {
          Navigator.pop(context);
        } else {
          setState(() => _isSignUp = false); // 切换回登录 UI 让用户手动登录
        }
      } else {
        // 登录
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ 登录成功，正在开启云端同步...'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_translateAuthError(e.message)), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('发生未知网络错误，请检查网络连接'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🟢 4. 忘记密码的业务流
  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先在上方输入您注册时的邮箱'), behavior: SnackBarBehavior.floating),
      );
      _emailFocus.requestFocus();
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('重置邮件已发送 📧'),
            content: Text('我们已向\n$email\n发送了一封包含重置密码链接的邮件，请查收。'),
            actions: [
              FilledButton.tonal(onPressed: () => Navigator.pop(ctx), child: const Text('我知道了')),
            ],
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_translateAuthError(e.message)), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // 🟢 终极商业级表单布局：CustomScrollView 完美解决居中与键盘滚动的冲突
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false, // 核心魔法：屏幕高度够时完美居中，不够时自动允许滚动
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center, // 🟢 现在居中终于生效了！
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(Icons.cloud_sync_rounded, size: 80, color: theme.colorScheme.primary),
                        const SizedBox(height: 24),
                        Text(
                          _isSignUp ? '创建 NoteSync 账号' : '欢迎回来',
                          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isSignUp ? '跨设备无缝同步您的灵感与待办' : '登录以开启极速的云端同步',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),

                        // 🟢 修复：删除了局部的 border 定义，完美继承全局的无边框灰色质感
                        TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocus,
                          enabled: !_isLoading,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return '邮箱不能为空';
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return '请输入正确的邮箱格式';
                            return null;
                          },
                          decoration: const InputDecoration(
                            labelText: '邮箱地址',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 20),

                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          enabled: !_isLoading,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _authenticate(),
                          validator: (value) {
                            if (value == null || value.isEmpty) return '密码不能为空';
                            if (value.length < 6) return '密码长度不能少于 6 位';
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: '密码',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),

                        if (!_isSignUp)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading ? null : _resetPassword,
                              child: Text('忘记密码?', style: TextStyle(color: theme.colorScheme.secondary)),
                            ),
                          )
                        else
                          const SizedBox(height: 24),

                        const SizedBox(height: 16),

                        FilledButton(
                          onPressed: _isLoading ? null : _authenticate,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _isLoading
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(
                            _isSignUp ? '立即注册' : '登 录',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isSignUp ? '已有账号？' : '没有账号？',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                            ),
                            TextButton(
                              onPressed: _isLoading ? null : () {
                                setState(() {
                                  _isSignUp = !_isSignUp;
                                  _formKey.currentState?.reset();
                                });
                              },
                              child: Text(_isSignUp ? '直接登录' : '立即注册', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}