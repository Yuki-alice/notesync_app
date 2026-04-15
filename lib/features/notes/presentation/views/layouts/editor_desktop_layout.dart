import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;


import '../../../../../core/services/image_storage_service.dart';
import '../../viewmodels/note_editor_viewmodel.dart';
import '../../widgets/editor_core/shared_editor_components.dart';
import '../../widgets/desktop_panels/left_navigation_panel.dart';
import '../../widgets/desktop_panels/right_inspector_panel.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final isDark = theme.brightness == Brightness.dark;

    // 🌟 Z轴三层空间颜色：让顶栏和侧边栏彻底融为一体
    final baseColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF4F5F7);
    final deskColor = isDark ? const Color(0xFF121212) : const Color(0xFFE8EAF1);
    final paperColor = theme.colorScheme.surface;

    return Container(
      color: baseColor, // Layer 0: 全局底色
      child: Column(
        children: [
          _buildGlobalTopbar(theme), // 顶栏融入底色

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 👈 左侧导航：去除边框，融入底色
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.fastOutSlowIn,
                  width: _isLeftPanelOpen ? 260 : 0,
                  color: Colors.transparent,
                  child: const ClipRect(
                    child: OverflowBox(
                      minWidth: 0, maxWidth: 260, alignment: Alignment.topLeft,
                      child: LeftNavigationPanel(),
                    ),
                  ),
                ),

                // 📄 中间工作台
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: deskColor, // Layer 1: 桌面色
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.15), width: 1),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SingleChildScrollView(
                          controller: widget.mainScrollController,
                          physics: const BouncingScrollPhysics(),
                          child: Center(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 820, minHeight: 900),
                              margin: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                              decoration: BoxDecoration(
                                color: paperColor, // Layer 2: 纯白白纸
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8))],
                              ),
                              child: Padding(
                                // 🌟 极致优化：大幅收窄标题上方的浪费空间，提升信噪比
                                padding: const EdgeInsets.fromLTRB(64, 40, 64, 160),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    EditorTitleField(theme: theme, viewModel: widget.viewModel, focusNode: widget.titleFocusNode, editorFocusNode: widget.editorFocusNode),
                                    const SizedBox(height: 16), // 缩短标题与正文距离
                                    EditorQuillArea(theme: theme, viewModel: widget.viewModel, focusNode: widget.editorFocusNode, scrollController: widget.editorInnerScrollController, imageService: widget.imageService),
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

                // 👉 右侧面板：修正 const 报错，类名对齐
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.fastOutSlowIn,
                  width: _isRightPanelOpen ? 300 : 0,
                  color: Colors.transparent,
                  // 🌟 修复点：去掉这里的 const，因为 RightInspectorPanel 内部包含变量
                  child: ClipRect(
                    child: OverflowBox(
                      minWidth: 0, maxWidth: 300, alignment: Alignment.topRight,
                      child: RightInspectorPanel(), // 🌟 类名现在 100% 匹配
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
      color: Colors.transparent, // 融入 Layer 0 底座
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
          _TopbarBtn(icon: Icons.ios_share_rounded, tooltip: '分享', onTap: () {}),
          const SizedBox(width: 8),
          _TopbarBtn(icon: _isRightPanelOpen ? Icons.menu_open_rounded : Icons.menu_rounded, tooltip: '右侧面板', isFlipped: true, onTap: () => setState(() => _isRightPanelOpen = !_isRightPanelOpen)),
        ],
      ),
    );
  }
}

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
        hoverColor: theme.colorScheme.onSurface.withOpacity(0.05),
        child: Padding(padding: const EdgeInsets.all(8.0), child: iconWidget),
      ),
    );
  }
}