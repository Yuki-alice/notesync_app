import 'package:flutter/material.dart';
import '../../../../../widgets/common/dialogs/app_dialog.dart';


Future<String?> showAddTagDialog(BuildContext context) {
  return AppDialog.showInput(
    context: context,
    title: '添加标签',
    subtitle: '贴上专属标签，方便日后寻找哦',
    hintText: '例如：灵感、重要、读书笔记...',
    // 采用圆润的标签专属图标
    icon: Icons.local_offer_rounded,
    confirmText: '添加',
  );
}