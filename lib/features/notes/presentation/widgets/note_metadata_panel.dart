import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../models/tag.dart';
import '../../../../utils/date_formatter.dart';
import '../../../../core/providers/notes_provider.dart'; // 🌟 引入
import '../viewmodels/note_editor_viewmodel.dart';
import 'dialogs/add_tag_dialog.dart';
import 'dialogs/set_category_sheet.dart';

class NoteMetadataPanel extends StatelessWidget {
  final bool isMobile;

  const NoteMetadataPanel({super.key, this.isMobile = false});

  String _formatDate(DateTime? date) {
    if (date == null) return '现在';
    return DateFormatter.formatFullDateTime(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<NoteEditorViewModel>();
    final notesProvider = context.watch<NotesProvider>(); // 🌟 获取字典

    if (isMobile) {
      return Wrap(
        spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildCategorySelector(context, theme, viewModel, notesProvider),
          _buildTagsWrap(context, theme, viewModel, notesProvider, isMobile: true),
        ],
      );
    }

    return Container(
      width: 320,
      color: theme.colorScheme.surfaceContainerLowest,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionTitle(theme, '信息', Icons.info_outline_rounded),
          const SizedBox(height: 16),
          _buildInfoRow(theme, '创建', _formatDate(viewModel.currentNote?.createdAt)),
          const SizedBox(height: 12),
          _buildInfoRow(theme, '修改', _formatDate(viewModel.currentNote?.updatedAt)),
          const SizedBox(height: 12),
          _buildInfoRow(theme, '字数', '${viewModel.wordCount} 字'),
          const SizedBox(height: 32),

          _buildSectionTitle(theme, '归属', Icons.folder_outlined),
          const SizedBox(height: 16),
          _buildCategorySelector(context, theme, viewModel, notesProvider),
          const SizedBox(height: 32),

          _buildSectionTitle(theme, '标签', Icons.tag_rounded),
          const SizedBox(height: 16),
          _buildTagsWrap(context, theme, viewModel, notesProvider),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon) {
    return Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
        ]
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 50, child: Text(label, style: TextStyle(color: theme.colorScheme.outline, fontSize: 13))),
          Expanded(child: Text(value, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500))),
        ]
    );
  }

  Widget _buildCategorySelector(BuildContext context, ThemeData theme, NoteEditorViewModel viewModel, NotesProvider notesProvider) {
    final realCategory = notesProvider.getCategoryById(viewModel.categoryId);

    return InkWell(
      onTap: viewModel.isReadOnly ? null : () async {
        // 🌟 巧妙兼容：传给弹窗的还是名字，保证你原来的弹窗代码不报错
        final selectedName = await showSetCategorySheet(context, currentCategory: realCategory?.name);

        if (selectedName != null) {
          if (selectedName.isEmpty) {
            viewModel.setCategoryId(null);
          } else {
            // 🌟 巧妙兼容：弹窗选了名字后，在这里反向查出 ID 塞给 ViewModel
            final foundCat = notesProvider.categories.firstWhere((c) => c.name == selectedName);
            viewModel.setCategoryId(foundCat.id);
          }
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: realCategory == null ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5) : theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
            border: realCategory == null ? Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)) : null
        ),
        child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(realCategory == null ? Icons.folder_open_outlined : Icons.folder_rounded, size: 16, color: realCategory == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Text(realCategory?.name ?? '未分类', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: realCategory == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onPrimaryContainer)),
            ]
        ),
      ),
    );
  }

  Widget _buildTagsWrap(BuildContext context, ThemeData theme, NoteEditorViewModel viewModel, NotesProvider notesProvider, {bool isMobile = false}) {
    // 🌟 V2 终极修复：必须加上 <Tag> 泛型！
    // 这样就能把查不到的 V1.0 旧标签 (null) 完美过滤掉，绝不让它们进入 UI 渲染层！
    final realTags = viewModel.tagIds
        .map((id) => notesProvider.getTagById(id))
        .whereType<Tag>()
        .toList();

    return Wrap(
      spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...realTags.map((tag) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('#${tag.name}', style: TextStyle(fontSize: 13, color: theme.colorScheme.secondary, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 6),
                  if (!viewModel.isReadOnly) InkWell(onTap: () => viewModel.removeTag(tag.id), child: Icon(Icons.close_rounded, size: 14, color: theme.colorScheme.secondary.withOpacity(0.7)))
                ]
            )
        )),
        if (!viewModel.isReadOnly) InkWell(
            onTap: () async {
              final newTagName = await showAddTagDialog(context);
              if (newTagName != null && newTagName.trim().isNotEmpty) {
                final newTag = await notesProvider.createTag(newTagName.trim());
                viewModel.addTag(newTag.id);
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(20),
                    color: isMobile ? Colors.transparent : theme.colorScheme.surface
                ),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8)),
                      const SizedBox(width: 4),
                      Text('添加标签', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8), fontWeight: FontWeight.w500))
                    ]
                )
            )
        ),
      ],
    );
  }
}