import 'package:flutter/material.dart';

Future<String?> showCreateTodoDialog(BuildContext context) {
  final titleController = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('创建待办'),
      content: TextField(
        controller: titleController,
        decoration: const InputDecoration(
          labelText: '待办标题',
          hintText: '输入待办内容',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (titleController.text.isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('待办标题不能为空')),
              );
              return;
            }
            Navigator.pop(ctx, titleController.text);
          },
          child: const Text('创建'),
        ),
      ],
    ),
  );
}