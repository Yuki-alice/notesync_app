import 'package:flutter/material.dart';

import '../../../models/note.dart';


void showNoteDetailDialog(BuildContext context, Note note) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(note.title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(note.content),
            const SizedBox(height: 20),
            Text('创建时间: ${note.formattedCreatedAt}'),
            Text('更新时间: ${note.formattedUpdatedAt}'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}