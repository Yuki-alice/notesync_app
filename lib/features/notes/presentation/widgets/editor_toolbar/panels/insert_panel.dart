import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../components/toolbar_button.dart';
import '../editor_bottom_toolbar.dart';


class InsertPanel extends StatelessWidget {
  final quill.QuillController controller;
  final VoidCallback onPickImage;
  final ValueChanged<ToolbarPanel> onPanelChanged;

  const InsertPanel({super.key, required this.controller, required this.onPickImage, required this.onPanelChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            ToolbarIconButton(icon: Icons.image_outlined, tooltip: '插入图片', onPressed: () { onPickImage(); onPanelChanged(ToolbarPanel.none); }),
            const ToolbarDivider(),
            ToolbarIconButton(icon: Icons.format_size_outlined, tooltip: '大标题', onPressed: () { controller.formatSelection(quill.Attribute.h1); onPanelChanged(ToolbarPanel.none); }),
            ToolbarIconButton(icon: Icons.title_outlined, tooltip: '中标题', onPressed: () { controller.formatSelection(quill.Attribute.h2); onPanelChanged(ToolbarPanel.none); }),
            ToolbarIconButton(icon: Icons.text_format_outlined, tooltip: '小标题', onPressed: () { controller.formatSelection(quill.Attribute.h3); onPanelChanged(ToolbarPanel.none); }),
            const ToolbarDivider(),
            ToolbarIconButton(icon: Icons.check_box_outlined, tooltip: '待办清单', onPressed: () { controller.formatSelection(quill.Attribute.unchecked); onPanelChanged(ToolbarPanel.none); }),
            ToolbarIconButton(icon: Icons.format_list_bulleted_outlined, tooltip: '无序列表', onPressed: () { controller.formatSelection(quill.Attribute.ul); onPanelChanged(ToolbarPanel.none); }),
            ToolbarIconButton(icon: Icons.format_list_numbered_outlined, tooltip: '有序列表', onPressed: () { controller.formatSelection(quill.Attribute.ol); onPanelChanged(ToolbarPanel.none); }),
            const ToolbarDivider(),
            ToolbarIconButton(icon: Icons.format_quote_outlined, tooltip: '引用块', onPressed: () { controller.formatSelection(quill.Attribute.blockQuote); onPanelChanged(ToolbarPanel.none); }),
            ToolbarIconButton(icon: Icons.code_outlined, tooltip: '代码块', onPressed: () { controller.formatSelection(quill.Attribute.codeBlock); onPanelChanged(ToolbarPanel.none); }),
          ],
        ),
      ),
    );
  }
}