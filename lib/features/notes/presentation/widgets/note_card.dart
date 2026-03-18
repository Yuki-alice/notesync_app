// 文件路径: lib/features/notes/presentation/widgets/note_card.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/services/image_storage_service.dart';
import '../../../../models/note.dart';
import '../../../../widgets/common/search_highlight_text.dart';

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
    final coverImage = note.firstImagePath;
    final hasTitle = note.title.isNotEmpty;
    final hasContent = note.plainText.isNotEmpty;

    // 🌟 核心魔法 1：注入 Hero 原生空间引擎
    return Hero(
      tag: 'note_card_${note.id}',
      // 🌟 飞行阻挡器：在卡片起飞扩张的 300ms 内，用一块纯色画板遮住内部文本，
      // 完美解决由于尺寸剧烈变化导致的文本排版溢出 (RenderFlex) 报错！
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
      child: Material(
        color: theme.colorScheme.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.3), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          onSecondaryTap: onSecondaryTap,
          splashColor: theme.colorScheme.primary.withOpacity(0.1),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (coverImage != null)
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
                    child: NoteCoverImage(imagePath: coverImage),
                  ),

                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasTitle) ...[
                        SearchHighlightText(note.title, query: searchQuery, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, height: 1.2, color: theme.colorScheme.onSurface), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                      ],

                      if (hasContent) ...[
                        SearchHighlightText(note.plainText, query: searchQuery, maxLines: coverImage != null ? 3 : 6, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5)),
                        const SizedBox(height: 12),
                      ],

                      Wrap(
                        spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (note.isPinned) Icon(Icons.push_pin_rounded, size: 14, color: theme.colorScheme.primary),
                          if (note.category != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withOpacity(0.6), borderRadius: BorderRadius.circular(6)),
                              child: Text(note.category!, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 10)),
                            ),
                          ...note.tags.take(2).map((tag) {
                            final isMatch = searchQuery.isNotEmpty && tag.toLowerCase().contains(searchQuery.toLowerCase());
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: isMatch ? const Color(0xFFFFF176) : Colors.transparent, borderRadius: BorderRadius.circular(4)),
                              child: Text('#$tag', style: theme.textTheme.labelSmall?.copyWith(color: isMatch ? Colors.black : theme.colorScheme.secondary, fontStyle: FontStyle.italic)),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 12, color: theme.colorScheme.outline),
                          const SizedBox(width: 4),
                          Text(note.formattedUpdatedAt, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
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

// 🌟 解决闪烁的终极方案：单例内存级读取
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
    final file = File(widget.imagePath);
    if (file.isAbsolute) {
      _resolvedFile = file;
    } else if (_fileCache.containsKey(widget.imagePath)) {
      _resolvedFile = _fileCache[widget.imagePath]; // 直接拿缓存，不闪白！
    } else {
      _resolveImageAsync(widget.imagePath);
    }
  }

  void _resolveImageAsync(String path) async {
    final resolvedFile = await ImageStorageService().getLocalFile(path);
    if (resolvedFile != null && mounted) {
      _fileCache[path] = resolvedFile;
      setState(() => _resolvedFile = resolvedFile);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvedFile != null) {
      return Image.file(_resolvedFile!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Icon(Icons.broken_image_rounded, color: Theme.of(context).colorScheme.outline)));
    }
    return Container(color: Theme.of(context).colorScheme.surfaceContainerHighest);
  }
}