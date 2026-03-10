import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/services/image_storage_service.dart';
import '../../../../models/note.dart';
import '../../../../widgets/common/search_highlight_text.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final String searchQuery;
  final VoidCallback onTap;
  final VoidCallback onLongPress;    // 手机端长按
  final VoidCallback? onSecondaryTap; // 电脑端右键

  const NoteCard({
    super.key,
    required this.note,
    this.searchQuery = '',
    required this.onTap,
    required this.onLongPress,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverImage = note.firstImagePath;
    final hasTitle = note.title.isNotEmpty;
    final hasContent = note.plainText.isNotEmpty;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onSecondaryTap,
      splashColor: theme.colorScheme.primary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(24),
      // 🟢 技巧：使用 NeverScrollableScrollPhysics 的 SingleChildScrollView
      // 这能彻底解决由于动画形变或软键盘收放导致的瞬间高度受限引起的 RenderFlex 溢出报错
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (coverImage != null)
            // 🟢 修复：移除了 Hero 标签。因为外层已经使用了 OpenContainer 动画，
            // 嵌套 Hero 会导致动画约束冲突，这是触发溢出报错的元凶之一。
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: NoteCoverImage(imagePath: coverImage),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasTitle) ...[
                    SearchHighlightText(
                      note.title,
                      query: searchQuery,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],

                  if (hasContent) ...[
                    SearchHighlightText(
                      note.plainText,
                      query: searchQuery,
                      maxLines: coverImage != null ? 3 : 6,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 标签和分类区域
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // 置顶标识
                      if (note.isPinned)
                        Icon(Icons.push_pin_rounded, size: 14, color: theme.colorScheme.primary),

                      if (note.category != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            note.category!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ...note.tags.take(2).map((tag) {
                        final isMatch = searchQuery.isNotEmpty &&
                            tag.toLowerCase().contains(searchQuery.toLowerCase());
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isMatch ? const Color(0xFFFFF176) : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#$tag',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isMatch ? Colors.black : theme.colorScheme.secondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 12, color: theme.colorScheme.outline),
                      const SizedBox(width: 4),
                      Text(
                        note.formattedUpdatedAt,
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NoteCoverImage extends StatelessWidget {
  final String imagePath;
  const NoteCoverImage({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = File(imagePath);

    if (file.isAbsolute) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(
          child: Icon(Icons.broken_image_rounded, color: theme.colorScheme.outline),
        ),
      );
    }

    return FutureBuilder<File?>(
      future: ImageStorageService().getLocalFile(imagePath),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.file(
            snapshot.data!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(
              child: Icon(Icons.broken_image_rounded, color: theme.colorScheme.outline),
            ),
          );
        }
        return Container(color: theme.colorScheme.surfaceContainerHighest);
      },
    );
  }
}