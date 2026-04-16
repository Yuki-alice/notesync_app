import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';

import '../../../../../utils/date_formatter.dart';
import '../../viewmodels/note_editor_viewmodel.dart';
import '../editor_core/quill_styles_config.dart';

import '../../../../../core/services/image_storage_service.dart';
import '../note_image_embed.dart';

class DesktopCraftReaderLayout extends StatelessWidget {
  final ThemeData theme;
  final NoteEditorViewModel viewModel;
  final ImageStorageService imageService;
  final VoidCallback onExitReadMode;

  const DesktopCraftReaderLayout({
    super.key,
    required this.theme,
    required this.viewModel,
    required this.imageService,
    required this.onExitReadMode,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    // Craft 风格的背景色（截图中的静谧蓝灰）
    // 你也可以换成 colorScheme.surfaceContainerHighest
    final craftBackgroundColor = const Color(0xFFB1C9D8);

    return Scaffold(
      backgroundColor: craftBackgroundColor,
      body: Stack(
        children: [
          // 🌟 核心：外层可滚动的画卷
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Center(
              child: Container(
                // 限制白纸的最大宽度，通常阅读最佳宽度在 800 - 900 之间
                constraints: const BoxConstraints(maxWidth: 880),
                // 制造白纸悬浮的上下边距
                margin: const EdgeInsets.symmetric(vertical: 48),
                // Craft 级别的海量留白
                padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
                decoration: BoxDecoration(
                  color: colorScheme.surface, // 白纸
                  borderRadius: BorderRadius.circular(12), // 克制的圆角
                  boxShadow: [
                    // 极淡的弥散投影，增加物理层级感
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 文档大标题
                    Text(
                      viewModel.currentNote?.title.isEmpty ?? true
                          ? '无标题文档'
                          : viewModel.currentNote!.title,
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. 元数据（时间、字数），用淡淡的灰色
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 14, color: colorScheme.outline),
                        const SizedBox(width: 6),
                        Text(
                          DateFormatter.formatFullDateTime(viewModel.currentNote?.updatedAt ?? DateTime.now()),
                          style: TextStyle(fontSize: 13, color: colorScheme.outline, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.bar_chart_rounded, size: 16, color: colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          '${viewModel.wordCount} 字',
                          style: TextStyle(fontSize: 13, color: colorScheme.outline, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),

                    // 3. 核心内容区 (只读模式的 QuillEditor)
                    quill.QuillEditor.basic(
                      controller: viewModel.quillController,
                      focusNode: FocusNode(), // 丢弃焦点
                      scrollController: ScrollController(),
                      config: quill.QuillEditorConfig(
                        scrollable: false, // 🌟 关键：禁用 Quill 自身的滚动，让外层的 SingleChildScrollView 接管，这样整张白纸才会跟着滚动！
                        expands: false,
                        padding: EdgeInsets.zero,
                        autoFocus: false,
                        showCursor: false,
                        embedBuilders: [
                          ImageEmbedBuilder(
                            imageService: imageService,
                            onSelectionChange: (_) {}, // 只读模式不需要响应选中
                          ),
                        ],
                        customStyles: QuillStylesConfig.getStyles(theme),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 🌟 悬浮操作栏（返回编辑按钮）
          Positioned(
            top: 24,
            right: 24,
            child: Material(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              elevation: 2,
              child: InkWell(
                onTap: onExitReadMode,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '返回编辑',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}