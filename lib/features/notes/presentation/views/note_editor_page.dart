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
import '../../../../utils/toast_utils.dart';
import '../viewmodels/note_editor_viewmodel.dart';
import '../widgets/dialogs/add_tag_dialog.dart';
import '../widgets/dialogs/set_category_sheet.dart';
import '../widgets/note_image_embed.dart';
import '../widgets/editor_bottom_toolbar.dart';

// 🟢 引入刚刚新建的长图预览页面
import 'note_export_preview_page.dart';

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
          create:
              (_) => NoteEditorViewModel(
                note: note,
                notesProvider: notesProvider,
                isProMode: isProMode,
              ),
          child: const _NoteEditorView(),
        );
      },
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

  // 🟢 轻量级的菜单分发逻辑
  Future<void> _handleExport(String type, NoteEditorViewModel viewModel) async {
    FocusScope.of(context).unfocus();
    final title =
        viewModel.titleController.text.trim().isEmpty
            ? '未命名笔记'
            : viewModel.titleController.text.trim();

    if (type == 'image_preview') {
      // 🟢 将当前 Delta 数据转为 JSON，传递给专门的后台渲染页面
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
      // 🟢 满血 Markdown 本地直存 + 系统分享引擎
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

        // 立即呼出系统分享面板
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
            backgroundColor: surfaceColor.withOpacity(0.95),
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
                              Icons.image_rounded,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            const Text('生成图片分享'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'markdown',
                        child: Row(
                          children: [
                            Icon(
                              Icons.code_rounded,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            const Text('分享Markdown'),
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
                    // 🟢 恢复原版的多层嵌套滚动
                    child: NestedScrollView(
                      headerSliverBuilder:
                          (context, innerBoxIsScrolled) => [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  48,
                                  24,
                                  48,
                                  16,
                                ),
                                child: _buildTitleField(theme, viewModel),
                              ),
                            ),
                          ],
                      body: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: _buildQuillEditor(theme, viewModel),
                      ),
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
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
        Container(
          width: 320,
          color: theme.colorScheme.surfaceContainerLowest,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildPanelSectionTitle(theme, '信息', Icons.info_outline_rounded),
              const SizedBox(height: 16),
              _buildInfoRow(
                theme,
                '创建',
                viewModel.currentNote != null
                    ? _formatHeaderDate(viewModel.currentNote!.createdAt)
                    : '现在',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                theme,
                '修改',
                viewModel.currentNote != null
                    ? _formatHeaderDate(viewModel.currentNote!.updatedAt)
                    : '现在',
              ),
              const SizedBox(height: 12),
              _buildInfoRow(theme, '字数', '${viewModel.wordCount} 字'),
              const SizedBox(height: 32),
              _buildPanelSectionTitle(theme, '归属', Icons.folder_outlined),
              const SizedBox(height: 16),
              _buildCategorySelector(theme, viewModel),
              const SizedBox(height: 32),
              _buildPanelSectionTitle(theme, '标签', Icons.tag_rounded),
              const SizedBox(height: 16),
              _buildTagsWrap(theme, viewModel),
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
          // 🟢 恢复原版的嵌套滚动：完美解决键盘遮挡和顶部标签占位问题
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleField(theme, viewModel),
                        const SizedBox(height: 12),
                        Text(
                          '${viewModel.currentNote != null ? _formatHeaderDate(viewModel.currentNote!.updatedAt) : _formatHeaderDate(DateTime.now())}  |  ${viewModel.wordCount}字',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant
                                .withOpacity(0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildCategorySelector(theme, viewModel),
                            _buildTagsWrap(theme, viewModel, isMobile: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildQuillEditor(theme, viewModel),
            ),
          ),
        ),
        if (!viewModel.isReadOnly) _buildBottomToolbar(viewModel),
      ],
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
        hintText: '标题',
        hintStyle: TextStyle(
          color: theme.colorScheme.outline.withOpacity(0.3),
          fontSize: 34,
          fontWeight: FontWeight.bold,
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
        fontSize: 34,
        fontWeight: FontWeight.bold,
        height: 1.3,
      ),
      maxLines: null,
    );
  }

  Widget _buildQuillEditor(ThemeData theme, NoteEditorViewModel viewModel) {
    return quill.QuillEditor.basic(
      controller: viewModel.quillController,
      focusNode: _editorFocusNode,
      config: quill.QuillEditorConfig(
        // 🟢 保持完美的滚动体验：不遮挡键盘，光标自动跟随
        scrollable: true,
        expands: true,
        padding: const EdgeInsets.only(bottom: 120),
        placeholder: '记点什么...',
        autoFocus: false,
        // 隐藏两侧残留的烦人光标
        showCursor: !viewModel.isReadOnly && !_isImageSelected,

        // 🟢 终极防闪烁杀招：在底层抢占 Tap（点击）事件
        // 🟢 终极防闪烁杀招：在底层抢占 Tap（点击）事件
        onTapUp: (details, getPosition) {
          try {
            // 获取手指点击的精确文档位置
            final pos = getPosition(details.localPosition);

            final leaf = viewModel.quillController.document.querySegmentLeafNode(pos.offset).leaf;

            // 判断点击的位置是不是一个图片节点
            if (leaf != null && leaf.value is Map && (leaf.value as Map).containsKey('image')) {
              // 1. 彻底取消焦点
              _editorFocusNode.unfocus();
              // 2. 强行隐去系统键盘
              SystemChannels.textInput.invokeMethod('TextInput.hide');
              // 3. 核心：返回 true，告诉 Quill “这个点击我已经拦截并处理了”
              return true;
            }
          } catch (_) {}

          // 非图片区域，返回 false，让 Quill 正常弹键盘打字
          return false;
        },

        embedBuilders: [
          ImageEmbedBuilder(
            imageService: _imageService,
            onSelectionChange: (isSelected) {
              // 这里只需纯粹地管理选中状态即可，拦截键盘的脏活已经交给 onTapUp 办了
              if (_isImageSelected != isSelected) {
                setState(() { _isImageSelected = isSelected; });
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

  Widget _buildCategorySelector(
    ThemeData theme,
    NoteEditorViewModel viewModel,
  ) {
    return InkWell(
      onTap:
          viewModel.isReadOnly
              ? null
              : () async {
                final selected = await showSetCategorySheet(
                  context,
                  currentCategory: viewModel.category,
                );
                if (selected != null)
                  viewModel.setCategory(selected.isEmpty ? null : selected);
              },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              viewModel.category == null
                  ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
                  : theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
          border:
              viewModel.category == null
                  ? Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.1),
                  )
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              viewModel.category == null
                  ? Icons.folder_open_outlined
                  : Icons.folder_rounded,
              size: 16,
              color:
                  viewModel.category == null
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Text(
              viewModel.category ?? '未分类',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    viewModel.category == null
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsWrap(
    ThemeData theme,
    NoteEditorViewModel viewModel, {
    bool isMobile = false,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...viewModel.tags.map(
          (tag) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '#$tag',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                if (!viewModel.isReadOnly)
                  InkWell(
                    onTap: () => viewModel.removeTag(tag),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: theme.colorScheme.secondary.withOpacity(0.7),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!viewModel.isReadOnly)
          InkWell(
            onTap: () async {
              final newTag = await showAddTagDialog(context);
              if (newTag != null) viewModel.addTag(newTag);
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
                borderRadius: BorderRadius.circular(20),
                color:
                    isMobile ? Colors.transparent : theme.colorScheme.surface,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '添加标签',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(
                        0.8,
                      ),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
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

  Widget _buildPanelSectionTitle(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(color: theme.colorScheme.outline, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
