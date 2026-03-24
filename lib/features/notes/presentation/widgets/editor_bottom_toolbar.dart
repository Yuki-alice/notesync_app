import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

enum ToolbarPanel { none, format, insert }

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
    final panelBgColor = theme.colorScheme.surface;
    final iconColor = theme.colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: panelBgColor,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🌟 二级面板
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.fastOutSlowIn,
              child: activePanel != ToolbarPanel.none
                  ? Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
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
                  child: activePanel == ToolbarPanel.format
                      ? _buildFormatPanel(context)
                      : _buildInsertPanel(context),
                ),
              )
                  : const SizedBox.shrink(),
            ),

            // 🌟 一级工具栏主轴
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  _buildPanelToggleButton(
                      context,
                      panel: ToolbarPanel.insert,
                      icon: Icons.add_rounded,
                      isRotatingIcon: true
                  ),
                  const SizedBox(width: 6),
                  _buildPanelToggleButton(
                      context,
                      panel: ToolbarPanel.format,
                      text: 'Aa'
                  ),

                  const SizedBox(width: 8),
                  _buildDivider(context),
                  const SizedBox(width: 8),

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
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
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

  Widget _buildPanelToggleButton(BuildContext context, {required ToolbarPanel panel, IconData? icon, String? text, bool isRotatingIcon = false}) {
    final theme = Theme.of(context);
    final isActive = activePanel == panel;
    final color = isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => onPanelChanged(isActive ? ToolbarPanel.none : panel),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null)
                isRotatingIcon
                    ? AnimatedRotation(
                  turns: isActive ? 0.125 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(icon, size: 24, color: color),
                )
                    : Icon(icon, size: 22, color: color),
              if (text != null)
                Text(
                  text,
                  style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: -0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================
  // 🌟 全新纯图标流插入面板 (与格式面板视觉完全统一)
  // ==============================================
  Widget _buildInsertPanel(BuildContext context) {
    return Container(
      key: const ValueKey(ToolbarPanel.insert),
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _ToolbarIconButton(
                icon: Icons.image_outlined,
                tooltip: '插入图片',
                onPressed: () {
                  onPickImage();
                  onPanelChanged(ToolbarPanel.none);
                }
            ),
            _buildDivider(context),

            _ToolbarIconButton(icon: Icons.format_size_outlined, tooltip: '大标题', onPressed: () { controller.formatSelection(quill.Attribute.h1); onPanelChanged(ToolbarPanel.none); }),
            _ToolbarIconButton(icon: Icons.title_outlined, tooltip: '中标题', onPressed: () { controller.formatSelection(quill.Attribute.h2); onPanelChanged(ToolbarPanel.none); }),
            _ToolbarIconButton(icon: Icons.text_format_outlined, tooltip: '小标题', onPressed: () { controller.formatSelection(quill.Attribute.h3); onPanelChanged(ToolbarPanel.none); }),
            _buildDivider(context),

            _ToolbarIconButton(icon: Icons.check_box_outlined, tooltip: '待办清单', onPressed: () { controller.formatSelection(quill.Attribute.unchecked); onPanelChanged(ToolbarPanel.none); }),
            _ToolbarIconButton(icon: Icons.format_list_bulleted_outlined, tooltip: '无序列表', onPressed: () { controller.formatSelection(quill.Attribute.ul); onPanelChanged(ToolbarPanel.none); }),
            _ToolbarIconButton(icon: Icons.format_list_numbered_outlined, tooltip: '有序列表', onPressed: () { controller.formatSelection(quill.Attribute.ol); onPanelChanged(ToolbarPanel.none); }),
            _buildDivider(context),

            _ToolbarIconButton(icon: Icons.format_quote_outlined, tooltip: '引用块', onPressed: () { controller.formatSelection(quill.Attribute.blockQuote); onPanelChanged(ToolbarPanel.none); }),
            _ToolbarIconButton(icon: Icons.code_outlined, tooltip: '代码块', onPressed: () { controller.formatSelection(quill.Attribute.codeBlock); onPanelChanged(ToolbarPanel.none); }),
          ],
        ),
      ),
    );
  }

  // ==============================================
  // 🌟 文本格式刷面板
  // ==============================================
  Widget _buildFormatPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey(ToolbarPanel.format),
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            quill.QuillToolbarToggleStyleButton(controller: controller, attribute: quill.Attribute.bold, options: _getToggleStyleOptions(context, Icons.format_bold_outlined, tooltip: '加粗')),
            quill.QuillToolbarToggleStyleButton(controller: controller, attribute: quill.Attribute.italic, options: _getToggleStyleOptions(context, Icons.format_italic_outlined, tooltip: '斜体')),
            quill.QuillToolbarToggleStyleButton(controller: controller, attribute: quill.Attribute.underline, options: _getToggleStyleOptions(context, Icons.format_underlined_outlined, tooltip: '下划线')),
            quill.QuillToolbarToggleStyleButton(controller: controller, attribute: quill.Attribute.strikeThrough, options: _getToggleStyleOptions(context, Icons.format_strikethrough_outlined, tooltip: '删除线')),
            _buildDivider(context),

            quill.QuillToolbarToggleStyleButton(controller: controller, attribute: quill.Attribute.leftAlignment, options: _getToggleStyleOptions(context, Icons.format_align_left_outlined, tooltip: '左对齐')),
            quill.QuillToolbarToggleStyleButton(controller: controller, attribute: quill.Attribute.centerAlignment, options: _getToggleStyleOptions(context, Icons.format_align_center_outlined, tooltip: '居中对齐')),
            quill.QuillToolbarToggleStyleButton(controller: controller, attribute: quill.Attribute.rightAlignment, options: _getToggleStyleOptions(context, Icons.format_align_right_outlined, tooltip: '右对齐')),
            _buildDivider(context),

            Row(mainAxisSize: MainAxisSize.min, children: [quill.QuillToolbarColorButton(controller: controller, isBackground: false, options: _getColorButtonOptions(context, '字体颜色', iconData: Icons.format_color_text_outlined))]),
            Row(mainAxisSize: MainAxisSize.min, children: [quill.QuillToolbarColorButton(controller: controller, isBackground: true, options: _getColorButtonOptions(context, '背景高亮', iconData: Icons.format_color_fill_outlined))]),
            _buildDivider(context),

            quill.QuillToolbarLinkStyleButton(
              controller: controller,
              options: quill.QuillToolbarLinkStyleButtonOptions(
                tooltip: '插入链接',
                iconData: Icons.link_outlined,
                iconTheme: quill.QuillIconTheme(
                  iconButtonUnselectedData: quill.IconButtonData(style: IconButton.styleFrom(foregroundColor: theme.colorScheme.onSurfaceVariant, iconSize: 22)),
                ),
              ),
            ),
            quill.QuillToolbarClearFormatButton(
              controller: controller,
              options: quill.QuillToolbarClearFormatButtonOptions(
                tooltip: '清除格式',
                iconData: Icons.format_clear_outlined,
                iconTheme: quill.QuillIconTheme(iconButtonUnselectedData: quill.IconButtonData(style: IconButton.styleFrom(foregroundColor: theme.colorScheme.onSurfaceVariant, iconSize: 22))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      height: 16, width: 1,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  quill.QuillToolbarToggleStyleButtonOptions _getToggleStyleOptions(BuildContext context, IconData icon, {String? tooltip}) {
    final theme = Theme.of(context);
    return quill.QuillToolbarToggleStyleButtonOptions(
      iconData: icon, tooltip: tooltip,
      iconTheme: quill.QuillIconTheme(
        iconButtonSelectedData: quill.IconButtonData(
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            foregroundColor: theme.colorScheme.primary, iconSize: 22,
          ),
        ),
        iconButtonUnselectedData: quill.IconButtonData(
          style: IconButton.styleFrom(foregroundColor: theme.colorScheme.onSurfaceVariant, iconSize: 22),
        ),
      ),
    );
  }

  quill.QuillToolbarColorButtonOptions _getColorButtonOptions(BuildContext context, String tooltip, {IconData? iconData}) {
    final theme = Theme.of(context);
    return quill.QuillToolbarColorButtonOptions(
      tooltip: tooltip, iconData: iconData,
      iconTheme: quill.QuillIconTheme(
        iconButtonUnselectedData: quill.IconButtonData(style: IconButton.styleFrom(foregroundColor: theme.colorScheme.onSurfaceVariant, iconSize: 22)),
      ),
    );
  }
}

// 🌟 修改了图标按钮，让其支持传入 Tooltip 并去除了外层 Padding 导致的大小不一
class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;
  final Color? activeColor;
  final Color? inactiveColor;
  final String? tooltip;

  const _ToolbarIconButton({
    required this.icon,
    required this.onPressed,
    this.isActive = false,
    this.activeColor,
    this.inactiveColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aColor = activeColor ?? theme.colorScheme.primary;
    final iColor = inactiveColor ?? theme.colorScheme.onSurfaceVariant;

    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isActive ? aColor.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed, icon: Icon(icon), color: isActive ? aColor : iColor,
        iconSize: 22, padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}