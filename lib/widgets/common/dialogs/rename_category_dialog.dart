import 'package:flutter/material.dart';


Future<String?> showRenameCategoryDialog(BuildContext context, String oldName) {
  return showDialog<String>(
    context: context,
    builder: (context) => _RenameCategoryDialog(oldName: oldName),
  );
}

class _RenameCategoryDialog extends StatefulWidget {
  final String oldName;
  const _RenameCategoryDialog({required this.oldName});

  @override
  State<_RenameCategoryDialog> createState() => _RenameCategoryDialogState();
}

class _RenameCategoryDialogState extends State<_RenameCategoryDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.oldName);
  }

  @override
  void dispose() {
    _controller.dispose(); // 🟢 释放资源
    super.dispose();
  }

  void _submit() {
    final newName = _controller.text.trim();
    if (newName.isNotEmpty && newName != widget.oldName) {
      Navigator.pop(context, newName);
    } else {
      Navigator.pop(context); // 没修改则当做取消处理
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('重命名分类'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(), // 支持回车提交
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '该分类下的所有笔记将自动更新',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}