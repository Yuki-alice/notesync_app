import 'package:flutter/material.dart';

Future<Map<String, String>?> showLoginDialog(BuildContext context) {
  final emailController = TextEditingController();
  final nameController = TextEditingController();

  return showDialog<Map<String, String>?>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('登录/注册'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: '用户名',
              hintText: '输入你的昵称',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: '邮箱',
              hintText: '输入你的邮箱',
            ),
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (nameController.text.isEmpty || emailController.text.isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('用户名和邮箱不能为空')),
              );
              return;
            }
            Navigator.pop(ctx, {
              'name': nameController.text,
              'email': emailController.text,
            });
          },
          child: const Text('确认'),
        ),
      ],
    ),
  );
}