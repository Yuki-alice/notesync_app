import 'package:flutter/material.dart';

Future<bool?> showDeleteCategoryDialog(BuildContext context, String categoryName) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _DeleteCategoryDialog(categoryName: categoryName),
  );
}

class _DeleteCategoryDialog extends StatelessWidget {
  final String categoryName;

  const _DeleteCategoryDialog({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surfaceContainerHigh,
      icon: Icon(Icons.delete_forever_rounded, size: 48, color: theme.colorScheme.error),
      title: Text('删除 "$categoryName"?', style: const TextStyle(fontWeight: FontWeight.bold)),
      content: const Text(
        '此分类将被移除。\n属于该分类的笔记不会被删除，它们将变为"未分类"状态。',
        textAlign: TextAlign.center,
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消')
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true), // 🟢 确认删除返回 true
          child: const Text('确认删除'),
        ),
      ],
    );
  }
}