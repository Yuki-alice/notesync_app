// 文件路径: lib/features/notes/presentation/views/note_editor_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/services/image_storage_service.dart';
import '../../../../models/note.dart';
import '../../../../utils/toast_utils.dart';
import '../viewmodels/note_editor_viewmodel.dart';
import '../widgets/dialogs/ai_assistant_sheet.dart';
import '../widgets/note_image_embed.dart';
import 'layouts/editor_mobile_layout.dart';
import 'note_export_preview_page.dart';
import 'layouts/editor_desktop_layout.dart';

class EditorFocusNode extends FocusNode {
  @override
  void requestFocus([FocusNode? node]) {
    if (globalImageLock) return;
    super.requestFocus(node);
  }
}

class NoteEditorPage extends StatelessWidget {
  final Note? note;
  final bool isPrivate;
  const NoteEditorPage({super.key, this.note, this.isPrivate = false});

  @override
  Widget build(BuildContext context) {
    final notesProvider = context.read<NotesProvider>();
    final isProMode = context.watch<ThemeProvider>().isProMode;

    return ChangeNotifierProvider(
      create:
          (_) => NoteEditorViewModel(
            note: note,
            notesProvider: notesProvider,
            isProMode: isProMode,
            isPrivate: isPrivate,
          ),
      child: const _NoteEditorShell(),
    );
  }
}

class _NoteEditorShell extends StatefulWidget {
  const _NoteEditorShell();
  @override
  State<_NoteEditorShell> createState() => _NoteEditorShellState();
}

class _NoteEditorShellState extends State<_NoteEditorShell> {
  late final EditorFocusNode _editorFocusNode;
  final FocusNode _titleFocusNode = FocusNode();
  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _editorInnerScrollController = ScrollController();
  final ImageStorageService _imageService = ImageStorageService();

  @override
  void initState() {
    super.initState();
    globalImageLock = false; // 重置幽灵锁
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
    globalImageLock = false;
    _editorFocusNode.dispose();
    _titleFocusNode.dispose();
    _mainScrollController.dispose();
    _editorInnerScrollController.dispose();
    super.dispose();
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
        Directory? dir =
            Platform.isAndroid
                ? Directory('/storage/emulated/0/Download/NoteSync')
                : await getDownloadsDirectory();
        if (Platform.isIOS) dir = await getApplicationDocumentsDirectory();

        if (dir != null) {
          if (!await dir.exists()) await dir.create(recursive: true);
          final fileName =
              '${title.isEmpty ? "未命名灵感" : title}_${DateTime.now().millisecondsSinceEpoch}.md';
          final file = File('${dir.path}/$fileName');
          await file.writeAsString(mdContent);
          if (mounted) ToastUtils.showSuccess(context, 'Markdown 已保存至本地✨');
          await Share.shareXFiles([
            XFile(file.path),
          ], text: '分享笔记: ${title.isEmpty ? "未命名" : title}');
        }
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
          appBar:
              isDesktop
                  ? null
                  : _buildMobileAppBar(theme, viewModel, surfaceColor),
          body: SafeArea(
            bottom: false,
            child:
                isDesktop
                    ? EditorDesktopLayout(
                      // 报错红线绝对消失了！
                      theme: theme,
                      viewModel: viewModel,
                      editorFocusNode: _editorFocusNode,
                      titleFocusNode: _titleFocusNode,
                      mainScrollController: _mainScrollController,
                      editorInnerScrollController: _editorInnerScrollController,
                      imageService: _imageService,
                    )
                    : EditorMobileLayout(
                      theme: theme,
                      viewModel: viewModel,
                      editorFocusNode: _editorFocusNode,
                      titleFocusNode: _titleFocusNode,
                      mainScrollController: _mainScrollController,
                      editorInnerScrollController: _editorInnerScrollController,
                      imageService: _imageService,
                    ),
          ),
        ),
      ),
    );
  }

  // 手机端 AppBar
  PreferredSizeWidget _buildMobileAppBar(
    ThemeData theme,
    NoteEditorViewModel viewModel,
    Color surfaceColor,
  ) {
    return AppBar(
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
        IconButton(
          tooltip: 'AI 伴写',
          icon: Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
          onPressed: () => _showAiMenu(viewModel),
        ),
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
    );
  }

  void _showAiMenu(NoteEditorViewModel viewModel) {
    FocusScope.of(context).unfocus(); // 先收起键盘，防止键盘和弹窗打架
    final theme = Theme.of(context);

    // 获取当前选中的文本
    final controller = viewModel.quillController;
    final selection = controller.selection;
    String textToProcess = '';
    bool hasSelection = selection.extentOffset - selection.baseOffset > 0;

    if (hasSelection) {
      textToProcess = controller.document.getPlainText(
        selection.baseOffset,
        selection.extentOffset - selection.baseOffset,
      );
    } else {
      // 如果没选中任何文字，就提取全文
      textToProcess = controller.document.toPlainText();
    }

    if (textToProcess.trim().isEmpty) {
      ToastUtils.showError(context, '请先输入或选中一些内容');
      return;
    }

    // 弹出菜单选择操作
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_fix_high),
                  title: const Text('润色排版'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _triggerAi(
                      viewModel,
                      textToProcess,
                      'polish',
                      '润色排版',
                      hasSelection,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.format_size),
                  title: const Text('扩写内容'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _triggerAi(
                      viewModel,
                      textToProcess,
                      'expand',
                      '扩写内容',
                      hasSelection,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.compress),
                  title: const Text('提炼总结'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _triggerAi(
                      viewModel,
                      textToProcess,
                      'summarize',
                      '提炼总结',
                      hasSelection,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.g_translate),
                  title: const Text('智能翻译'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _triggerAi(
                      viewModel,
                      textToProcess,
                      'translate',
                      '智能翻译',
                      hasSelection,
                    );
                  },
                ),
              ],
            ),
          ),
    );
  }

  // 🌟 触发大模型并回写编辑器
  void _triggerAi(
    NoteEditorViewModel viewModel,
    String text,
    String type,
    String name,
    bool hasSelection,
  ) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) =>
              AiAssistantSheet(text: text, actionType: type, actionName: name),
    );

    if (result != null && mounted) {
      final action = result['action'];
      final generatedText = result['text']!;
      final controller = viewModel.quillController;
      final selection = controller.selection;

      if (action == 'replace' && hasSelection) {
        // 替换选中的文字
        controller.replaceText(
          selection.baseOffset,
          selection.extentOffset - selection.baseOffset,
          generatedText,
          null,
        );
      } else {
        // 追加到光标处或末尾
        int insertIndex =
            selection.extentOffset > -1
                ? selection.extentOffset
                : controller.document.length - 1;
        controller.document.insert(insertIndex, '\n$generatedText\n');
      }
      viewModel.saveNote(); // 自动保存一下
      ToastUtils.showSuccess(context, 'AI 伴写已应用✨');
    }
  }
}
