// 文件路径: lib/features/notes/presentation/views/note_editor_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_quill/quill_delta.dart' as quill;
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
                      theme: theme,
                      viewModel: viewModel,
                      editorFocusNode: _editorFocusNode,
                      titleFocusNode: _titleFocusNode,
                      mainScrollController: _mainScrollController,
                      editorInnerScrollController: _editorInnerScrollController,
                      imageService: _imageService,
                  onAiPressed: ()=>_showAiMenu(viewModel),
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
// 🌟 AI 呼出处理逻辑 (响应式重构)
  void _showAiMenu(NoteEditorViewModel viewModel) {
    FocusScope.of(context).unfocus();
    final theme = Theme.of(context);
    // 🌟 判断是否为宽屏桌面端
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final controller = viewModel.quillController;
    final selection = controller.selection;
    String textToProcess = '';
    bool hasSelection = selection.extentOffset - selection.baseOffset > 0;

    if (hasSelection) {
      textToProcess = controller.document.getPlainText(selection.baseOffset, selection.extentOffset - selection.baseOffset);
    } else {
      textToProcess = controller.document.toPlainText();
    }

    if (textToProcess.trim().isEmpty) {
      ToastUtils.showError(context, '请先输入或选中一些内容');
      return;
    }

    String title = viewModel.titleController.text.trim();
    String fullContent = controller.document.toPlainText().trim();
    if (fullContent.length > 3000) fullContent = fullContent.substring(0, 3000);
    String fullContext = '笔记标题: ${title.isEmpty ? "未命名" : title}\n笔记全文: $fullContent';

    // 构建菜单项
    Widget buildMenuItems(BuildContext ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(leading: const Icon(Icons.auto_fix_high), title: const Text('润色排版'), onTap: () { Navigator.pop(ctx); _triggerAi(viewModel, textToProcess, 'polish', '润色排版', hasSelection, fullContext, isDesktop); }),
        ListTile(leading: const Icon(Icons.format_size), title: const Text('扩写内容'), onTap: () { Navigator.pop(ctx); _triggerAi(viewModel, textToProcess, 'expand', '扩写内容', hasSelection, fullContext, isDesktop); }),
        ListTile(leading: const Icon(Icons.compress), title: const Text('提炼总结'), onTap: () { Navigator.pop(ctx); _triggerAi(viewModel, textToProcess, 'summarize', '提炼总结', hasSelection, fullContext, isDesktop); }),
        ListTile(leading: const Icon(Icons.g_translate), title: const Text('智能翻译'), onTap: () { Navigator.pop(ctx); _triggerAi(viewModel, textToProcess, 'translate', '智能翻译', hasSelection, fullContext, isDesktop); }),
      ],
    );

    // 🌟 响应式弹出菜单
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(children: [Icon(Icons.auto_awesome, color: theme.colorScheme.primary), const SizedBox(width: 8), const Text('AI 伴写')]),
          content: SizedBox(width: 320, child: buildMenuItems(ctx)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(24)),
          child: buildMenuItems(ctx),
        ),
      );
    }
  }

  // 🌟 触发大模型并回写编辑器 (增加了 isDesktop 透传)
  void _triggerAi(NoteEditorViewModel viewModel, String text, String type, String name, bool hasSelection, String fullContext, bool isDesktop) async {

    // 🌟 响应式弹出 AI 预览舱
    final result = await (isDesktop
        ? showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false, // 桌面端防止误触边缘关闭
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: AiAssistantSheet(text: text, actionType: type, actionName: name, fullContext: fullContext, isDesktop: true),
      ),
    )
        : showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AiAssistantSheet(text: text, actionType: type, actionName: name, fullContext: fullContext, isDesktop: false),
    ));

    if (result != null && mounted) {
      // ... (下方解析并回写 Delta 的代码保持完全不变) ...
      final action = result['action'];
      final generatedMarkdown = result['text']!;
      final controller = viewModel.quillController;
      final selection = controller.selection;

      final generatedDelta = SimpleMarkdownToDelta.parse(generatedMarkdown);
      quill.Delta finalDelta = quill.Delta();

      if (action == 'replace' && hasSelection) {
        finalDelta..retain(selection.baseOffset)..delete(selection.extentOffset - selection.baseOffset);
        finalDelta = finalDelta.concat(generatedDelta);
      } else {
        int insertIndex = selection.extentOffset > -1 ? selection.extentOffset : controller.document.length - 1;
        finalDelta..retain(insertIndex)..insert('\n');
        finalDelta = finalDelta.concat(generatedDelta);
      }

      controller.document.compose(finalDelta, quill.ChangeSource.local);
      viewModel.saveNote();
      ToastUtils.showSuccess(context, 'AI 伴写已完美渲染');
    }
  }
}

// 🌟 架构师特供 V2.0：支持多级嵌套列表与空行压缩的转换引擎
class SimpleMarkdownToDelta {
  static quill.Delta parse(String markdown) {
    final delta = quill.Delta();
    final lines = markdown.split('\n');

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];

      // 🌟 核心修复 1：压缩多余的空行，防止列表间距过大
      if (line.trim().isEmpty) {
        // 如果上一行也是空行，直接跳过，防止连续空行
        if (i > 0 && lines[i - 1].trim().isEmpty) continue;
        delta.insert('\n');
        continue;
      }

      Map<String, dynamic>? lineAttributes;

      // 🌟 核心修复 2：计算前面的空格数量，推导出嵌套层级 (每 2 或 4 个空格算一级)
      String text = line.trimLeft();
      int spaceCount = line.length - text.length;
      int indentLevel = spaceCount ~/ 2;
      if (indentLevel > 5) indentLevel = 5; // Quill 一般最多支持几级缩进

      // 解析标题
      if (text.startsWith('# ')) {
        text = text.substring(2);
        lineAttributes = {'header': 1};
      } else if (text.startsWith('## ')) {
        text = text.substring(3);
        lineAttributes = {'header': 2};
      } else if (text.startsWith('### ')) {
        text = text.substring(4);
        lineAttributes = {'header': 3};
      }
      // 🌟 核心修复 3：无视前导空格，精准捕捉无序列表，并注入 indent 属性！
      else if (text.startsWith('- ') || text.startsWith('* ') || text.startsWith('+ ')) {
        text = text.substring(2);
        lineAttributes = {'list': 'bullet'};
        if (indentLevel > 0) lineAttributes['indent'] = indentLevel;
      }
      // 精准捕捉有序列表 (例如 "1. ")
      else if (RegExp(r'^\d+\.\s').hasMatch(text)) {
        text = text.replaceFirst(RegExp(r'^\d+\.\s'), '');
        lineAttributes = {'list': 'ordered'};
        if (indentLevel > 0) lineAttributes['indent'] = indentLevel;
      }

      // 剔除 AI 喜欢用的加粗符号，保持纯净文本
      text = text.replaceAll('**', '').replaceAll('__', '').replaceAll('`', '');

      // 插入文本并应用块级格式
      delta.insert(text + '\n', lineAttributes);
    }
    return delta;
  }
}
