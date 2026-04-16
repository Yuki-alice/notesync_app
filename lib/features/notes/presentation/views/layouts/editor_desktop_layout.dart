import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../../../core/services/image_storage_service.dart';
import '../../../../../utils/date_formatter.dart';

import '../../viewmodels/note_editor_viewmodel.dart';
import '../../widgets/editor_core/shared_editor_components.dart';
import '../../widgets/desktop_panels/left_navigation_panel.dart';
import '../../widgets/desktop_panels/right_inspector_panel.dart';
import '../../widgets/editor_core/quill_styles_config.dart';
import '../../widgets/note_image_embed.dart';
import '../../widgets/dialogs/share_dialog.dart';

class EditorDesktopLayout extends StatefulWidget {
  final ThemeData theme;
  final NoteEditorViewModel viewModel;
  final FocusNode editorFocusNode;
  final FocusNode titleFocusNode;
  final ScrollController mainScrollController;
  final ScrollController editorInnerScrollController;
  final ImageStorageService imageService;

  const EditorDesktopLayout({
    super.key,
    required this.theme,
    required this.viewModel,
    required this.editorFocusNode,
    required this.titleFocusNode,
    required this.mainScrollController,
    required this.editorInnerScrollController,
    required this.imageService,
  });

  @override
  State<EditorDesktopLayout> createState() => _EditorDesktopLayoutState();
}

class _EditorDesktopLayoutState extends State<EditorDesktopLayout> {
  bool _isLeftPanelOpen = true;
  bool _isRightPanelOpen = true;

  // 🌟 关键：用于长图导出的截图 Key
  final GlobalKey _contentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    if (widget.viewModel.isReadOnly) {
      return DesktopCraftReaderLayout(
        theme: theme,
        viewModel: widget.viewModel,
        imageService: widget.imageService,
        onBack: () async {
          await widget.viewModel.saveNote();
          if (context.mounted) Navigator.pop(context);
        },
        onExitReadMode: () {
          widget.viewModel.toggleReadOnly();
        },
        // 🌟 阅读模式也要传 Key，方便在阅读模式下直接分享
        contentKey: _contentKey,
      );
    }

    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark
        ? theme.colorScheme.surface
        : Color.alphaBlend(theme.colorScheme.primary.withValues(alpha: 0.03), theme.colorScheme.surface);

    final deskColor = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : Color.alphaBlend(theme.colorScheme.primary.withValues(alpha: 0.12), theme.colorScheme.surface);

    final paperColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Container(
      color: baseColor,
      child: Column(
        children: [
          _buildGlobalTopbar(theme),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.fastOutSlowIn,
                  width: _isLeftPanelOpen ? 260 : 0,
                  color: Colors.transparent,
                  child: ClipRect(
                    child: OverflowBox(
                      minWidth: 0, maxWidth: 260, alignment: Alignment.topLeft,
                      child: LeftNavigationPanel(scrollController: widget.mainScrollController, editorFocusNode: widget.editorFocusNode,),
                    ),
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: deskColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15), width: 1),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SingleChildScrollView(
                          controller: widget.mainScrollController,
                          physics: const BouncingScrollPhysics(),
                          child: Center(
                            // 🌟 关键：RepaintBoundary 包裹整张白纸
                            child: RepaintBoundary(
                              key: _contentKey,
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 820, minHeight: 900),
                                margin: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                                decoration: BoxDecoration(
                                  color: paperColor,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 8))],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(64, 40, 64, 160),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      EditorTitleField(theme: theme, viewModel: widget.viewModel, focusNode: widget.titleFocusNode, editorFocusNode: widget.editorFocusNode),
                                      const SizedBox(height: 16),
                                      EditorQuillArea(theme: theme, viewModel: widget.viewModel, focusNode: widget.editorFocusNode, scrollController: widget.editorInnerScrollController, imageService: widget.imageService),
                                      // 底部点击自动聚焦逻辑...
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          if (!widget.viewModel.isReadOnly) {
                                            widget.editorFocusNode.requestFocus();
                                            final length = widget.viewModel.quillController.document.length;
                                            widget.viewModel.quillController.updateSelection(TextSelection.collapsed(offset: length > 0 ? length - 1 : 0), quill.ChangeSource.local);
                                          }
                                        },
                                        child: const SizedBox(width: double.infinity, height: 400),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.fastOutSlowIn,
                  width: _isRightPanelOpen ? 300 : 0,
                  color: Colors.transparent,
                  child: const ClipRect(
                    child: OverflowBox(
                      minWidth: 0, maxWidth: 300, alignment: Alignment.topRight,
                      child: RightInspectorPanel(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalTopbar(ThemeData theme) {
    return Container(
      height: 56,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _TopbarBtn(icon: Icons.arrow_back_rounded, tooltip: '返回', onTap: () async { await widget.viewModel.saveNote(); if (context.mounted) Navigator.pop(context); }),
          const SizedBox(width: 8),
          _TopbarBtn(icon: _isLeftPanelOpen ? Icons.menu_open_rounded : Icons.menu_rounded, tooltip: '左侧导航', onTap: () => setState(() => _isLeftPanelOpen = !_isLeftPanelOpen)),
          const Spacer(),
          if (widget.viewModel.isDirty) Text('编辑中...', style: TextStyle(color: theme.colorScheme.outline, fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          _TopbarBtn(icon: widget.viewModel.isReadOnly ? Icons.edit_note_rounded : Icons.menu_book_rounded, tooltip: widget.viewModel.isReadOnly ? '编辑模式' : '沉浸阅读', onTap: () => widget.viewModel.toggleReadOnly()),
          const SizedBox(width: 8),

          // 🌟 重构后的分享按钮
          _TopbarBtn(
              icon: Icons.ios_share_rounded,
              tooltip: '分享与导出',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => ShareDialog(
                    noteTitle: widget.viewModel.currentNote?.title ?? '无标题文档',
                    viewModel: widget.viewModel,
                  ),
                );
              }
          ),

          const SizedBox(width: 8),
          _TopbarBtn(icon: _isRightPanelOpen ? Icons.menu_open_rounded : Icons.menu_rounded, tooltip: '右侧面板', isFlipped: true, onTap: () => setState(() => _isRightPanelOpen = !_isRightPanelOpen)),
        ],
      ),
    );
  }
}

// _TopbarBtn 类保持不变...
class _TopbarBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isFlipped;
  const _TopbarBtn({required this.icon, required this.tooltip, required this.onTap, this.isFlipped = false});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget iconWidget = Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant);
    if (isFlipped) iconWidget = Transform.scale(scaleX: -1, child: iconWidget);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        child: Padding(padding: const EdgeInsets.all(8.0), child: iconWidget),
      ),
    );
  }
}

