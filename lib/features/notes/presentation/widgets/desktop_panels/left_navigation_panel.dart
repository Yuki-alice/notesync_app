import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';


import '../../../../../core/providers/notes_provider.dart';
import '../../viewmodels/note_editor_viewmodel.dart';

class LeftNavigationPanel extends StatefulWidget {
  const LeftNavigationPanel({super.key});

  @override
  State<LeftNavigationPanel> createState() => _LeftNavigationPanelState();
}

class _LeftNavigationPanelState extends State<LeftNavigationPanel> {
  int _leftTab = 0; // 0: 大纲, 1: 分类, 2: 媒体

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<NoteEditorViewModel>();

    return Column(
      children: [
        // 顶层搜索框
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8)
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Text('在文档内搜索...', style: TextStyle(color: theme.colorScheme.outline, fontSize: 13)),
              ],
            ),
          ),
        ),

        // 三个独立 Tab
        Row(
          children: [
            _buildLeftTab('大纲', 0, theme),
            _buildLeftTab('分类', 1, theme),
            _buildLeftTab('媒体', 2, theme),
          ],
        ),
        Divider(height: 1, color: theme.colorScheme.outlineVariant.withOpacity(0.15)),

        // 动态内容区
        Expanded(
          child: _leftTab == 0 ? _buildOutlineTOC(theme, viewModel)
              : _leftTab == 1 ? _buildCategoryTree(theme, viewModel)
              : _buildMediaPlaceholder(theme),
        ),
      ],
    );
  }

  Widget _buildLeftTab(String label, int index, ThemeData theme) {
    final isActive = _leftTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _leftTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isActive ? theme.colorScheme.primary : Colors.transparent, width: 2))
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: isActive ? FontWeight.bold : FontWeight.w500, color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant)),
        ),
      ),
    );
  }

  Widget _buildOutlineTOC(ThemeData theme, NoteEditorViewModel viewModel) {
    final toc = <Map<String, dynamic>>[];
    for (final node in viewModel.quillController.document.root.children) {
      if (node is quill.Line && node.style.attributes['header'] != null) {
        final text = node.toPlainText().trim();
        if (text.isNotEmpty) toc.add({'level': node.style.attributes['header']!.value, 'text': text, 'offset': node.documentOffset});
      }
    }

    if (toc.isEmpty) return Center(child: Text('无标题层级', style: TextStyle(color: theme.colorScheme.outline, fontSize: 12)));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: toc.length,
      itemBuilder: (context, index) {
        final item = toc[index];
        final level = item['level'] as int;
        return InkWell(
          onTap: () => viewModel.quillController.updateSelection(TextSelection.collapsed(offset: item['offset']), quill.ChangeSource.local),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: EdgeInsets.only(left: (level - 1) * 16.0, top: 6, bottom: 6, right: 8),
            child: Text(item['text'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: level == 1 ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant, fontWeight: level == 1 ? FontWeight.bold : FontWeight.normal)),
          ),
        );
      },
    );
  }

  Widget _buildCategoryTree(ThemeData theme, NoteEditorViewModel viewModel) {
    final provider = context.watch<NotesProvider>();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: provider.categories.length,
      itemBuilder: (context, index) {
        final cat = provider.categories[index];
        final isCurrent = viewModel.categoryId == cat.id;
        return InkWell(
          onTap: () => viewModel.setCategoryId(cat.id),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: isCurrent ? theme.colorScheme.primaryContainer.withOpacity(0.4) : Colors.transparent, borderRadius: BorderRadius.circular(6)),
            child: Row(children: [
              Icon(Icons.folder_outlined, size: 16, color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.outline),
              const SizedBox(width: 8),
              Text(cat.name, style: TextStyle(fontSize: 13, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurface)),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildMediaPlaceholder(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.perm_media_outlined, size: 48, color: theme.colorScheme.outline.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('附件与媒体将显示在这里', style: TextStyle(color: theme.colorScheme.outline, fontSize: 12)),
        ],
      ),
    );
  }
}