import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../../../core/providers/notes_provider.dart';
import '../../../../../../models/tag.dart';
import '../../../viewmodels/note_editor_viewmodel.dart';
import '../../dialogs/add_tag_dialog.dart';
import '../../dialogs/set_category_sheet.dart';
import '../components/premium_pill.dart';
import '../components/toolbar_button.dart';

class MetadataPanel extends StatelessWidget {
  const MetadataPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<NoteEditorViewModel>();
    final notesProvider = context.watch<NotesProvider>();

    final realCategory = notesProvider.getCategoryById(viewModel.categoryId);
    final realTags = viewModel.tagIds.map((id) => notesProvider.getTagById(id)).whereType<Tag>().toList();

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PremiumPill(
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
            const ToolbarDivider(),
            const SizedBox(width: 4),

            ...realTags.map((tag) => Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: PremiumTagPill(
                  tag: tag,
                  theme: theme,
                  onDelete: viewModel.isReadOnly ? null : () {
                    HapticFeedback.selectionClick();
                    viewModel.removeTag(tag.id);
                  }
              ),
            )),

            if (!viewModel.isReadOnly)
              PremiumPill(
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
}