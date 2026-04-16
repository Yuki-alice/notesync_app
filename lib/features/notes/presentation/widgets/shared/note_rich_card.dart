import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../../../core/services/image_storage_service.dart';
import '../note_image_embed.dart';

class SharedNoteRichCard extends StatelessWidget {
  final String title;
  final quill.QuillController controller;
  final ThemeData theme;
  final double width;

  const SharedNoteRichCard({
    super.key,
    required this.title,
    required this.controller,
    required this.theme,
    this.width = 760, // 黄金排版宽度
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;

    // 🌟 高级渐变背景逻辑
    final bgColor1 = isDark ? const Color(0xFF1A1D21) : Color.alphaBlend(colorScheme.primary.withValues(alpha: 0.15), colorScheme.surface);
    final bgColor2 = isDark ? const Color(0xFF121212) : colorScheme.surfaceContainerLowest;
    final paperColor = isDark ? const Color(0xFF242424) : Colors.white;

    return Container(
      width: width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bgColor1, bgColor2],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 📄 实体纸张卡片
          Container(
            decoration: BoxDecoration(
              color: paperColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 72),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? '未命名笔记' : title,
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                    height: 1.3,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 16, color: colorScheme.outline),
                    const SizedBox(width: 8),
                    Text(
                      'Generated on NoteSync',
                      style: TextStyle(color: colorScheme.outline, fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                // 只读编辑器渲染内容
                quill.QuillEditor.basic(
                  controller: controller,
                  focusNode: FocusNode(),
                  scrollController: ScrollController(),
                  config: quill.QuillEditorConfig(
                    scrollable: false,
                    expands: false,
                    autoFocus: false,
                    showCursor: false,
                    embedBuilders: [
                      ImageEmbedBuilder(
                        imageService: ImageStorageService(),
                        onSelectionChange: (_) {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          // 🏷️ 底部品牌水印
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Powered by NoteSync',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}