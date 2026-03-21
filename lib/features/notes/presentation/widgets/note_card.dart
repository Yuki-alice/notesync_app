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

    // 文本清洗：压缩多余换行
    final cleanContent = note.plainText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final hasContent = cleanContent.isNotEmpty;

    // 🟢 架构师逻辑优化：动态空间折叠开关
    // 只有当置顶、分类、标签至少存在一个时，才分配空间
    final hasMetadata = note.isPinned || note.category != null || note.tags.isNotEmpty;

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
              color: theme.colorScheme.shadow.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.15),
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
            splashColor: theme.colorScheme.primary.withOpacity(0.05),
            highlightColor: theme.colorScheme.primary.withOpacity(0.02),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (coverImage != null)
                    Container(
                      // 🟢 架构师视觉优化：将图片高度从 110 提升到 150，大幅增强图片视觉张力！
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
                          // 🟢 动态留白：如果下面还有正文，留窄一点；如果没有正文但有标签，留宽一点
                          if (hasContent) const SizedBox(height: 6)
                          else if (hasMetadata) const SizedBox(height: 12)
                          else const SizedBox(height: 8),
                        ],

                        if (hasContent) ...[
                          SearchHighlightText(
                              cleanContent,
                              query: searchQuery,
                              // 🟢 动态行数：如果有大图，正文就少显示点（2行）；纯文字就多显示点（4行）
                              maxLines: coverImage != null ? 2 : 4,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                                height: 1.6,
                                fontSize: 13,
                              )
                          ),
                          // 🟢 动态留白：只有下方有标签时，才撑开 12 的距离，否则压缩到 8
                          if (hasMetadata) const SizedBox(height: 12) else const SizedBox(height: 8),
                        ],

                        // 🟢 架构师空间折叠：彻底消灭僵尸留白！
                        // 如果既没置顶，也没分类，也没标签，整个 Wrap 和底部的间距直接消失
                        if (hasMetadata) ...[
                          Wrap(
                            spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (note.isPinned) Icon(Icons.push_pin_rounded, size: 14, color: theme.colorScheme.primary),
                              if (note.category != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(6)
                                  ),
                                  child: Text(note.category!, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700, fontSize: 10)),
                                ),
                              ...note.tags.take(2).map((tag) {
                                final isMatch = searchQuery.isNotEmpty && tag.toLowerCase().contains(searchQuery.toLowerCase());
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: isMatch ? const Color(0xFFFFF176) : theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(4)
                                  ),
                                  child: Text('#$tag', style: theme.textTheme.labelSmall?.copyWith(color: isMatch ? Colors.black : theme.colorScheme.secondary, fontSize: 10)),
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 10), // 只有上面有标签时，才为下方的时间行撑开留白
                        ],

                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 11, color: theme.colorScheme.outline.withOpacity(0.6)),
                            const SizedBox(width: 4),
                            Text(note.formattedUpdatedAt, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline.withOpacity(0.6), fontSize: 10, letterSpacing: 0.2)),
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

class NoteCoverImage extends StatefulWidget {
  final String imagePath;
  const NoteCoverImage({super.key, required this.imagePath});

  @override
  State<NoteCoverImage> createState() => _NoteCoverImageState();
}

class _NoteCoverImageState extends State<NoteCoverImage> {
  static final Map<String, File> _fileCache = {};
  late Future<File?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = _resolveImage(widget.imagePath);
  }

  // 🟢 关键修复：当卡片在列表复用时，确保状态能够刷新
  @override
  void didUpdateWidget(covariant NoteCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _imageFuture = _resolveImage(widget.imagePath);
    }
  }

  Future<File?> _resolveImage(String path) async {
    // 1. 命中内存缓存，秒出
    if (_fileCache.containsKey(path)) {
      return _fileCache[path];
    }
    // 2. 检查是否为本地有效绝对路径
    final file = File(path);
    if (file.isAbsolute && file.existsSync()) {
      _fileCache[path] = file;
      return file;
    }
    // 3. 走存储服务去云端拉取/解析
    final resolvedFile = await ImageStorageService().getLocalFile(path);
    if (resolvedFile != null) {
      // 🟢 关键修复：无视 mounted 状态，只要拉取成功就强制塞入静态缓存
      _fileCache[path] = resolvedFile;
    }
    return resolvedFile;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        // 加载中，显示占位底色
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(color: Theme.of(context).colorScheme.surfaceContainerHighest);
        }
        // 加载成功并解析为文件
        if (snapshot.hasData && snapshot.data != null) {
          return Image.file(
            snapshot.data!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(
                child: Icon(Icons.broken_image_rounded, color: Theme.of(context).colorScheme.outline.withOpacity(0.5))
            ),
          );
        }
        // 解析失败或无图片
        return Container(color: Theme.of(context).colorScheme.surfaceContainerHighest);
      },
    );
  }
}