// 🌟 修改 DesktopCraftReaderLayout 以支持截图
class DesktopCraftReaderLayout extends StatefulWidget {
  final ThemeData theme;
  final NoteEditorViewModel viewModel;
  final ImageStorageService imageService;
  final VoidCallback onExitReadMode;
  final VoidCallback onBack;
  final GlobalKey contentKey; // 新增

  const DesktopCraftReaderLayout({
    super.key,
    required this.theme,
    required this.viewModel,
    required this.imageService,
    required this.onExitReadMode,
    required this.onBack,
    required this.contentKey,
  });

  @override
  State<DesktopCraftReaderLayout> createState() => _DesktopCraftReaderLayoutState();
}

class _DesktopCraftReaderLayoutState extends State<DesktopCraftReaderLayout> {
  final ScrollController _craftScrollController = ScrollController();

  @override
  void dispose() { _craftScrollController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final craftBackgroundColor = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : Color.alphaBlend(theme.colorScheme.primary.withValues(alpha: 0.18), theme.colorScheme.surface);

    return Scaffold(
      backgroundColor: craftBackgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _craftScrollController,
            physics: const BouncingScrollPhysics(),
            child: Center(
              child: RepaintBoundary( // 🌟 给阅读模式也加上边界
                key: widget.contentKey,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 860, minHeight: 900),
                  margin: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 88, vertical: 72),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 32, offset: const Offset(0, 12))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.viewModel.currentNote?.title.isEmpty ?? true ? '无标题文档' : widget.viewModel.currentNote!.title,
                        style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: colorScheme.onSurface, letterSpacing: -0.5, height: 1.2),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 14, color: colorScheme.outline),
                          const SizedBox(width: 6),
                          Text(DateFormatter.formatFullDateTime(widget.viewModel.currentNote?.updatedAt ?? DateTime.now()), style: TextStyle(fontSize: 13, color: colorScheme.outline, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 16),
                          Icon(Icons.bar_chart_rounded, size: 16, color: colorScheme.outline),
                          const SizedBox(width: 4),
                          Text('${widget.viewModel.wordCount} 字', style: TextStyle(fontSize: 13, color: colorScheme.outline, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 56),
                      quill.QuillEditor.basic(
                        controller: widget.viewModel.quillController,
                        focusNode: FocusNode(),
                        scrollController: ScrollController(),
                        config: quill.QuillEditorConfig(
                          scrollable: false, expands: false, padding: EdgeInsets.zero, autoFocus: false, showCursor: false,
                          onLaunchUrl: (url) async { /* 逻辑同前... */ },
                          embedBuilders: [ImageEmbedBuilder(imageService: widget.imageService, onSelectionChange: (_) {})],
                          customStyles: QuillStylesConfig.getStyles(theme),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 悬浮按钮逻辑同前...
          Positioned(top: 24, left: 24, child: _buildFloatingAction(icon: Icons.arrow_back_rounded, label: '返回主页', onTap: widget.onBack, theme: theme)),
          Positioned(top: 24, right: 24, child: _buildFloatingAction(icon: Icons.edit_rounded, label: '编辑文档', onTap: widget.onExitReadMode, theme: theme, isPrimary: true)),

          // 🌟 增加阅读模式下的分享快捷键入口
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => ShareDialog(
                    noteTitle: widget.viewModel.currentNote?.title ?? '无标题文档',
                    viewModel: widget.viewModel,
                  ),
                );
              },
              icon: const Icon(Icons.ios_share_rounded),
              label: const Text('分享'),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingAction({required IconData icon, required String label, required VoidCallback onTap, required ThemeData theme, bool isPrimary = false}) {
    final colorScheme = theme.colorScheme;
    return Material(
      color: isPrimary ? colorScheme.primaryContainer : colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: isPrimary ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant), const SizedBox(width: 8), Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isPrimary ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant))])),
      ),
    );
  }
}