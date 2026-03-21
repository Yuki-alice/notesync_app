import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../utils/date_formatter.dart';
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

    // 🟢 手机端，横向排布，不显示多余的时间信息
    if (isMobile) {
      return Wrap(
        spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildCategorySelector(context, theme, viewModel),
          _buildTagsWrap(context, theme, viewModel, isMobile: true),
        ],
      );
    }

    // 🟢 桌面端，右侧优雅的信息画廊
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
          _buildCategorySelector(context, theme, viewModel),
          const SizedBox(height: 32),

          _buildSectionTitle(theme, '标签', Icons.tag_rounded),
          const SizedBox(height: 16),
          _buildTagsWrap(context, theme, viewModel),
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

  Widget _buildCategorySelector(BuildContext context, ThemeData theme, NoteEditorViewModel viewModel) {
    return InkWell(
      onTap: viewModel.isReadOnly ? null : () async {
        final selected = await showSetCategorySheet(context, currentCategory: viewModel.category);
        if (selected != null) viewModel.setCategory(selected.isEmpty ? null : selected);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: viewModel.category == null ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5) : theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
            border: viewModel.category == null ? Border.all(color: theme.colorScheme.outline.withOpacity(0.1)) : null
        ),
        child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(viewModel.category == null ? Icons.folder_open_outlined : Icons.folder_rounded, size: 16, color: viewModel.category == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Text(viewModel.category ?? '未分类', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: viewModel.category == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onPrimaryContainer)),
            ]
        ),
      ),
    );
  }

  Widget _buildTagsWrap(BuildContext context, ThemeData theme, NoteEditorViewModel viewModel, {bool isMobile = false}) {
    return Wrap(
      spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...viewModel.tags.map((tag) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('#$tag', style: TextStyle(fontSize: 13, color: theme.colorScheme.secondary, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 6),
                  if (!viewModel.isReadOnly) InkWell(onTap: () => viewModel.removeTag(tag), child: Icon(Icons.close_rounded, size: 14, color: theme.colorScheme.secondary.withOpacity(0.7)))
                ]
            )
        )),
        if (!viewModel.isReadOnly) InkWell(
            onTap: () async {
              final newTag = await showAddTagDialog(context);
              if (newTag != null) viewModel.addTag(newTag);
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