import 'package:flutter/material.dart';

import '../../../models/note.dart';


Future<Note?> showCreateNoteDialog({
  required BuildContext context,
  Note? existingNote, // 编辑时传入现有笔记
}) {
  final titleController = TextEditingController(
    text: existingNote?.title ?? '',
  );
  final contentController = TextEditingController(
    text: existingNote?.content ?? '',
  );

  return showDialog<Note>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(existingNote == null ? '创建笔记' : '编辑笔记'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: '标题',
                hintText: '输入笔记标题',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: '内容',
                hintText: '输入笔记内容',
                alignLabelWithHint: true,
              ),
              maxLines: 5,
            ),
          ],
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
                const SnackBar(content: Text('标题不能为空')),
              );
              return;
            }

            final note = existingNote?.copyWith(
              title: titleController.text,
              content: contentController.text,
              updatedAt: DateTime.now(),
            ) ?? Note(
              id: '', // 由Provider生成UUID
              title: titleController.text,
              content: contentController.text,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            Navigator.pop(ctx, note);
          },
          child: Text(existingNote == null ? '创建' : '保存'),
        ),
      ],
    ),
  );
}