import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../../../core/services/image_storage_service.dart';
import '../../../../../utils/date_formatter.dart';
import '../../viewmodels/note_editor_viewmodel.dart';
import '../../widgets/editor_toolbar/editor_bottom_toolbar.dart';
import '../../widgets/note_image_embed.dart';
import '../../widgets/editor_core/shared_editor_components.dart';

class EditorMobileLayout extends StatefulWidget {
  final ThemeData theme;
  final NoteEditorViewModel viewModel;
  final FocusNode editorFocusNode;
  final FocusNode titleFocusNode;
  final ScrollController mainScrollController;
  final ScrollController editorInnerScrollController;
  final ImageStorageService imageService;

  const EditorMobileLayout({
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
  State<EditorMobileLayout> createState() => _EditorMobileLayoutState();
}

class _EditorMobileLayoutState extends State<EditorMobileLayout> {
  // 🌟 手机端独有状态：底部面板切换
  ToolbarPanel _activePanel = ToolbarPanel.none;

  void _togglePanel(ToolbarPanel panel) {
    setState(() {
      _activePanel = (_activePanel == panel) ? ToolbarPanel.none : panel;
      if (_activePanel == ToolbarPanel.metadata) {
        FocusScope.of(context).unfocus(); // 打开标签面板时收起键盘
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final viewModel = widget.viewModel;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: widget.mainScrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EditorTitleField(
                        theme: theme,
                        viewModel: viewModel,
                        focusNode: widget.titleFocusNode,
                        editorFocusNode: widget.editorFocusNode,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${viewModel.currentNote != null ? DateFormatter.formatFullDateTime(viewModel.currentNote!.updatedAt) : DateFormatter.formatFullDateTime(DateTime.now())}  |  ${viewModel.wordCount}字',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: EditorQuillArea(
                    theme: theme,
                    viewModel: viewModel,
                    focusNode: widget.editorFocusNode,
                    scrollController: widget.editorInnerScrollController,
                    imageService: widget.imageService,
                  ),
                ),
                // 🌟 底部唤醒区
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (!viewModel.isReadOnly) {
                      globalImageLock = false;
                      if (_activePanel != ToolbarPanel.none) setState(() => _activePanel = ToolbarPanel.none);
                      widget.editorFocusNode.requestFocus();
                      final length = viewModel.quillController.document.length;
                      viewModel.quillController.updateSelection(TextSelection.collapsed(offset: length > 0 ? length - 1 : 0), quill.ChangeSource.local);
                    }
                  },
                  child: SizedBox(width: double.infinity, height: MediaQuery.of(context).size.height * 0.6),
                ),
              ],
            ),
          ),
        ),
        // 🌟 手机端专属底部工具栏
        if (!viewModel.isReadOnly)
          SafeArea(
            top: false,
            child: EditorBottomToolbar(
              controller: viewModel.quillController,
              activePanel: _activePanel,
              onPanelChanged: _togglePanel,
              onUndo: viewModel.undo,
              onRedo: viewModel.redo,
              onPickImage: () async {
                FocusScope.of(context).unfocus();
                setState(() => _activePanel = ToolbarPanel.none);
                await viewModel.pickAndInsertImage();
                widget.editorFocusNode.requestFocus();
              },
              onFinish: () async {
                FocusScope.of(context).unfocus();
                await viewModel.saveNote();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ),
      ],
    );
  }
}