import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../core/services/image_storage_service.dart';
import '../../../../models/note.dart';
import '../../../../models/category.dart';
import '../../../../models/tag.dart';
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
    final notesProvider = context.watch<NotesProvider>();
    final realCategoryName = notesProvider.getCategoryById(note.categoryId)?.name;

    final realTags = note.tagIds
        .map((id) => notesProvider.getTagById(id))
        .whereType<Tag>()
        .toList();

    final coverImage = note.firstImagePath;
    final hasTitle = note.title.isNotEmpty;

    final cleanContent = note.plainText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final hasContent = cleanContent.isNotEmpty;
    final hasMetadata = note.isPinned || note.categoryId != null || realTags.isNotEmpty;

    return Hero(
      tag: 'note_card_${note.id}',
      flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final radius = BorderRadius.lerp(BorderRadius.circular(20), BorderRadius.zero, animation.value);
            return Material(
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: radius ?? BorderRadius.zero),
              elevation: 0,
            );
          },
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
            width: 0.5,
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
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (coverImage != null)
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
                      child: NoteCoverImage(imagePath: coverImage),
                    ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasTitle) ...[
                          SearchHighlightText(
                              note.title,
                              query: searchQuery,
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.3,
                                  letterSpacing: 0.3,
                                  color: theme.colorScheme.onSurface
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis
                          ),
                          if (hasContent) const SizedBox(height: 6)
                          else if (hasMetadata) const SizedBox(height: 12)
                          else const SizedBox(height: 8),
                        ],

                        if (hasContent) ...[
                          SearchHighlightText(
                              cleanContent,
                              query: searchQuery,
                              maxLines: coverImage != null ? 2 : 4,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                height: 1.6,
                                fontSize: 13,
                              )
                          ),
                          if (hasMetadata) const SizedBox(height: 12) else const SizedBox(height: 8),
                        ],

                        if (hasMetadata) ...[
                          Wrap(
                            spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (note.isPinned) Icon(Icons.push_pin_rounded, size: 14, color: theme.colorScheme.primary),
                              if (realCategoryName != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(6)
                                  ),
                                  child: Text(realCategoryName, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700, fontSize: 10)),
                                ),
                              ...realTags.take(3).map((tag) {
                                final isMatch = searchQuery.isNotEmpty && tag.name.toLowerCase().contains(searchQuery.toLowerCase());
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: isMatch ? const Color(0xFFFFF176) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(4)
                                  ),
                                  child: Text('#${tag.name}', style: theme.textTheme.labelSmall?.copyWith(color: isMatch ? Colors.black : theme.colorScheme.secondary, fontSize: 10)),
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],

                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 11, color: theme.colorScheme.outline.withValues(alpha: 0.6)),
                            const SizedBox(width: 4),
                            Text(note.formattedUpdatedAt, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline.withValues(alpha: 0.6), fontSize: 10, letterSpacing: 0.2)),
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
      ),
    );
  }
}

// =========================================================================
// 🌟 终极缓存引擎：同步直出（防闪烁） + 强制刷新监听（防不显示）
// =========================================================================
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

  // 🟢 关键修复：补回监听更新钩子！解决云端同步后卡片装死不加载图片的问题
  @override
  void didUpdateWidget(covariant NoteCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果图片路径换了，或者当前没有图（可能刚同步完），立刻再去磁盘捞一遍！
    if (oldWidget.imagePath != widget.imagePath || _resolvedFile == null) {
      _checkAndResolve();
    }
  }

  void _checkAndResolve() {
    // 1. 同步拦截：检查内存缓存
    if (_fileCache.containsKey(widget.imagePath)) {
      final file = _fileCache[widget.imagePath]!;
      if (file.existsSync()) {
        setState(() => _resolvedFile = file);
        return;
      } else {
        _fileCache.remove(widget.imagePath);
      }
    }

    // 2. 同步拦截：检查本地绝对路径
    final file = File(widget.imagePath);
    if (file.isAbsolute && file.existsSync()) {
      _fileCache[widget.imagePath] = file;
      setState(() => _resolvedFile = file);
      return;
    }

    // 3. 异步回退：上面都没找到，去调用服务拉取
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
    // 🟢 彻底抛弃 FutureBuilder！直接构建，1 帧都不等！
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