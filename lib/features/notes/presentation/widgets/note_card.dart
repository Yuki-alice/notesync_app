import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../core/services/image_storage_service.dart';
import '../../../../core/services/privacy_service.dart';
import '../../../../models/note.dart';
import '../../../../models/tag.dart';
import '../../../../widgets/common/search_highlight_text.dart';
import 'privacy_toggle_button.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final String searchQuery;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onSecondaryTap;

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
    final notesProvider = context.watch<NotesProvider>();
    final realCategoryName = notesProvider.getCategoryById(note.categoryId)?.name;

    final realTags = note.tagIds
        .map((id) => notesProvider.getTagById(id))
        .whereType<Tag>()
        .toList();

    final coverImage = note.firstImagePath;
    final isPrivate = note.isPrivate;
    final isLocked = isPrivate && !PrivacyService().isUnlocked;
    
    // 隐私笔记处理
    final displayTitle = isLocked ? '🔒 私密笔记' : note.title;
    final displayContent = isLocked ? '' : note.plainText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final hasTitle = displayTitle.isNotEmpty;
    final hasContent = displayContent.isNotEmpty;
    final hasMetadata = note.isPinned || note.categoryId != null || realTags.isNotEmpty || isPrivate;

    return Hero(
      tag: 'note_card_${note.id}',
      flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final radius = BorderRadius.lerp(BorderRadius.circular(24), BorderRadius.zero, animation.value);
            return Material(
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: radius ?? BorderRadius.zero),
              elevation: 0,
            );
          },
        );
      },
      child: Container(
        // 🌟 视觉升级 1：更平滑的大圆角与极其克制的弥散阴影
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            onSecondaryTap: onSecondaryTap,
            splashColor: theme.colorScheme.primary.withValues(alpha: 0.05),
            highlightColor: theme.colorScheme.primary.withValues(alpha: 0.02),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (coverImage != null)
                  Container(
                    height: 180, // 稍微增加图片高度，更有张力
                    width: double.infinity,
                    decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
                    child: NoteCoverImage(imagePath: coverImage),
                  ),

                // 🌟 视觉升级 2：放宽内部留白，增加呼吸感
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasTitle) ...[
                        SearchHighlightText(
                            displayTitle,
                            query: isLocked ? '' : searchQuery,
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                height: 1.3,
                                letterSpacing: 0.2,
                                color: isLocked 
                                    ? theme.colorScheme.error 
                                    : theme.colorScheme.onSurface
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis
                        ),
                        if (hasContent || hasMetadata) const SizedBox(height: 10),
                      ],

                      if (hasContent) ...[
                        SearchHighlightText(
                            displayContent,
                            query: searchQuery,
                            maxLines: coverImage != null ? 1 : 4,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                              height: 1.6,
                              fontSize: 13,
                            )
                        ),
                        if (hasMetadata) const SizedBox(height: 16),
                      ],

                      // 🌟 视觉升级 3：极其精致的元数据小胶囊
                      if (hasMetadata) ...[
                        Wrap(
                          spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (isPrivate)
                              PrivacyNoteIndicator(isLocked: isLocked),
                            if (note.isPinned)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: theme.colorScheme.errorContainer.withValues(alpha: 0.5), shape: BoxShape.circle),
                                child: Icon(Icons.push_pin_rounded, size: 12, color: theme.colorScheme.error),
                              ),
                            if (realCategoryName != null && !isLocked)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8)
                                ),
                                child: Text(realCategoryName, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w800, fontSize: 11)),
                              ),
                            ...realTags.take(isLocked ? 0 : 3).map((tag) {
                              final isMatch = searchQuery.isNotEmpty && tag.name.toLowerCase().contains(searchQuery.toLowerCase());
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: isMatch ? const Color(0xFFFFF176) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(6)
                                ),
                                child: Text('# ${tag.name}', style: theme.textTheme.labelSmall?.copyWith(color: isMatch ? Colors.black : theme.colorScheme.secondary, fontWeight: FontWeight.w600, fontSize: 11)),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 12, color: theme.colorScheme.outline.withValues(alpha: 0.6)),
                          const SizedBox(width: 4),
                          Text(note.formattedUpdatedAt, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// NoteCoverImage 组件保持你原本完美的直出逻辑不变...
class NoteCoverImage extends StatefulWidget {
  final String imagePath;
  const NoteCoverImage({super.key, required this.imagePath});

  @override
  State<NoteCoverImage> createState() => _NoteCoverImageState();
}

class _NoteCoverImageState extends State<NoteCoverImage> {
  static final Map<String, File> _fileCache = {};
  File? _resolvedFile;

  @override
  void initState() {
    super.initState();
    _checkAndResolve();
  }

  @override
  void didUpdateWidget(covariant NoteCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath || _resolvedFile == null) {
      _checkAndResolve();
    }
  }

  void _checkAndResolve() {
    if (_fileCache.containsKey(widget.imagePath)) {
      final file = _fileCache[widget.imagePath]!;
      if (file.existsSync()) {
        setState(() => _resolvedFile = file);
        return;
      } else {
        _fileCache.remove(widget.imagePath);
      }
    }
    final file = File(widget.imagePath);
    if (file.isAbsolute && file.existsSync()) {
      _fileCache[widget.imagePath] = file;
      setState(() => _resolvedFile = file);
      return;
    }
    _resolveImageAsync(widget.imagePath);
  }

  void _resolveImageAsync(String path) async {
    final resolvedFile = await ImageStorageService().getLocalFile(path);
    if (resolvedFile != null && resolvedFile.existsSync() && mounted) {
      _fileCache[path] = resolvedFile;
      setState(() => _resolvedFile = resolvedFile);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvedFile != null) {
      return Image.file(
          _resolvedFile!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(child: Icon(Icons.broken_image_rounded, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5)))
      );
    }
    return Container(color: Theme.of(context).colorScheme.surfaceContainerHighest);
  }
}