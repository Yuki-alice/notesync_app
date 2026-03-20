import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

enum ToolbarPanel { none, format }

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

    return Container(
      decoration: BoxDecoration(
        color: panelBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 格式面板（二级菜单）
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.fastOutSlowIn,
              child: activePanel != ToolbarPanel.none
                  ? Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SizeTransition(sizeFactor: anim, child: child),
                  ),
                  child: _buildFormatPanel(context),
                ),
              )
                  : const SizedBox.shrink(),
            ),

            // 一级工具栏
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  _ToolbarIconButton(
                    icon: Icons.undo_outlined,
                    onPressed: onUndo,
                    inactiveColor: iconColor,
                  ),
                  _ToolbarIconButton(
                    icon: Icons.redo_outlined,
                    onPressed: onRedo,
                    inactiveColor: iconColor,
                  ),
                  _ToolbarIconButton(
                    icon: Icons.image_outlined,
                    onPressed: onPickImage,
                    inactiveColor: iconColor,
                  ),
                  const SizedBox(width: 4),
                  quill.QuillToolbarToggleStyleButton(
                    controller: controller,
                    attribute: quill.Attribute.unchecked,
                    options: _getToggleStyleOptions(
                      context,
                      Icons.check_circle_outlined,
                      tooltip: '待办清单',
                      isSecondaryPanel: false,
                    ),
                  ),
                  _buildAaButton(context),
                  const Spacer(),
                  FilledButton.tonal(
                    onPressed: onFinish,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      minimumSize: const Size(60, 36),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '完成',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAaButton(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = activePanel == ToolbarPanel.format;
    final color = isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => onPanelChanged(isActive ? ToolbarPanel.none : ToolbarPanel.format),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Aa',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: -0.5,
                ),
              ),
              if (!isActive) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.unfold_more_outlined,
                  size: 14,
                  color: color.withValues(alpha: 0.5),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey(ToolbarPanel.format),
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // 文本样式组
            quill.QuillToolbarToggleStyleButton(
              controller: controller,
              attribute: quill.Attribute.bold,
              options: _getToggleStyleOptions(context, Icons.format_bold_outlined, tooltip: '加粗'),
            ),
            quill.QuillToolbarToggleStyleButton(
              controller: controller,
              attribute: quill.Attribute.italic,
              options: _getToggleStyleOptions(context, Icons.format_italic_outlined, tooltip: '斜体'),
            ),
            quill.QuillToolbarToggleStyleButton(
              controller: controller,
              attribute: quill.Attribute.underline,
              options: _getToggleStyleOptions(context, Icons.format_underlined_outlined, tooltip: '下划线'),
            ),
            quill.QuillToolbarToggleStyleButton(
              controller: controller,
              attribute: quill.Attribute.strikeThrough,
              options: _getToggleStyleOptions(context, Icons.format_strikethrough_outlined, tooltip: '删除线'),
            ),
            _buildDivider(context),

            // 列表组
            quill.QuillToolbarToggleStyleButton(
              controller: controller,
              attribute: quill.Attribute.ul,
              options: _getToggleStyleOptions(context, Icons.format_list_bulleted_outlined, tooltip: '无序列表'),
            ),
            quill.QuillToolbarToggleStyleButton(
              controller: controller,
              attribute: quill.Attribute.ol,
              options: _getToggleStyleOptions(context, Icons.format_list_numbered_outlined, tooltip: '有序列表'),
            ),
            quill.QuillToolbarToggleStyleButton(
              controller: controller,
              attribute: quill.Attribute.blockQuote,
              options: _getToggleStyleOptions(context, Icons.format_quote_outlined, tooltip: '引用'),
            ),
            _buildDivider(context),

            // 标题组
            quill.QuillToolbarToggleStyleButton(
              controller: controller,
              attribute: quill.Attribute.h1,
              options: _getToggleStyleOptions(context, Icons.format_size_outlined, tooltip: '大标题'),
            ),
            quill.QuillToolbarToggleStyleButton(
              controller: controller,
              attribute: quill.Attribute.h2,
              options: _getToggleStyleOptions(context, Icons.title_outlined, tooltip: '中标题'),
            ),
            _buildDivider(context),

            // 颜色与清除格式组
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                quill.QuillToolbarColorButton(
                  controller: controller,
                  isBackground: false,
                  options: _getColorButtonOptions(context, '字体颜色'),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                quill.QuillToolbarColorButton(
                  controller: controller,
                  isBackground: true,
                  options: _getColorButtonOptions(context, '背景高亮', iconData: Icons.format_color_fill_outlined),
                ),
              ],
            ),
            quill.QuillToolbarClearFormatButton(
              controller: controller,
              options: quill.QuillToolbarClearFormatButtonOptions(
                tooltip: '清除格式',
                iconData: Icons.format_clear_outlined,
                iconTheme: quill.QuillIconTheme(
                  iconButtonUnselectedData: quill.IconButtonData(
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                      iconSize: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      height: 16,
      width: 1,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(horizontal: 6),
    );
  }

  quill.QuillToolbarToggleStyleButtonOptions _getToggleStyleOptions(
      BuildContext context,
      IconData icon, {
        String? tooltip,
        bool isSecondaryPanel = true,
      }) {
    final theme = Theme.of(context);
    return quill.QuillToolbarToggleStyleButtonOptions(
      iconData: icon,
      tooltip: tooltip,
      iconTheme: quill.QuillIconTheme(
        iconButtonSelectedData: quill.IconButtonData(
          style: IconButton.styleFrom(
            backgroundColor: isSecondaryPanel
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            foregroundColor: theme.colorScheme.primary,
            iconSize: 22,
          ),
        ),
        iconButtonUnselectedData: quill.IconButtonData(
          style: IconButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            iconSize: 22,
          ),
        ),
      ),
    );
  }

  quill.QuillToolbarColorButtonOptions _getColorButtonOptions(
      BuildContext context,
      String tooltip, {
        IconData? iconData,
      }) {
    final theme = Theme.of(context);
    return quill.QuillToolbarColorButtonOptions(
      tooltip: tooltip,
      iconData: iconData,
      iconTheme: quill.QuillIconTheme(
        iconButtonUnselectedData: quill.IconButtonData(
          style: IconButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            iconSize: 22,
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;
  final Color? activeColor;
  final Color? inactiveColor;

  const _ToolbarIconButton({
    required this.icon,
    required this.onPressed,
    this.isActive = false,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aColor = activeColor ?? theme.colorScheme.primary;
    final iColor = inactiveColor ?? theme.colorScheme.onSurfaceVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isActive ? aColor.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: isActive ? aColor : iColor,
        iconSize: 22,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ),
    );
  }
}