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

// 🌟 核心修正：类名正式改为 RightInspectorPanel，且去掉不必要的 const 限制
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

    return Column(
      children: [
        // 1:1 Craft 顶部 Tab
        Container(
          height: 60,
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTextTab('插入', 0, theme),
              _buildTextTab('样式', 1, theme),
              _buildTextTab('页面', 2, theme),
            ],
          ),
        ),

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
    );
  }

  Widget _buildTextTab(String label, int index, ThemeData theme) {
    final isActive = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isActive ? theme.colorScheme.primary : Colors.transparent, width: 2))
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: isActive ? FontWeight.bold : FontWeight.w500, color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant)),
      ),
    );
  }

  // 样式、插入、页面面板逻辑保持原样...
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
      padding: const EdgeInsets.all(20),
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
            quill.QuillToolbarColorButton(controller: controller, isBackground: false, options: quill.QuillToolbarColorButtonOptions(iconData: Icons.format_color_text_rounded, iconTheme: quill.QuillIconTheme(iconButtonUnselectedData: quill.IconButtonData(style: IconButton.styleFrom(backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5), shape: const CircleBorder()))))),
            const SizedBox(width: 12),
            quill.QuillToolbarColorButton(controller: controller, isBackground: true, options: quill.QuillToolbarColorButtonOptions(iconData: Icons.format_color_fill_rounded, iconTheme: quill.QuillIconTheme(iconButtonUnselectedData: quill.IconButtonData(style: IconButton.styleFrom(backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5), shape: const CircleBorder()))))),
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

  Widget _buildInsertTab(ThemeData theme, NoteEditorViewModel viewModel) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHeader(theme, '媒体资源'),
        _buildActionRow(theme, Icons.image_outlined, '插入相册图片', () => viewModel.pickAndInsertImage()),
        _buildActionRow(theme, Icons.link_rounded, '插入超链接', () => viewModel.quillController.formatSelection(quill.Attribute.link)),
      ],
    );
  }

  Widget _buildActionRow(ThemeData theme, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface)),
        ]),
      ),
    );
  }

  Widget _buildPageTab(ThemeData theme, NoteEditorViewModel viewModel) {
    final provider = context.watch<NotesProvider>();
    return ListView(
      padding: const EdgeInsets.all(20),
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
          backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          onTap: () async {
            final res = await showSetCategorySheet(context, currentCategory: provider.getCategoryById(viewModel.categoryId)?.name);
            if (res != null) viewModel.setCategoryId(res.isEmpty ? null : provider.categories.firstWhere((c) => c.name == res).id);
          },
        ),
        const SizedBox(height: 32),
        _buildHeader(theme, '关联标签'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ...viewModel.tagIds.map((id) => provider.getTagById(id)).whereType<Tag>().map((t) => PremiumTagPill(tag: t, theme: theme, onDelete: () => viewModel.removeTag(t.id))),
          PremiumPill(
            icon: Icons.add_rounded, label: '标签', color: theme.colorScheme.onSurfaceVariant, backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            onTap: () async {
              final name = await showAddTagDialog(context);
              if (name != null && name.trim().isNotEmpty) viewModel.addTag((await provider.createTag(name.trim())).id);
            },
          ),
        ])
      ],
    );
  }

  Widget _buildHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.outline, letterSpacing: 1.0)),
    );
  }

  Widget _buildInfoItem(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: theme.colorScheme.outline, fontSize: 13)),
        Text(value, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _buildSegmentedGroup(ThemeData theme, List<_SegmentItem> items) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: items.map((item) {
          return Expanded(
            child: GestureDetector(
              onTap: item.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: item.isActive ? theme.colorScheme.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: item.isActive ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1))] : [],
                ),
                alignment: Alignment.center,
                child: item.label != null
                    ? Text(item.label!, style: TextStyle(fontSize: 12, fontWeight: item.isActive ? FontWeight.bold : FontWeight.w500, color: item.isActive ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant))
                    : Icon(item.icon, size: 18, color: item.isActive ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant),
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