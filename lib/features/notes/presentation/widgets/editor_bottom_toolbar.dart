import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

// 定义工具栏激活面板枚举
enum ToolbarPanel { none, textStyle, paragraphStyle, color }

class EditorBottomToolbar extends StatelessWidget {
  final quill.QuillController controller;
  final ToolbarPanel activePanel;
  final ValueChanged<ToolbarPanel> onPanelChanged;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onPickImage;
  final VoidCallback onFinish;

  const EditorBottomToolbar({
    super.key,
    required this.controller,
    required this.activePanel,
    required this.onPanelChanged,
    required this.onUndo,
    required this.onRedo,
    required this.onPickImage,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final panelBgColor = theme.colorScheme.surfaceContainer;
    final iconColor = theme.colorScheme.onSurfaceVariant;
    final activeIconColor = theme.colorScheme.primary;
    const double toolbarIconSize = 24;

    return Container(
      decoration: BoxDecoration(
        color: panelBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 动态面板区域 (样式、颜色选择器等)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
            child: activePanel != ToolbarPanel.none
                ? Container(
              decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.15),
                        width: 0.8)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    panelBgColor.withOpacity(0.95),
                    panelBgColor,
                  ],
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SizeTransition(sizeFactor: anim, child: child)),
                child: _buildActivePanelContent(context),
              ),
            )
                : const SizedBox.shrink(),
          ),

          // 固定工具栏按钮行
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _ToolbarIconButton(
                            icon: Icons.undo_rounded,
                            tooltip: '撤销',
                            onPressed: onUndo,
                            isActive: false,
                            activeColor: activeIconColor,
                            inactiveColor: iconColor,
                            iconSize: toolbarIconSize),
                        const SizedBox(width: 8),
                        _ToolbarIconButton(
                            icon: Icons.redo_rounded,
                            tooltip: '重做',
                            onPressed: onRedo,
                            isActive: false,
                            activeColor: activeIconColor,
                            inactiveColor: iconColor,
                            iconSize: toolbarIconSize),
                        Container(
                            height: 20,
                            width: 1,
                            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                            margin: const EdgeInsets.symmetric(horizontal: 12)),
                        _ToolbarIconButton(
                            icon: Icons.text_fields_outlined,
                            tooltip: '文本样式',
                            isActive: activePanel == ToolbarPanel.textStyle,
                            onPressed: () => onPanelChanged(ToolbarPanel.textStyle),
                            activeColor: activeIconColor,
                            inactiveColor: iconColor,
                            iconSize: toolbarIconSize),
                        const SizedBox(width: 8),
                        _ToolbarIconButton(
                            icon: Icons.text_snippet_outlined,
                            tooltip: '段落样式',
                            isActive: activePanel == ToolbarPanel.paragraphStyle,
                            onPressed: () => onPanelChanged(ToolbarPanel.paragraphStyle),
                            activeColor: activeIconColor,
                            inactiveColor: iconColor,
                            iconSize: toolbarIconSize),
                        const SizedBox(width: 8),
                        _ToolbarIconButton(
                            icon: Icons.palette_outlined,
                            tooltip: '颜色',
                            isActive: activePanel == ToolbarPanel.color,
                            onPressed: () => onPanelChanged(ToolbarPanel.color),
                            activeColor: activeIconColor,
                            inactiveColor: iconColor,
                            iconSize: toolbarIconSize),
                        const SizedBox(width: 8),
                        _ToolbarIconButton(
                            icon: Icons.insert_photo_outlined,
                            tooltip: '插入图片',
                            isActive: false,
                            onPressed: onPickImage,
                            activeColor: activeIconColor,
                            inactiveColor: iconColor,
                            iconSize: toolbarIconSize),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: onFinish,
                  style: FilledButton.styleFrom(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('完成', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePanelContent(BuildContext context) {
    final theme = Theme.of(context);
    switch (activePanel) {
      case ToolbarPanel.textStyle:
        return _buildPanelRow([
          quill.QuillToolbarToggleStyleButton(
              controller: controller,
              attribute: quill.Attribute.bold,
              options: _getToggleStyleOptions(context, Icons.format_bold_rounded,
                  tooltip: '加粗')),
          quill.QuillToolbarToggleStyleButton(
              controller: controller,
              attribute: quill.Attribute.italic,
              options: _getToggleStyleOptions(context, Icons.format_italic_rounded,
                  tooltip: '斜体')),
          quill.QuillToolbarToggleStyleButton(
              controller: controller,
              attribute: quill.Attribute.underline,
              options: _getToggleStyleOptions(
                  context, Icons.format_underlined_rounded,
                  tooltip: '下划线')),
          quill.QuillToolbarToggleStyleButton(
              controller: controller,
              attribute: quill.Attribute.strikeThrough,
              options: _getToggleStyleOptions(
                  context, Icons.format_strikethrough_rounded,
                  tooltip: '删除线')),
          quill.QuillToolbarToggleStyleButton(
              controller: controller,
              attribute: quill.Attribute.inlineCode,
              options: _getToggleStyleOptions(context, Icons.code_rounded,
                  tooltip: '代码')),
        ]);
      case ToolbarPanel.paragraphStyle:
        return _buildPanelRow([
          quill.QuillToolbarToggleStyleButton(
              controller: controller,
              attribute: quill.Attribute.h1,
              options: _getToggleStyleOptions(context, Icons.looks_one_rounded,
                  tooltip: '标题 1')),
          quill.QuillToolbarToggleStyleButton(
              controller: controller,
              attribute: quill.Attribute.h2,
              options: _getToggleStyleOptions(context, Icons.looks_two_rounded,
                  tooltip: '标题 2')),
          quill.QuillToolbarToggleStyleButton(
              controller: controller,
              attribute: quill.Attribute.ul,
              options: _getToggleStyleOptions(
                  context, Icons.format_list_bulleted_rounded,
                  tooltip: '无序列表')),
          quill.QuillToolbarToggleStyleButton(
              controller: controller,
              attribute: quill.Attribute.ol,
              options: _getToggleStyleOptions(
                  context, Icons.format_list_numbered_rounded,
                  tooltip: '有序列表')),
          quill.QuillToolbarToggleStyleButton(
              controller: controller,
              attribute: quill.Attribute.blockQuote,
              options: _getToggleStyleOptions(context, Icons.format_quote_rounded,
                  tooltip: '引用')),
        ]);
      case ToolbarPanel.color:
        return _buildPanelRow([
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text("A",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            quill.QuillToolbarColorButton(
                controller: controller,
                isBackground: false,
                options: _getColorButtonOptions(context, '字体颜色',
                    iconData: Icons.format_color_text_outlined))
          ]),
          const SizedBox(width: 20),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.highlight_rounded, size: 18),
            quill.QuillToolbarColorButton(
                controller: controller,
                isBackground: true,
                options: _getColorButtonOptions(context, '背景高亮',
                    iconData: Icons.format_color_fill_outlined))
          ]),
          const SizedBox(width: 20),
          quill.QuillToolbarClearFormatButton(
              controller: controller,
              options: quill.QuillToolbarClearFormatButtonOptions(
                  tooltip: '清除格式',
                  iconData: Icons.format_clear_rounded,
                  iconTheme: quill.QuillIconTheme(
                      iconButtonUnselectedData: quill.IconButtonData(
                          style: IconButton.styleFrom(
                              foregroundColor: theme.colorScheme.onSurface))))),
        ]);
      case ToolbarPanel.none:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPanelRow(List<Widget> children) {
    return Container(
        key: ValueKey(activePanel),
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center, children: children)));
  }

  // 样式辅助方法
  quill.QuillToolbarToggleStyleButtonOptions _getToggleStyleOptions(
      BuildContext context, IconData icon,
      {String? tooltip, bool isSecondaryPanel = true}) {
    final theme = Theme.of(context);
    return quill.QuillToolbarToggleStyleButtonOptions(
      iconData: icon,
      tooltip: tooltip,
      iconTheme: quill.QuillIconTheme(
          iconButtonSelectedData: quill.IconButtonData(
              style: IconButton.styleFrom(
                  backgroundColor: isSecondaryPanel
                      ? theme.colorScheme.primary.withOpacity(0.1)
                      : theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.primary)),
          iconButtonUnselectedData: quill.IconButtonData(
              style: IconButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7)))),
    );
  }

  quill.QuillToolbarColorButtonOptions _getColorButtonOptions(
      BuildContext context, String tooltip,
      {IconData? iconData}) {
    final theme = Theme.of(context);
    return quill.QuillToolbarColorButtonOptions(
        tooltip: tooltip,
        iconData: iconData,
        iconTheme: quill.QuillIconTheme(
            iconButtonUnselectedData: quill.IconButtonData(
                style: IconButton.styleFrom(
                    foregroundColor:
                    theme.colorScheme.onSurface.withOpacity(0.7)))));
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;
  final Color activeColor;
  final Color inactiveColor;
  final String? tooltip;
  final double iconSize;

  const _ToolbarIconButton(
      {required this.icon,
        required this.isActive,
        required this.onPressed,
        required this.activeColor,
        required this.inactiveColor,
        this.tooltip,
        this.iconSize = 24});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12)),
      child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          tooltip: tooltip,
          color: isActive ? activeColor : inactiveColor,
          iconSize: iconSize,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap)),
    );
  }
}