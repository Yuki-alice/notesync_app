import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/services/image_storage_service.dart';
import '../../../../models/note.dart';
import '../../../../utils/date_formatter.dart';
import '../../../../utils/toast_utils.dart';
import '../viewmodels/note_editor_viewmodel.dart';
import '../widgets/editor_bottom_toolbar.dart';
import 'note_export_preview_page.dart';

import '../widgets/note_image_embed.dart';
import '../widgets/note_metadata_panel.dart';

class EditorFocusNode extends FocusNode {
  @override
  void requestFocus([FocusNode? node]) {
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
    final isProMode = context.watch<ThemeProvider>().isProMode;

    return ChangeNotifierProvider(
      create:
          (_) => NoteEditorViewModel(
            note: note,
            notesProvider: notesProvider,
            isProMode: isProMode,
          ),
      child: const _NoteEditorView(),
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

  Future<void> _handleExport(String type, NoteEditorViewModel viewModel) async {
    FocusScope.of(context).unfocus();
    final title =
        viewModel.titleController.text.trim().isEmpty
            ? '未命名笔记'
            : viewModel.titleController.text.trim();

    if (type == 'image_preview') {
      final deltaJson = jsonEncode(
        viewModel.quillController.document.toDelta().toJson(),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => NoteExportPreviewPage(title: title, deltaJson: deltaJson),
        ),
      );
    } else if (type == 'markdown') {
      try {
        final mdContent = viewModel.generateMarkdownContent();
        Directory? dir;
        if (Platform.isAndroid) {
          dir = Directory('/storage/emulated/0/Download/NoteSync');
          try {
            if (!await dir.exists()) await dir.create(recursive: true);
          } catch (_) {
            dir = await getExternalStorageDirectory();
          }
        } else if (Platform.isIOS) {
          dir = await getApplicationDocumentsDirectory();
        } else {
          dir = await getDownloadsDirectory();
          dir = Directory('${dir?.path}/NoteSync');
          if (!await dir.exists()) await dir.create(recursive: true);
        }
        final fileName =
            '${title.isEmpty ? "未命名灵感" : title}_${DateTime.now().millisecondsSinceEpoch}.md';
        final file = File('${dir!.path}/$fileName');
        await file.writeAsString(mdContent);
        if (mounted) ToastUtils.showSuccess(context, 'Markdown 已保存至本地✨');
        await Share.shareXFiles([
          XFile(file.path),
        ], text: '分享笔记: ${title.isEmpty ? "未命名" : title}');
      } catch (e) {
        if (mounted) ToastUtils.showError(context, '导出失败，请检查存储权限');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor =
        theme.brightness == Brightness.light
            ? Colors.white
            : const Color(0xFF1A1C1E);
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('已保存'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        },
        child: Scaffold(
          backgroundColor: surfaceColor,
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            backgroundColor: surfaceColor.withValues(alpha: 0.95),
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            title:
                viewModel.isReadOnly
                    ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '沉浸阅读',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                    : null,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: theme.colorScheme.onSurface,
              ),
              onPressed: () async {
                FocusScope.of(context).unfocus();
                await viewModel.saveNote();
                if (context.mounted) Navigator.pop(context);
              },
            ),
            actions: [
              if (viewModel.isDirty)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      viewModel.saveNote();
                    },
                    icon: Icon(
                      Icons.check_circle_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    tooltip: '保存',
                  ),
                ),
              IconButton(
                tooltip: viewModel.isReadOnly ? '切换到编辑' : '切换到阅读',
                icon: Icon(
                  viewModel.isReadOnly
                      ? Icons.edit_note_rounded
                      : Icons.menu_book_rounded,
                  color:
                      viewModel.isReadOnly
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  viewModel.toggleReadOnly();
                },
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.ios_share_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                position: PopupMenuPosition.under,
                color: theme.colorScheme.surfaceContainerHighest,
                onSelected: (value) => _handleExport(value, viewModel),
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: 'image_preview',
                        child: Row(
                          children: [
                            Icon(
                              Icons.image_outlined,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            const Text('生成长图分享 / 保存'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'markdown',
                        child: Row(
                          children: [
                            Icon(
                              Icons.code_outlined,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            const Text('导出 / 分享 Markdown'),
                          ],
                        ),
                      ),
                    ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            bottom: false,
            child:
                isDesktop
                    ? _buildDesktopLayout(theme, viewModel)
                    : _buildMobileLayout(theme, viewModel),
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
                    child: _buildScrollableContent(
                      theme,
                      viewModel,
                      48.0,
                      24.0,
                    ),
                  ),
                ),
              ),
              if (!viewModel.isReadOnly) _buildBottomToolbar(viewModel),
            ],
          ),
        ),
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        const NoteMetadataPanel(isMobile: false),
      ],
    );
  }

  Widget _buildMobileLayout(ThemeData theme, NoteEditorViewModel viewModel) {
    return Column(
      children: [
        Expanded(child: _buildScrollableContent(theme, viewModel, 24.0, 12.0)),
        if (!viewModel.isReadOnly) _buildBottomToolbar(viewModel),
      ],
    );
  }

  Widget _buildScrollableContent(
    ThemeData theme,
    NoteEditorViewModel viewModel,
    double horizontalPadding,
    double topPadding,
  ) {
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
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  topPadding,
                  horizontalPadding,
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitleField(theme, viewModel),
                    const SizedBox(height: 12),
                    Text(
                      '${viewModel.currentNote != null ? DateFormatter.formatFullDateTime(viewModel.currentNote!.updatedAt) : DateFormatter.formatFullDateTime(DateTime.now())}  |  ${viewModel.wordCount}字',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (horizontalPadding == 24.0)
                      const NoteMetadataPanel(isMobile: true),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: _buildQuillEditor(theme, viewModel),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!viewModel.isReadOnly) {
                    globalImageLock = false;
                    _editorFocusNode.requestFocus();
                    final length = viewModel.quillController.document.length;
                    viewModel.quillController.updateSelection(
                      TextSelection.collapsed(
                        offset: length > 0 ? length - 1 : 0,
                      ),
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
      controller: viewModel.titleController,
      focusNode: _titleFocusNode,
      textInputAction: TextInputAction.next,
      readOnly: viewModel.isReadOnly,
      onEditingComplete: () {
        _editorFocusNode.requestFocus();
      },
      decoration: InputDecoration(
        hintText: '写个好标题...',
        hintStyle: TextStyle(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
          fontSize: 36,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
        filled: false,
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 36,
        fontWeight: FontWeight.w900,
        height: 1.3,
        letterSpacing: 0.5,
      ),
      maxLines: null,
    );
  }

  Widget _buildQuillEditor(ThemeData theme, NoteEditorViewModel viewModel) {
    final defaultTextStyle = TextStyle(
      fontSize: 16,
      height: 1.8,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
      letterSpacing: 0.4,
    );

    final listTextStyle = TextStyle(
      fontSize: 16,
      height: 1.25,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
      letterSpacing: 0.4,
    );

    return quill.QuillEditor.basic(
      controller: viewModel.quillController,
      focusNode: _editorFocusNode,
      scrollController: _editorInnerScrollController,
      config: quill.QuillEditorConfig(
        scrollable: false,
        expands: false,
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        placeholder: '从这里开始你的灵感...',
        autoFocus: false,
        showCursor: !viewModel.isReadOnly && !_isImageSelected,

        // 🌟 核心修复：接管超链接点击，调起外部浏览器！
        onLaunchUrl: (String? url) async {
          if (url == null || url.isEmpty) return;
          // 自动补全 http 头，防止 uri 解析失败
          var parsedUrl = url.startsWith('http') ? url : 'https://$url';
          try {
            final uri = Uri.parse(parsedUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          } catch (e) {
            debugPrint('链接无法打开: $parsedUrl');
          }
        },

        embedBuilders: [
          ImageEmbedBuilder(
            imageService: _imageService,
            onSelectionChange: (isSelected) {
              if (_isImageSelected != isSelected)
                setState(() => _isImageSelected = isSelected);
            },
          ),
        ],
        customStyles: quill.DefaultStyles(
          paragraph: quill.DefaultTextBlockStyle(
            defaultTextStyle,
            const quill.HorizontalSpacing(0, 0),
            const quill.VerticalSpacing(6, 6),
            const quill.VerticalSpacing(0, 0),
            null,
          ),
          h1: quill.DefaultTextBlockStyle(
            TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.3,
              color: theme.colorScheme.onSurface,
              letterSpacing: 0.5,
            ),
            const quill.HorizontalSpacing(0, 0),
            const quill.VerticalSpacing(28, 12),
            const quill.VerticalSpacing(0, 0),
            null,
          ),
          h2: quill.DefaultTextBlockStyle(
            TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.3,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
            ),
            const quill.HorizontalSpacing(0, 0),
            const quill.VerticalSpacing(20, 10),
            const quill.VerticalSpacing(0, 0),
            null,
          ),
          h3: quill.DefaultTextBlockStyle(
            TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
            const quill.HorizontalSpacing(0, 0),
            const quill.VerticalSpacing(16, 8),
            const quill.VerticalSpacing(0, 0),
            null,
          ),
          quote: quill.DefaultTextBlockStyle(
            TextStyle(
              fontSize: 15,
              height: 1.6,
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
            const quill.HorizontalSpacing(16, 0),
            const quill.VerticalSpacing(12, 12),
            const quill.VerticalSpacing(0, 0),
            BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              border: Border(
                left: BorderSide(color: theme.colorScheme.primary, width: 4),
              ),
            ),
          ),
          code: quill.DefaultTextBlockStyle(
            GoogleFonts.firaCode(
              fontSize: 14,
              height: 1.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const quill.HorizontalSpacing(16, 16),
            const quill.VerticalSpacing(12, 12),
            const quill.VerticalSpacing(0, 0),
            BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          lists: quill.DefaultListBlockStyle(
            listTextStyle,
            const quill.HorizontalSpacing(0, 0),
            const quill.VerticalSpacing(8, 8),
            const quill.VerticalSpacing(6, 6),
            null,
            null,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomToolbar(NoteEditorViewModel viewModel) {
    return SafeArea(
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
          _editorFocusNode.requestFocus();
        },
        onFinish: () async {
          FocusScope.of(context).unfocus();
          await viewModel.saveNote();
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}
