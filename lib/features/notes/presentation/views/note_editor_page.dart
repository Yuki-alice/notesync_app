// 文件路径: lib/features/notes/presentation/views/note_editor_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/notes_provider.dart';
import '../../../../core/services/image_storage_service.dart';
import '../../../../models/note.dart';
import '../viewmodels/note_editor_viewmodel.dart';
import '../widgets/dialogs/add_tag_dialog.dart';
import '../widgets/dialogs/set_category_sheet.dart';
import '../widgets/note_image_embed.dart';
import '../widgets/editor_bottom_toolbar.dart';

class NoteEditorPage extends StatelessWidget {
  final Note? note;
  const NoteEditorPage({super.key, this.note});

  @override
  Widget build(BuildContext context) {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);

    return FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Scaffold();
          final isProMode = snapshot.data!.getBool('isProMode') ?? false;

          return ChangeNotifierProvider(
            create: (_) => NoteEditorViewModel(
              note: note,
              notesProvider: notesProvider,
              isProMode: isProMode,
            ),
            child: const _NoteEditorView(),
          );
        }
    );
  }
}

class _NoteEditorView extends StatefulWidget {
  const _NoteEditorView();
  @override
  State<_NoteEditorView> createState() => _NoteEditorViewState();
}

class _NoteEditorViewState extends State<_NoteEditorView> {
  bool _isImageSelected = false;
  final FocusNode _editorFocusNode = FocusNode();
  final FocusNode _titleFocusNode = FocusNode();
  final ImageStorageService _imageService = ImageStorageService();
  ToolbarPanel _activePanel = ToolbarPanel.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final viewModel = context.read<NoteEditorViewModel>();
      if (viewModel.currentNote == null) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) _titleFocusNode.requestFocus();
        });
      }
    });
  }

  @override
  void dispose() {
    _editorFocusNode.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _togglePanel(ToolbarPanel panel) {
    setState(() {
      _activePanel = (_activePanel == panel) ? ToolbarPanel.none : panel;
      if (_activePanel != ToolbarPanel.none) _editorFocusNode.requestFocus();
    });
  }

  String _formatHeaderDate(DateTime date) {
    return DateFormat('yyyy年M月d日 HH:mm', 'zh_CN').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.brightness == Brightness.light ? Colors.white : const Color(0xFF1A1C1E);
    final viewModel = context.watch<NoteEditorViewModel>();
    final isDesktop = MediaQuery.of(context).size.width >= 1000;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await viewModel.saveNote();
        if (context.mounted) Navigator.pop(context);
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
            viewModel.saveNote();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已保存'), duration: Duration(seconds: 1)));
          },
        },
        child: Scaffold(
          backgroundColor: surfaceColor,
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            backgroundColor: surfaceColor, elevation: 0, scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
              onPressed: () async { FocusScope.of(context).unfocus(); await viewModel.saveNote(); if (context.mounted) Navigator.pop(context); },
            ),
            actions: [
              if (viewModel.isDirty)
                Padding(padding: const EdgeInsets.only(right: 8.0), child: IconButton(onPressed: () { FocusScope.of(context).unfocus(); viewModel.saveNote(); }, icon: Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary), tooltip: '保存')),
              IconButton(icon: Icon(Icons.more_vert_rounded, color: theme.colorScheme.onSurface), onPressed: () {}),
            ],
          ),
          body: SafeArea(
            bottom: false,
            child: isDesktop ? _buildDesktopLayout(theme, viewModel) : _buildMobileLayout(theme, viewModel),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(ThemeData theme, NoteEditorViewModel viewModel) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) => [ SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(48, 24, 48, 16), child: _buildTitleField(theme, viewModel))) ],
                      body: Padding(padding: const EdgeInsets.symmetric(horizontal: 48), child: _buildQuillEditor(theme, viewModel)),
                    ),
                  ),
                ),
              ),
              _buildBottomToolbar(viewModel),
            ],
          ),
        ),
        VerticalDivider(width: 1, thickness: 1, color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
        Container(
          width: 320, color: theme.colorScheme.surfaceContainerLowest,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildPanelSectionTitle(theme, '信息', Icons.info_outline_rounded), const SizedBox(height: 16),
              _buildInfoRow(theme, '创建', viewModel.currentNote != null ? _formatHeaderDate(viewModel.currentNote!.createdAt) : '现在'), const SizedBox(height: 12),
              _buildInfoRow(theme, '修改', viewModel.currentNote != null ? _formatHeaderDate(viewModel.currentNote!.updatedAt) : '现在'), const SizedBox(height: 12),
              _buildInfoRow(theme, '字数', '${viewModel.wordCount} 字'), const SizedBox(height: 32),
              _buildPanelSectionTitle(theme, '归属', Icons.folder_outlined), const SizedBox(height: 16), _buildCategorySelector(theme, viewModel), const SizedBox(height: 32),
              _buildPanelSectionTitle(theme, '标签', Icons.tag_rounded), const SizedBox(height: 16), _buildTagsWrap(theme, viewModel),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(ThemeData theme, NoteEditorViewModel viewModel) {
    return Column(
      children: [
        Expanded(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleField(theme, viewModel), const SizedBox(height: 12),
                        Text('${viewModel.currentNote != null ? _formatHeaderDate(viewModel.currentNote!.updatedAt) : _formatHeaderDate(DateTime.now())}  |  ${viewModel.wordCount}字', style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500)), const SizedBox(height: 20),
                        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [_buildCategorySelector(theme, viewModel), _buildTagsWrap(theme, viewModel, isMobile: true)]),
                      ],
                    ),
                  ),
                )
              ];
            },
            body: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: _buildQuillEditor(theme, viewModel)),
          ),
        ),
        _buildBottomToolbar(viewModel),
      ],
    );
  }

  Widget _buildTitleField(ThemeData theme, NoteEditorViewModel viewModel) {
    return TextField(
      controller: viewModel.titleController, focusNode: _titleFocusNode, textInputAction: TextInputAction.next,
      onEditingComplete: () { _editorFocusNode.requestFocus(); },
      decoration: InputDecoration(hintText: '标题', hintStyle: TextStyle(color: theme.colorScheme.outline.withOpacity(0.3), fontSize: 34, fontWeight: FontWeight.bold), filled: false, border: InputBorder.none, focusedBorder: InputBorder.none, enabledBorder: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
      style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 34, fontWeight: FontWeight.bold, height: 1.3), maxLines: null,
    );
  }

  Widget _buildQuillEditor(ThemeData theme, NoteEditorViewModel viewModel) {
    return quill.QuillEditor.basic(
      controller: viewModel.quillController, focusNode: _editorFocusNode,
      config: quill.QuillEditorConfig(
        placeholder: '记点什么...', autoFocus: false, scrollable: true, expands: true, padding: const EdgeInsets.only(bottom: 120),
        // 🌟 只要选中图片，绝对隐藏光标
        showCursor: !_isImageSelected,
        embedBuilders: [
          ImageEmbedBuilder(
            imageService: _imageService,
            onSelectionChange: (isSelected) {
              if (_isImageSelected != isSelected) {
                setState(() { _isImageSelected = isSelected; });

                // 🌟 双重物理强杀：无论是选中还是取消选中，只要发生切换，直接干掉焦点和键盘！
                _editorFocusNode.unfocus();
                SystemChannels.textInput.invokeMethod('TextInput.hide');

                if (!isSelected) {
                  // 取消选中时，额外增加一个微小延迟的强杀，防止 Quill 引擎反应过慢再次拉起键盘
                  Future.delayed(const Duration(milliseconds: 50), () {
                    _editorFocusNode.unfocus();
                  });
                }
              }
            },
          ),
        ],
        customStyles: quill.DefaultStyles(
          paragraph: quill.DefaultTextBlockStyle(TextStyle(fontSize: 17, height: 1.6, color: theme.colorScheme.onSurface.withOpacity(0.85)), const quill.HorizontalSpacing(0, 0), const quill.VerticalSpacing(0, 0), const quill.VerticalSpacing(0, 0), null),
          h1: quill.DefaultTextBlockStyle(TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.5, color: theme.colorScheme.onSurface), const quill.HorizontalSpacing(0, 0), const quill.VerticalSpacing(16, 0), const quill.VerticalSpacing(0, 0), null),
        ),
      ),
    );
  }

  Widget _buildCategorySelector(ThemeData theme, NoteEditorViewModel viewModel) {
    return InkWell(
      onTap: () async { final selected = await showSetCategorySheet(context, currentCategory: viewModel.category); if (selected != null) viewModel.setCategory(selected.isEmpty ? null : selected); },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: viewModel.category == null ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5) : theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(20), border: viewModel.category == null ? Border.all(color: theme.colorScheme.outline.withOpacity(0.1)) : null),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(viewModel.category == null ? Icons.folder_open_outlined : Icons.folder_rounded, size: 16, color: viewModel.category == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onPrimaryContainer), const SizedBox(width: 8), Text(viewModel.category ?? '未分类', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: viewModel.category == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onPrimaryContainer))]),
      ),
    );
  }

  Widget _buildTagsWrap(ThemeData theme, NoteEditorViewModel viewModel, {bool isMobile = false}) {
    return Wrap(
      spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...viewModel.tags.map((tag) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer.withOpacity(0.3), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text('#$tag', style: TextStyle(fontSize: 13, color: theme.colorScheme.secondary, fontWeight: FontWeight.w500)), const SizedBox(width: 6), InkWell(onTap: () => viewModel.removeTag(tag), child: Icon(Icons.close_rounded, size: 14, color: theme.colorScheme.secondary.withOpacity(0.7)))]))),
        InkWell(onTap: () async { final newTag = await showAddTagDialog(context); if (newTag != null) viewModel.addTag(newTag); }, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)), borderRadius: BorderRadius.circular(20), color: isMobile ? Colors.transparent : theme.colorScheme.surface), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8)), const SizedBox(width: 4), Text('添加标签', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8), fontWeight: FontWeight.w500))]))),
      ],
    );
  }

  Widget _buildBottomToolbar(NoteEditorViewModel viewModel) {
    return SafeArea(
      top: false,
      child: EditorBottomToolbar(
        controller: viewModel.quillController, activePanel: _activePanel, onPanelChanged: _togglePanel, onUndo: viewModel.undo, onRedo: viewModel.redo,
        onPickImage: () async { FocusScope.of(context).unfocus(); setState(() => _activePanel = ToolbarPanel.none); await viewModel.pickAndInsertImage(); _editorFocusNode.requestFocus(); },
        onFinish: () async { FocusScope.of(context).unfocus(); await viewModel.saveNote(); if (context.mounted) Navigator.pop(context); },
      ),
    );
  }

  Widget _buildPanelSectionTitle(ThemeData theme, String title, IconData icon) { return Row(children: [Icon(icon, size: 18, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold))]); }
  Widget _buildInfoRow(ThemeData theme, String label, String value) { return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 50, child: Text(label, style: TextStyle(color: theme.colorScheme.outline, fontSize: 13))), Expanded(child: Text(value, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)))]); }
}