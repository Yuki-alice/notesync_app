import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';

import '../../../../core/providers/notes_provider.dart';
import '../../../../models/tag.dart';
import '../viewmodels/note_editor_viewmodel.dart';
import 'dialogs/add_tag_dialog.dart';
import 'dialogs/set_category_sheet.dart';

enum ToolbarPanel { none, format, insert, metadata }

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
    // 🌟 修复：定义统一的底色，让上下面板完美融合
    final unifiedBgColor = theme.colorScheme.surface;
    final iconColor = theme.colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: unifiedBgColor,
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
            // 🌟 二级面板动态展示
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.fastOutSlowIn,
              child: activePanel != ToolbarPanel.none
                  ? Container(
                decoration: BoxDecoration(
                  color: unifiedBgColor, // 🌟 修复：使用和下面主轴绝对一致的颜色！
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
                      : (activePanel == ToolbarPanel.insert
                      ? _buildInsertPanel(context)
                      : _buildMetadataPanel(context)),
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
                  const SizedBox(width: 4),
                  _buildPanelToggleButton(
                      context,
                      panel: ToolbarPanel.format,
                      text: 'Aa'
                  ),
                  const SizedBox(width: 4),
                  _buildPanelToggleButton(
                    context,
                    panel: ToolbarPanel.metadata,
                    icon: Icons.local_offer_outlined,
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
  // 🌟 视觉优化后的元数据面板
  // ==============================================
  Widget _buildMetadataPanel(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<NoteEditorViewModel>();
    final notesProvider = context.watch<NotesProvider>();

    final realCategory = notesProvider.getCategoryById(viewModel.categoryId);
    final realTags = viewModel.tagIds.map((id) => notesProvider.getTagById(id)).whereType<Tag>().toList();

    return Container(
      key: const ValueKey(ToolbarPanel.metadata),
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center, // 保证横向绝对居中
          children: [
            // 📁 1. 分类定制按钮
            _PremiumPill(
              icon: realCategory == null ? Icons.folder_open_outlined : Icons.folder_rounded,
              label: realCategory?.name ?? '归入分类',
              color: realCategory == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onPrimaryContainer,
              backgroundColor: realCategory == null ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5) : theme.colorScheme.primaryContainer,
              onTap: viewModel.isReadOnly ? null : () async {
                final selectedName = await showSetCategorySheet(context, currentCategory: realCategory?.name);
                if (selectedName != null) {
                  if (selectedName.isEmpty) {
                    viewModel.setCategoryId(null);
                  } else {
                    final foundCat = notesProvider.categories.firstWhere((c) => c.name == selectedName);
                    viewModel.setCategoryId(foundCat.id);
                  }
                }
              },
            ),

            const SizedBox(width: 4),
            _buildDivider(context),
            const SizedBox(width: 4),

            // 🏷️ 2. 标签流
            ...realTags.map((tag) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: _PremiumTagPill(
                  tag: tag,
                  theme: theme,
                  onDelete: viewModel.isReadOnly ? null : () {
                    HapticFeedback.selectionClick();
                    viewModel.removeTag(tag.id);
                  }
              ),
            )),

            // ➕ 3. 新建标签按钮
            if (!viewModel.isReadOnly)
              _PremiumPill(
                icon: Icons.add_rounded,
                label: '标签',
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                onTap: () async {
                  final newTagName = await showAddTagDialog(context);
                  if (newTagName != null && newTagName.trim().isNotEmpty) {
                    final newTag = await notesProvider.createTag(newTagName.trim());
                    viewModel.addTag(newTag.id);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

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
            _ToolbarIconButton(icon: Icons.image_outlined, tooltip: '插入图片', onPressed: () { onPickImage(); onPanelChanged(ToolbarPanel.none); }),
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
            quill.QuillToolbarLinkStyleButton(controller: controller, options: quill.QuillToolbarLinkStyleButtonOptions(tooltip: '插入链接', iconData: Icons.link_outlined, iconTheme: quill.QuillIconTheme(iconButtonUnselectedData: quill.IconButtonData(style: IconButton.styleFrom(foregroundColor: theme.colorScheme.onSurfaceVariant, iconSize: 22))))),
            quill.QuillToolbarClearFormatButton(controller: controller, options: quill.QuillToolbarClearFormatButtonOptions(tooltip: '清除格式', iconData: Icons.format_clear_outlined, iconTheme: quill.QuillIconTheme(iconButtonUnselectedData: quill.IconButtonData(style: IconButton.styleFrom(foregroundColor: theme.colorScheme.onSurfaceVariant, iconSize: 22))))),
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

// ==============================================
// 🌟 终极 UI 补丁：视觉完全统一且高度绝对锁定的药丸
// ==============================================
class _PremiumPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;
  final VoidCallback? onTap;

  const _PremiumPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 34, // 🌟 修复：锁定绝对高度，无视内部文字撑开的误差
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center, // 🌟 修复：内容强行居中
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumTagPill extends StatelessWidget {
  final Tag tag;
  final ThemeData theme;
  final VoidCallback? onDelete;

  const _PremiumTagPill({
    required this.tag,
    required this.theme,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onDelete,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 34, // 🌟 修复：锁定绝对高度，完美对齐分类按钮
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center, // 🌟 修复：内容强行居中
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('# ${tag.name}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.secondary, letterSpacing: 0.3)),
              if (onDelete != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.close_rounded, size: 14, color: theme.colorScheme.secondary.withValues(alpha: 0.6)),
              ]
            ],
          ),
        ),
      ),
    );
  }
}