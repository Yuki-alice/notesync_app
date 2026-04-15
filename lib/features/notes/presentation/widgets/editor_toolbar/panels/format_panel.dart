import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../components/toolbar_button.dart';

class FormatPanel extends StatelessWidget {
  final quill.QuillController controller;
  const FormatPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            quill.QuillToolbarToggleStyleButton(controller: controller, attribute: quill.Attribute.bold, options: _getToggleOptions(context, Icons.format_bold_outlined, '加粗')),
            quill.QuillToolbarToggleStyleButton(controller: controller, attribute: quill.Attribute.italic, options: _getToggleOptions(context, Icons.format_italic_outlined, '斜体')),
            quill.QuillToolbarToggleStyleButton(controller: controller, attribute: quill.Attribute.underline, options: _getToggleOptions(context, Icons.format_underlined_outlined, '下划线')),
            quill.QuillToolbarToggleStyleButton(controller: controller, attribute: quill.Attribute.strikeThrough, options: _getToggleOptions(context, Icons.format_strikethrough_outlined, '删除线')),
            const ToolbarDivider(),
            quill.QuillToolbarToggleStyleButton(controller: controller, attribute: quill.Attribute.leftAlignment, options: _getToggleOptions(context, Icons.format_align_left_outlined, '左对齐')),
            quill.QuillToolbarToggleStyleButton(controller: controller, attribute: quill.Attribute.centerAlignment, options: _getToggleOptions(context, Icons.format_align_center_outlined, '居中对齐')),
            quill.QuillToolbarToggleStyleButton(controller: controller, attribute: quill.Attribute.rightAlignment, options: _getToggleOptions(context, Icons.format_align_right_outlined, '右对齐')),
            const ToolbarDivider(),
            Row(mainAxisSize: MainAxisSize.min, children: [quill.QuillToolbarColorButton(controller: controller, isBackground: false, options: _getColorOptions(context, '字体颜色', Icons.format_color_text_outlined))]),
            Row(mainAxisSize: MainAxisSize.min, children: [quill.QuillToolbarColorButton(controller: controller, isBackground: true, options: _getColorOptions(context, '背景高亮', Icons.format_color_fill_outlined))]),
            const ToolbarDivider(),
            quill.QuillToolbarLinkStyleButton(controller: controller, options: quill.QuillToolbarLinkStyleButtonOptions(tooltip: '插入链接', iconData: Icons.link_outlined, iconTheme: quill.QuillIconTheme(iconButtonUnselectedData: quill.IconButtonData(style: IconButton.styleFrom(foregroundColor: theme.colorScheme.onSurfaceVariant, iconSize: 22))))),
            quill.QuillToolbarClearFormatButton(controller: controller, options: quill.QuillToolbarClearFormatButtonOptions(tooltip: '清除格式', iconData: Icons.format_clear_outlined, iconTheme: quill.QuillIconTheme(iconButtonUnselectedData: quill.IconButtonData(style: IconButton.styleFrom(foregroundColor: theme.colorScheme.onSurfaceVariant, iconSize: 22))))),
          ],
        ),
      ),
    );
  }

  quill.QuillToolbarToggleStyleButtonOptions _getToggleOptions(BuildContext context, IconData icon, String tooltip) {
    final theme = Theme.of(context);
    return quill.QuillToolbarToggleStyleButtonOptions(
      iconData: icon, tooltip: tooltip,
      iconTheme: quill.QuillIconTheme(
        iconButtonSelectedData: quill.IconButtonData(style: IconButton.styleFrom(backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12), foregroundColor: theme.colorScheme.primary, iconSize: 22)),
        iconButtonUnselectedData: quill.IconButtonData(style: IconButton.styleFrom(foregroundColor: theme.colorScheme.onSurfaceVariant, iconSize: 22)),
      ),
    );
  }

  quill.QuillToolbarColorButtonOptions _getColorOptions(BuildContext context, String tooltip, IconData icon) {
    final theme = Theme.of(context);
    return quill.QuillToolbarColorButtonOptions(
      tooltip: tooltip, iconData: icon,
      iconTheme: quill.QuillIconTheme(iconButtonUnselectedData: quill.IconButtonData(style: IconButton.styleFrom(foregroundColor: theme.colorScheme.onSurfaceVariant, iconSize: 22))),
    );
  }
}