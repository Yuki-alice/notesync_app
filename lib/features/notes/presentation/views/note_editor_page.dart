// 文件路径: lib/features/notes/presentation/views/note_editor_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/providers/notes_provider.dart';
import '../../../../core/services/image_storage_service.dart';
import '../../../../models/note.dart';
import '../../../../utils/date_formatter.dart';
import '../../../../utils/toast_utils.dart';
import '../viewmodels/note_editor_viewmodel.dart';
import '../widgets/dialogs/add_tag_dialog.dart';
import '../widgets/dialogs/set_category_sheet.dart';
import '../widgets/editor_bottom_toolbar.dart';
import 'note_export_preview_page.dart';

// 🌟 引入刚放好锁的图片组件
import '../widgets/note_image_embed.dart';

// =================================================================
// 🌟 核心防闪烁黑科技：读取已转交的全局锁
// =================================================================
class EditorFocusNode extends FocusNode {
  @override
  void requestFocus([FocusNode? node]) {
    // 读取引入文件中的 globalImageLock
    if (globalImageLock) return;
    super.requestFocus(node);
  }
}

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
  late final EditorFocusNode _editorFocusNode;
  final FocusNode _titleFocusNode = FocusNode();

  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _editorInnerScrollController = ScrollController();

  final ImageStorageService _imageService = ImageStorageService();
  ToolbarPanel _activePanel = ToolbarPanel.none;
  final GlobalKey _boundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _editorFocusNode = EditorFocusNode();
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
    _mainScrollController.dispose();
    _editorInnerScrollController.dispose();
    super.dispose();
  }

  void _togglePanel(ToolbarPanel panel) {
    setState(() {
      _activePanel = (_activePanel == panel) ? ToolbarPanel.none : panel;
      if (_activePanel != ToolbarPanel.none) _editorFocusNode.requestFocus();
    });
  }

  String _formatHeaderDate(DateTime date) {
    return DateFormatter.formatFullDateTime(date);
  }

  Future<void> _handleExport(String type, NoteEditorViewModel viewModel) async {
    FocusScope.of(context).unfocus();
    final title = viewModel.titleController.text.trim().isEmpty ? '未命名笔记' : viewModel.titleController.text.trim();

    if (type == 'image_preview') {
      final deltaJson = jsonEncode(viewModel.quillController.document.toDelta().toJson());
      Navigator.push(context, MaterialPageRoute(builder: (_) => NoteExportPreviewPage(title: title, deltaJson: deltaJson)));
    } else if (type == 'markdown') {
      try {
        final mdContent = viewModel.generateMarkdownContent();
        Directory? dir;
        if (Platform.isAndroid) {
          dir = Directory('/storage/emulated/0/Download/NoteSync');
          try { if (!await dir.exists()) await dir.create(recursive: true); } catch (_) { dir = await getExternalStorageDirectory(); }
        } else if (Platform.isIOS) {
          dir = await getApplicationDocumentsDirectory();
        } else {
          dir = await getDownloadsDirectory();
          dir = Directory('${dir?.path}/NoteSync');
          if (!await dir.exists()) await dir.create(recursive: true);
        }
        final fileName = '${title.isEmpty ? "未命名灵感" : title}_${DateTime.now().millisecondsSinceEpoch}.md';
        final file = File('${dir!.path}/$fileName');
        await file.writeAsString(mdContent);
        if (mounted) ToastUtils.showSuccess(context, 'Markdown 已保存至本地✨');
        await Share.shareXFiles([XFile(file.path)], text: '分享笔记: ${title.isEmpty ? "未命名" : title}');
      } catch (e) {
        if (mounted) ToastUtils.showError(context, '导出失败，请检查存储权限');
      }
    }
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
            backgroundColor: surfaceColor.withOpacity(0.95), elevation: 0, scrolledUnderElevation: 0, centerTitle: true,
            title: viewModel.isReadOnly ? Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.menu_book_rounded, size: 16, color: theme.colorScheme.primary), const SizedBox(width: 8), Text('沉浸阅读', style: TextStyle(color: theme.colorScheme.primary, fontSize: 15, fontWeight: FontWeight.bold))]) : null,
            leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface), onPressed: () async { FocusScope.of(context).unfocus(); await viewModel.saveNote(); if (context.mounted) Navigator.pop(context); }),
            actions: [
              if (viewModel.isDirty) Padding(padding: const EdgeInsets.only(right: 8.0), child: IconButton(onPressed: () { FocusScope.of(context).unfocus(); viewModel.saveNote(); }, icon: Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary), tooltip: '保存')),
              IconButton(tooltip: viewModel.isReadOnly ? '切换到编辑' : '切换到阅读', icon: Icon(viewModel.isReadOnly ? Icons.edit_note_rounded : Icons.menu_book_rounded, color: viewModel.isReadOnly ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant), onPressed: () { FocusScope.of(context).unfocus(); viewModel.toggleReadOnly(); }),
              PopupMenuButton<String>(
                icon: Icon(Icons.ios_share_rounded, color: theme.colorScheme.onSurfaceVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), position: PopupMenuPosition.under, color: theme.colorScheme.surfaceContainerHighest,
                onSelected: (value) => _handleExport(value, viewModel),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'image_preview', child: Row(children: [Icon(Icons.image_rounded, size: 20, color: theme.colorScheme.primary), const SizedBox(width: 12), const Text('生成长图分享 / 保存')])),
                  const PopupMenuDivider(),
                  PopupMenuItem(value: 'markdown', child: Row(children: [Icon(Icons.code_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant), const SizedBox(width: 12), const Text('导出 / 分享 Markdown')])),
                ],
              ),
              const SizedBox(width: 8),
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
                    child: _buildScrollableContent(theme, viewModel, 48.0, 24.0),
                  ),
                ),
              ),
              if (!viewModel.isReadOnly) _buildBottomToolbar(viewModel),
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
          child: _buildScrollableContent(theme, viewModel, 24.0, 12.0),
        ),
        if (!viewModel.isReadOnly) _buildBottomToolbar(viewModel),
      ],
    );
  }

  Widget _buildScrollableContent(ThemeData theme, NoteEditorViewModel viewModel, double horizontalPadding, double topPadding) {
    return SingleChildScrollView(
      controller: _mainScrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      physics: const AlwaysScrollableScrollPhysics(),
      child: RepaintBoundary(
        key: _boundaryKey,
        child: Container(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, topPadding, horizontalPadding, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitleField(theme, viewModel), const SizedBox(height: 12),
                    Text('${viewModel.currentNote != null ? _formatHeaderDate(viewModel.currentNote!.updatedAt) : _formatHeaderDate(DateTime.now())}  |  ${viewModel.wordCount}字', style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w500)), const SizedBox(height: 20),
                    Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [_buildCategorySelector(theme, viewModel), _buildTagsWrap(theme, viewModel, isMobile: horizontalPadding == 24.0)]),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: _buildQuillEditor(theme, viewModel),
              ),
              // 🌟 这就是让你能在打字时随意上下滑动的 60% 高度空气魔法留白！
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!viewModel.isReadOnly) {
                    globalImageLock = false;
                    _editorFocusNode.requestFocus();
                    final length = viewModel.quillController.document.length;
                    viewModel.quillController.updateSelection(
                      TextSelection.collapsed(offset: length > 0 ? length - 1 : 0),
                      quill.ChangeSource.local,
                    );
                  }
                },
                child: SizedBox(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleField(ThemeData theme, NoteEditorViewModel viewModel) {
    return TextField(
      controller: viewModel.titleController, focusNode: _titleFocusNode, textInputAction: TextInputAction.next, readOnly: viewModel.isReadOnly,
      onEditingComplete: () { _editorFocusNode.requestFocus(); },
      decoration: InputDecoration(hintText: '标题', hintStyle: TextStyle(color: theme.colorScheme.outline.withOpacity(0.3), fontSize: 34, fontWeight: FontWeight.bold), filled: false, border: InputBorder.none, focusedBorder: InputBorder.none, enabledBorder: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
      style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 34, fontWeight: FontWeight.bold, height: 1.3), maxLines: null,
    );
  }

  Widget _buildQuillEditor(ThemeData theme, NoteEditorViewModel viewModel) {
    return quill.QuillEditor.basic(
      controller: viewModel.quillController, focusNode: _editorFocusNode,
      scrollController: _editorInnerScrollController,
      config: quill.QuillEditorConfig(
        scrollable: false, expands: false,
        padding: EdgeInsets.zero,
        placeholder: '记点什么...', autoFocus: false,
        showCursor: !viewModel.isReadOnly && !_isImageSelected,

        embedBuilders: [
          ImageEmbedBuilder(
            imageService: _imageService,
            onSelectionChange: (isSelected) {
              if (_isImageSelected != isSelected) {
                setState(() => _isImageSelected = isSelected);
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

  Widget _buildCategorySelector(ThemeData theme, NoteEditorViewModel viewModel) { return InkWell(onTap: viewModel.isReadOnly ? null : () async { final selected = await showSetCategorySheet(context, currentCategory: viewModel.category); if (selected != null) viewModel.setCategory(selected.isEmpty ? null : selected); }, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: viewModel.category == null ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5) : theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(20), border: viewModel.category == null ? Border.all(color: theme.colorScheme.outline.withOpacity(0.1)) : null), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(viewModel.category == null ? Icons.folder_open_outlined : Icons.folder_rounded, size: 16, color: viewModel.category == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onPrimaryContainer), const SizedBox(width: 8), Text(viewModel.category ?? '未分类', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: viewModel.category == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onPrimaryContainer))]))); }
  Widget _buildTagsWrap(ThemeData theme, NoteEditorViewModel viewModel, {bool isMobile = false}) { return Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [...viewModel.tags.map((tag) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer.withOpacity(0.3), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text('#$tag', style: TextStyle(fontSize: 13, color: theme.colorScheme.secondary, fontWeight: FontWeight.w500)), const SizedBox(width: 6), if (!viewModel.isReadOnly) InkWell(onTap: () => viewModel.removeTag(tag), child: Icon(Icons.close_rounded, size: 14, color: theme.colorScheme.secondary.withOpacity(0.7)))]))), if (!viewModel.isReadOnly) InkWell(onTap: () async { final newTag = await showAddTagDialog(context); if (newTag != null) viewModel.addTag(newTag); }, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)), borderRadius: BorderRadius.circular(20), color: isMobile ? Colors.transparent : theme.colorScheme.surface), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8)), const SizedBox(width: 4), Text('添加标签', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8), fontWeight: FontWeight.w500))]))),]); }
  Widget _buildBottomToolbar(NoteEditorViewModel viewModel) { return SafeArea(top: false, child: EditorBottomToolbar(controller: viewModel.quillController, activePanel: _activePanel, onPanelChanged: _togglePanel, onUndo: viewModel.undo, onRedo: viewModel.redo, onPickImage: () async { FocusScope.of(context).unfocus(); setState(() => _activePanel = ToolbarPanel.none); await viewModel.pickAndInsertImage(); _editorFocusNode.requestFocus(); }, onFinish: () async { FocusScope.of(context).unfocus(); await viewModel.saveNote(); if (context.mounted) Navigator.pop(context); })); }
  Widget _buildPanelSectionTitle(ThemeData theme, String title, IconData icon) { return Row(children: [Icon(icon, size: 18, color: theme.colorScheme.primary), const SizedBox(width: 8), Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold))]); }
  Widget _buildInfoRow(ThemeData theme, String label, String value) { return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 50, child: Text(label, style: TextStyle(color: theme.colorScheme.outline, fontSize: 13))), Expanded(child: Text(value, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)))]); }
}