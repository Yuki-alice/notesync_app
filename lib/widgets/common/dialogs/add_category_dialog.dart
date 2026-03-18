import 'package:flutter/material.dart';
import 'app_dialog.dart';

Future<String?> showAddCategoryDialog(BuildContext context) {
  return AppDialog.showInput(
    context: context,
    title: '新建分类',
    hintText: '例如：学习、工作...',
    icon: Icons.create_new_folder_rounded, // 圆润的文件夹图标
    confirmText: '创建',
  );
}