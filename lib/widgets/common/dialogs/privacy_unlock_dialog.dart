import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/privacy_service.dart';

/// 显示隐私解锁对话框
/// 
/// [context]: BuildContext
/// 
/// 返回: true = 解锁成功, false = 取消/失败
Future<bool> showPrivacyUnlockDialog(BuildContext context) async {
  // 如果已经解锁，直接放行
  if (PrivacyService().isUnlocked) return true;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
    builder: (context) => const _UnlockDialogContent(),
  );
  return result ?? false;
}

/// 显示隐私设置对话框（首次设置密码）
Future<bool> showPrivacySetupDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
    builder: (context) => const _SetupDialogContent(),
  );
  return result ?? false;
}

// ==================== 解锁对话框 ====================

class _UnlockDialogContent extends StatefulWidget {
  const _UnlockDialogContent();

  @override
  State<_UnlockDialogContent> createState() => _UnlockDialogContentState();
}

class _UnlockDialogContentState extends State<_UnlockDialogContent>
    with SingleTickerProviderStateMixin {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocus = FocusNode();
  String _errorMessage = '';
  bool _isLoading = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _requestFocus();
  }

  void _initAnimations() {
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: 0), weight: 1),
    ]).animate(_shakeController);
  }

  void _requestFocus() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _pinFocus.requestFocus();
    });
  }

  Future<void> _verifyPassword() async {
    final password = _pinController.text;
    if (password.isEmpty) return;

    if (password.length < 4) {
      _triggerError('密码至少需要 4 位');
      return;
    }

    setState(() => _isLoading = true);

    final success = await PrivacyService().unlockWithPassword(password);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context, true);
      } else {
        _triggerError('密码错误');
      }
    }
  }

  void _triggerError(String msg) {
    HapticFeedback.heavyImpact();
    setState(() => _errorMessage = msg);
    _shakeController.forward(from: 0);
    _pinController.clear();
    _requestFocus();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocus.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 400;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: 24,
      ),
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_shakeAnimation.value, 0),
            child: child,
          );
        },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 380,
            maxHeight: size.height * 0.8,
          ),
          padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                blurRadius: 40,
                spreadRadius: 10,
              )
            ],
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // 图标
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_person_rounded,
                  size: 40,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),

              // 标题
              Text(
                "私密空间",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              // 副标题
              Text(
                "请输入安全验证密码",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              // 密码输入框
              TextField(
                controller: _pinController,
                focusNode: _pinFocus,
                obscureText: true,
                obscuringCharacter: '●',
                textAlign: TextAlign.center,
                keyboardType: TextInputType.visiblePassword,
                enabled: !_isLoading,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onSubmitted: (_) => _verifyPassword(),
                onChanged: (v) {
                  if (_errorMessage.isNotEmpty) {
                    setState(() => _errorMessage = '');
                  }
                },
              ),

              // 错误信息
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 13,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        '取消',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isLoading ? null : _verifyPassword,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          : const Text(
                              '解锁',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

}

// ==================== 设置对话框 ====================

class _SetupDialogContent extends StatefulWidget {
  const _SetupDialogContent();

  @override
  State<_SetupDialogContent> createState() => _SetupDialogContentState();
}

class _SetupDialogContentState extends State<_SetupDialogContent> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  String _errorMessage = '';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _requestFocus();
  }

  void _requestFocus() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _passwordFocus.requestFocus();
    });
  }

  Future<void> _setupPrivacy() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    // 验证
    if (password.length < 4) {
      setState(() => _errorMessage = '密码至少需要 4 位');
      return;
    }

    if (password != confirm) {
      setState(() => _errorMessage = '两次输入的密码不一致');
      _confirmController.clear();
      _confirmFocus.requestFocus();
      return;
    }

    setState(() => _isLoading = true);

    try {
      await PrivacyService().setupPassword(password);

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '设置失败: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 400;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 24,
        vertical: 24,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 380,
          maxHeight: size.height * 0.8,
        ),
        padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              blurRadius: 40,
              spreadRadius: 10,
            )
          ],
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // 图标
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shield_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),

            // 标题
            Text(
              "设置私密空间",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),

            // 副标题
            Text(
              "请设置安全密码以保护您的私密笔记",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),

            // 密码输入
            _buildPasswordField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              hint: '设置密码',
              obscure: _obscurePassword,
              onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
              onSubmitted: () => _confirmFocus.requestFocus(),
            ),
            const SizedBox(height: 16),

            // 确认密码
            _buildPasswordField(
              controller: _confirmController,
              focusNode: _confirmFocus,
              hint: '确认密码',
              obscure: _obscureConfirm,
              onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
              onSubmitted: _isLoading ? null : _setupPrivacy,
            ),

            // 错误信息
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _errorMessage,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ),

            const SizedBox(height: 32),

            // 按钮
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      '取消',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _isLoading ? null : _setupPrivacy,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Text(
                            '确认',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required VoidCallback? onSubmitted,
  }) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.visiblePassword,
      enabled: !_isLoading,
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 4,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          onPressed: onToggleObscure,
        ),
      ),
      onSubmitted: (_) => onSubmitted?.call(),
      onChanged: (_) {
        if (_errorMessage.isNotEmpty) setState(() => _errorMessage = '');
      },
    );
  }

}
