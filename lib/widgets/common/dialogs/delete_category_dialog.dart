import 'package:flutter/material.dart';
import 'app_dialog.dart';

Future<bool?> showDeleteCategoryDialog(BuildContext context, String categoryName) {
  return AppDialog.showConfirm(
    context: context,
    title: '删除分类',
    // 换行让排版更美观，并消除用户的顾虑
    content: '确定要删除 "$categoryName" 吗？\n该分类下的笔记不会被删除，将变为"未分类"状态。',
    icon: Icons.delete_sweep_rounded, // 扫帚图标
    confirmText: '确认删除',
    isDestructive: true, // 🌟 自动变为危险操作的红色样式
  );
}