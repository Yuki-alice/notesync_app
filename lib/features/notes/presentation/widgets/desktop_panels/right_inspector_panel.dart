import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';

import '../../../../../core/providers/notes_provider.dart';
import '../../../../../models/tag.dart';
import '../../../../../utils/date_formatter.dart';
import '../../viewmodels/note_editor_viewmodel.dart';
import '../dialogs/add_tag_dialog.dart';
import '../dialogs/set_category_sheet.dart';
import '../editor_toolbar/components/premium_pill.dart';
// 🌟 引入我们刚才新建的超链接弹窗
import '../dialogs/hyperlink_dialog.dart';

class RightInspectorPanel extends StatefulWidget {
  const RightInspectorPanel({super.key});

  @override
  State<RightInspectorPanel> createState() => _RightInspectorPanelState();
}

class _RightInspectorPanelState extends State<RightInspectorPanel> {
  int _currentTab = 1; // 0: 插入, 1: 样式, 2: 页面

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<NoteEditorViewModel>();
    final colorScheme = theme.colorScheme;

    return Container(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildTab('插入', Icons.add_circle_outline_rounded, 0, colorScheme)),
                Expanded(child: _buildTab('样式', Icons.text_format_rounded, 1, colorScheme)),
                Expanded(child: _buildTab('页面', Icons.info_outline_rounded, 2, colorScheme)),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.2)),

          Expanded(
            child: AnimatedBuilder(
              animation: viewModel.quillController,
              builder: (context, _) {
                if (_currentTab == 0) return _buildInsertTab(theme, viewModel);
                if (_currentTab == 1) return _buildStyleTab(theme, viewModel);
                return _buildPageTab(theme, viewModel);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, IconData icon, int index, ColorScheme colorScheme) {
    final isActive = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isActive ? colorScheme.primary : Colors.transparent, width: 2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: isActive ? FontWeight.w600 : FontWeight.w500, color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleTab(ThemeData theme, NoteEditorViewModel viewModel) {
    final controller = viewModel.quillController;
    final style = controller.getSelectionStyle();

    bool isH1 = style.attributes['header']?.value == 1;
    bool isH2 = style.attributes['header']?.value == 2;
    bool isH3 = style.attributes['header']?.value == 3;
    bool isNormal = !isH1 && !isH2 && !isH3;

    bool isBold = style.attributes['bold']?.value == true;
    bool isItalic = style.attributes['italic']?.value == true;
    bool isUnder = style.attributes['underline']?.value == true;
    bool isStrike = style.attributes['strike']?.value == true;

    bool isUL = style.attributes['list']?.value == 'bullet';
    bool isOL = style.attributes['list']?.value == 'ordered';
    bool isTodo = style.attributes['list']?.value == 'checked' || style.attributes['list']?.value == 'unchecked';
    bool isCode = style.attributes['code-block']?.value == true;
    bool isQuote = style.attributes['blockquote']?.value == true;

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildHeader(theme, '标题与正文'),
        _buildSegmentedGroup(theme, [
          _SegmentItem(label: '大标题', isActive: isH1, onTap: () => _format(controller, quill.Attribute.h1)),
          _SegmentItem(label: '中标题', isActive: isH2, onTap: () => _format(controller, quill.Attribute.h2)),
          _SegmentItem(label: '正文', isActive: isNormal, onTap: () => _format(controller, quill.Attribute.header)),
        ]),
        const SizedBox(height: 8),
        _buildSegmentedGroup(theme, [
          _SegmentItem(label: '小标题', isActive: isH3, onTap: () => _format(controller, quill.Attribute.h3)),
          _SegmentItem(label: '引用', isActive: isQuote, onTap: () => _format(controller, quill.Attribute.blockQuote)),
          _SegmentItem(label: '代码块', isActive: isCode, onTap: () => _format(controller, quill.Attribute.codeBlock)),
        ]),

        const SizedBox(height: 28),
        _buildHeader(theme, '基础排版'),
        _buildSegmentedGroup(theme, [
          _SegmentItem(icon: Icons.format_bold_rounded, isActive: isBold, onTap: () => _format(controller, quill.Attribute.bold)),
          _SegmentItem(icon: Icons.format_italic_rounded, isActive: isItalic, onTap: () => _format(controller, quill.Attribute.italic)),
          _SegmentItem(icon: Icons.format_underlined_rounded, isActive: isUnder, onTap: () => _format(controller, quill.Attribute.underline)),
          _SegmentItem(icon: Icons.format_strikethrough_rounded, isActive: isStrike, onTap: () => _format(controller, quill.Attribute.strikeThrough)),
        ]),
        const SizedBox(height: 8),
        _buildSegmentedGroup(theme, [
          _SegmentItem(icon: Icons.check_box_outlined, isActive: isTodo, onTap: () => _format(controller, quill.Attribute.unchecked)),
          _SegmentItem(icon: Icons.format_list_bulleted_rounded, isActive: isUL, onTap: () => _format(controller, quill.Attribute.ul)),
          _SegmentItem(icon: Icons.format_list_numbered_rounded, isActive: isOL, onTap: () => _format(controller, quill.Attribute.ol)),
          _SegmentItem(icon: Icons.format_clear_rounded, isActive: false, onTap: () => controller.formatSelection(quill.Attribute.clone(quill.Attribute.bold, null))),
        ]),

        const SizedBox(height: 28),
        _buildHeader(theme, '颜色与高亮'),
        Row(
          children: [
            quill.QuillToolbarColorButton(controller: controller, isBackground: false, options: quill.QuillToolbarColorButtonOptions(iconData: Icons.format_color_text_rounded, iconTheme: quill.QuillIconTheme(iconButtonUnselectedData: quill.IconButtonData(style: IconButton.styleFrom(backgroundColor: theme.colorScheme.onSurface.withOpacity(0.04), shape: const CircleBorder()))))),
            const SizedBox(width: 12),
            quill.QuillToolbarColorButton(controller: controller, isBackground: true, options: quill.QuillToolbarColorButtonOptions(iconData: Icons.format_color_fill_rounded, iconTheme: quill.QuillIconTheme(iconButtonUnselectedData: quill.IconButtonData(style: IconButton.styleFrom(backgroundColor: theme.colorScheme.onSurface.withOpacity(0.04), shape: const CircleBorder()))))),
          ],
        ),
      ],
    );
  }

  void _format(quill.QuillController controller, quill.Attribute attr) {
    final style = controller.getSelectionStyle();
    if (style.attributes.containsKey(attr.key) && style.attributes[attr.key]?.value == attr.value) {
      controller.formatSelection(quill.Attribute.clone(attr, null));
    } else {
      controller.formatSelection(attr);
    }
  }

  // 🌟 修复报错的核心区
  Widget _buildInsertTab(ThemeData theme, NoteEditorViewModel viewModel) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildHeader(theme, '媒体资源'),
        _buildActionRow(theme, Icons.image_outlined, '插入相册图片', () => viewModel.pickAndInsertImage()),

        _buildActionRow(theme, Icons.link_rounded, '插入超链接', () async {
          final controller = viewModel.quillController;
          final selection = controller.selection;

          // 1. 使用 start 和 end 而非 index / length
          final int start = selection.start;
          final int end = selection.end;
          final int length = end - start;

          String text = '';
          if (length > 0) {
            text = controller.document.getPlainText(start, length).trim();
          }

          final result = await showDialog<Map<String, String>>(
            context: context,
            builder: (context) => HyperlinkDialog(initialText: text),
          );

          if (result != null && result['url']!.isNotEmpty) {
            final linkText = result['text']!.isEmpty ? result['url']! : result['text']!;
            final linkUrl = result['url']!;

            // 2. 替换文字
            if (length > 0) {
              controller.replaceText(start, length, linkText, TextSelection.collapsed(offset: start + linkText.length));
            } else {
              controller.document.insert(start, linkText);
              controller.updateSelection(TextSelection.collapsed(offset: start + linkText.length), quill.ChangeSource.local);
            }

            // 3. 修复 Attribute.link 报错，使用 quill.LinkAttribute() 实例
            controller.formatText(start, linkText.length, quill.LinkAttribute(linkUrl));
          }
        }),
      ],
    );
  }

  Widget _buildActionRow(ThemeData theme, IconData icon, String label, VoidCallback onTap) {
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: colorScheme.onSurface.withOpacity(0.04),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageTab(ThemeData theme, NoteEditorViewModel viewModel) {
    final provider = context.watch<NotesProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildHeader(theme, '统计信息'),
        _buildInfoItem(theme, '创建', _formatDate(viewModel.currentNote?.createdAt)),
        _buildInfoItem(theme, '修改', _formatDate(viewModel.currentNote?.updatedAt)),
        _buildInfoItem(theme, '字数', '${viewModel.wordCount} 字'),

        const SizedBox(height: 32),
        _buildHeader(theme, '收纳位置'),
        PremiumPill(
          icon: Icons.folder_outlined,
          label: provider.getCategoryById(viewModel.categoryId)?.name ?? '未分类',
          color: theme.colorScheme.onSurfaceVariant,
          backgroundColor: theme.colorScheme.onSurface.withOpacity(0.04),
          onTap: () async {
            final res = await showSetCategorySheet(context, currentCategory: provider.getCategoryById(viewModel.categoryId)?.name);
            if (res != null) viewModel.setCategoryId(res.isEmpty ? null : provider.categories.firstWhere((c) => c.name == res).id);
          },
        ),

        const SizedBox(height: 32),
        _buildHeader(theme, '关联标签'),
        Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              ...viewModel.tagIds.map((id) => provider.getTagById(id)).whereType<Tag>().map((t) => PremiumTagPill(tag: t, theme: theme, onDelete: () => viewModel.removeTag(t.id))),
              PremiumPill(icon: Icons.add_rounded, label: '标签', color: theme.colorScheme.onSurfaceVariant, backgroundColor: theme.colorScheme.onSurface.withOpacity(0.04), onTap: () async { final name = await showAddTagDialog(context); if (name != null && name.trim().isNotEmpty) viewModel.addTag((await provider.createTag(name.trim())).id); }),
            ]
        )
      ],
    );
  }

  Widget _buildHeader(ThemeData theme, String title) {
    return Padding(padding: const EdgeInsets.only(left: 4, bottom: 12), child: Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: theme.colorScheme.outline, letterSpacing: 1.2)));
  }

  Widget _buildInfoItem(ThemeData theme, String label, String value) {
    return Padding(padding: const EdgeInsets.only(left: 4, right: 4, bottom: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: theme.colorScheme.outline, fontSize: 13)), Text(value, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500))]));
  }

  Widget _buildSegmentedGroup(ThemeData theme, List<_SegmentItem> items) {
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: colorScheme.onSurface.withOpacity(0.04), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: items.map((item) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(color: item.isActive ? colorScheme.surface : Colors.transparent, borderRadius: BorderRadius.circular(6), boxShadow: item.isActive ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1))] : []),
                    alignment: Alignment.center,
                    child: item.label != null
                        ? Text(item.label!, style: TextStyle(fontSize: 12, fontWeight: item.isActive ? FontWeight.w600 : FontWeight.w500, color: item.isActive ? colorScheme.primary : colorScheme.onSurfaceVariant))
                        : Icon(item.icon, size: 18, color: item.isActive ? colorScheme.primary : colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatDate(DateTime? date) => date == null ? '-' : DateFormatter.formatFullDateTime(date);
}

class _SegmentItem {
  final String? label;
  final IconData? icon;
  final bool isActive;
  final VoidCallback onTap;
  _SegmentItem({this.label, this.icon, required this.isActive, required this.onTap});
}