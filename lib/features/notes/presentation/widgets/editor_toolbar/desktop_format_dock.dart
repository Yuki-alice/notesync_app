import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'components/toolbar_button.dart';

class DesktopFormatDock extends StatelessWidget {
  final quill.QuillController controller;
  final VoidCallback onPickImage;

  const DesktopFormatDock({
    super.key,
    required this.controller,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 🌟 苹果级毛玻璃悬浮坞
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 文本层级
              ToolbarIconButton(icon: Icons.format_size_rounded, tooltip: '大标题', onPressed: () => controller.formatSelection(quill.Attribute.h1)),
              ToolbarIconButton(icon: Icons.title_rounded, tooltip: '中标题', onPressed: () => controller.formatSelection(quill.Attribute.h2)),
              const ToolbarDivider(),

              // 核心格式
              quill.QuillToolbarToggleStyleButton(controller: controller, attribute: quill.Attribute.bold, options: _getOptions(context, Icons.format_bold_rounded, '加粗')),
              quill.QuillToolbarToggleStyleButton(controller: controller, attribute: quill.Attribute.italic, options: _getOptions(context, Icons.format_italic_rounded, '斜体')),
              quill.QuillToolbarToggleStyleButton(controller: controller, attribute: quill.Attribute.underline, options: _getOptions(context, Icons.format_underlined_rounded, '下划线')),
              quill.QuillToolbarToggleStyleButton(controller: controller, attribute: quill.Attribute.strikeThrough, options: _getOptions(context, Icons.format_strikethrough_rounded, '删除线')),
              const ToolbarDivider(),

              // 高级插入
              ToolbarIconButton(icon: Icons.format_list_bulleted_rounded, tooltip: '无序列表', onPressed: () => controller.formatSelection(quill.Attribute.ul)),
              ToolbarIconButton(icon: Icons.check_box_outlined, tooltip: '待办清单', onPressed: () => controller.formatSelection(quill.Attribute.unchecked)),
              ToolbarIconButton(icon: Icons.format_quote_rounded, tooltip: '引用块', onPressed: () => controller.formatSelection(quill.Attribute.blockQuote)),
              ToolbarIconButton(icon: Icons.code_rounded, tooltip: '代码块', onPressed: () => controller.formatSelection(quill.Attribute.codeBlock)),
              const ToolbarDivider(),

              // 媒体插入
              ToolbarIconButton(icon: Icons.image_outlined, tooltip: '插入图片', onPressed: onPickImage),
            ],
          ),
        ),
      ),
    );
  }

  quill.QuillToolbarToggleStyleButtonOptions _getOptions(BuildContext context, IconData icon, String tooltip) {
    final theme = Theme.of(context);
    return quill.QuillToolbarToggleStyleButtonOptions(
      iconData: icon, tooltip: tooltip,
      iconTheme: quill.QuillIconTheme(
        iconButtonSelectedData: quill.IconButtonData(style: IconButton.styleFrom(backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15), foregroundColor: theme.colorScheme.primary, iconSize: 22)),
        iconButtonUnselectedData: quill.IconButtonData(style: IconButton.styleFrom(foregroundColor: theme.colorScheme.onSurfaceVariant, iconSize: 22)),
      ),
    );
  }
}