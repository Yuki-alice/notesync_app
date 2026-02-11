import 'package:flutter/material.dart';

Future<String?> showAddTagDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _AddTagDialog(),
  );
}

class _AddTagDialog extends StatefulWidget {
  const _AddTagDialog();

  @override
  State<_AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<_AddTagDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _isValid = _controller.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surfaceContainerHigh, // MD3 弹窗背景
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), // 大圆角

      title: Row(
        children: [
          Icon(Icons.local_offer_rounded, color: theme.colorScheme.primary, size: 24),
          const SizedBox(width: 12),
          Text('添加标签', style: theme.textTheme.headlineSmall?.copyWith(fontSize: 22)),
        ],
      ),

      content: TextField(
        controller: _controller,
        autofocus: true,
        style: TextStyle(color: theme.colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: '输入标签名称',
          hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          // 前缀符号 #
          prefixText: '# ',
          prefixStyle: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 16
          ),
        ),
        onSubmitted: (value) {
          if (_isValid) Navigator.pop(context, value.trim());
        },
      ),

      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurfaceVariant,
          ),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isValid ? () => Navigator.pop(context, _controller.text.trim()) : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Text('添加'),
        ),
      ],
    );
  }
}