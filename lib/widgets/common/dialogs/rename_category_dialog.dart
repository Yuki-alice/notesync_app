import 'package:flutter/material.dart';
import 'app_dialog.dart';

Future<String?> showRenameCategoryDialog(BuildContext context, String currentName) {
  return AppDialog.showInput(
    context: context,
    title: '重命名分类',
    initialText: currentName, // 传入当前的名字
    hintText: '请输入新的分类名称',
    icon: Icons.drive_file_rename_outline_rounded, // 圆润的编辑图标
    confirmText: '保存修改',
  );
}