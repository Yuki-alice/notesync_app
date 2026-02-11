// 文件路径: lib/features/notes/presentation/views/note_editor_page.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/notes_provider.dart';
import '../../../../core/services/image_storage_service.dart';
import '../../../../models/note.dart';
import '../widgets/dialogs/add_tag_dialog.dart';
import '../widgets/dialogs/set_category_sheet.dart';
import '../widgets/note_image_embed.dart';
import '../widgets/editor_bottom_toolbar.dart';

class NoteEditorPage extends StatefulWidget {
  final Note? note;
  const NoteEditorPage({super.key, this.note});
  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late quill.QuillController _quillController;
  late TextEditingController _titleController;
  bool _isImageSelected = false;
  final FocusNode _editorFocusNode = FocusNode();
  final FocusNode _titleFocusNode = FocusNode();

  List<String> _tags = [];
  String? _category;

  Note? _editingNote;

  final ImageStorageService _imageService = ImageStorageService();
  ToolbarPanel _activePanel = ToolbarPanel.none;
  bool _isDirty = false;

  final ValueNotifier<int> _wordCountNotifier = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _editingNote = widget.note;

    _titleController = TextEditingController(text: _editingNote?.title ?? '');
    _tags = _editingNote?.tags.toList() ?? [];
    _category = _editingNote?.category;

    _initQuillController();

    _titleController.addListener(_markAsDirty);

    _quillController.document.changes.listen((quill.DocChange event) {
      _wordCountNotifier.value = _quillController.document.toPlainText().trim().length;
      if (event.source == quill.ChangeSource.local) {
        _markAsDirty();
      }
    });
  }

  void _markAsDirty() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
  }

  void _initQuillController() {
    try {
      if (_editingNote != null && _editingNote!.content.isNotEmpty) {
        if (_editingNote!.isRichText) {
          final jsonContent = jsonDecode(_editingNote!.content);
          _quillController = quill.QuillController(
            document: quill.Document.fromJson(jsonContent),
            selection: const TextSelection.collapsed(offset: 0),
          );
        } else {
          final doc = quill.Document()..insert(0, _editingNote!.content);
          _quillController = quill.QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
          );
        }
      } else {
        _quillController = quill.QuillController.basic();
      }
      _wordCountNotifier.value = _quillController.document.toPlainText().trim().length;
    } catch (e) {
      _quillController = quill.QuillController.basic();
    }
  }

  @override
  void dispose() {
    _quillController.dispose();
    _titleController.dispose();
    _editorFocusNode.dispose();
    _titleFocusNode.dispose();
    _wordCountNotifier.dispose();
    super.dispose();
  }

  Future<void> _pickAndInsertImage() async {
    FocusScope.of(context).unfocus();
    setState(() => _activePanel = ToolbarPanel.none);

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final File file = File(image.path);
      final String localPath = await _imageService.saveImage(file);

      var index = _quillController.selection.baseOffset;
      final length = _quillController.document.length;
      if (index < 0) index = length - 1;

      _quillController.document.insert(index, quill.BlockEmbed.image(localPath));
      _quillController.document.insert(index + 1, '\n');

      setState(() {
        _quillController.updateSelection(TextSelection.collapsed(offset: index + 2), quill.ChangeSource.local);
      });
      _editorFocusNode.requestFocus();
      _markAsDirty();
    }
  }

  Future<void> _saveNote({bool closePage = false}) async {
    if (!_isDirty && _editingNote != null) {
      if (closePage && mounted) Navigator.pop(context);
      return;
    }

    final title = _titleController.text.trim();
    if (_editingNote == null && title.isEmpty && _quillController.document.isEmpty()) {
      if (closePage && mounted) Navigator.pop(context);
      return;
    }

    final contentJson = jsonEncode(_quillController.document.toDelta().toJson());
    final provider = Provider.of<NotesProvider>(context, listen: false);

    if (_editingNote == null) {
      final newNote = await provider.addNote(
          title: title.isEmpty ? '未命名笔记' : title,
          content: contentJson,
          tags: _tags,
          category: _category);

      if (mounted) {
        setState(() {
          _editingNote = newNote;
          _isDirty = false;
        });
      }
    } else {
      final updatedNote = _editingNote!.copyWith(
          title: title,
          content: contentJson,
          tags: _tags,
          category: _category,
          updatedAt: DateTime.now());

      await provider.updateNote(updatedNote);

      if (mounted) {
        setState(() {
          _editingNote = updatedNote;
          _isDirty = false;
        });
      }
    }

    if (closePage && mounted) Navigator.pop(context);
  }

  void _togglePanel(ToolbarPanel panel) {
    setState(() {
      _activePanel = (_activePanel == panel) ? ToolbarPanel.none : panel;
      if (_activePanel != ToolbarPanel.none) _editorFocusNode.requestFocus();
    });
  }

  void _undo() { if (_quillController.hasUndo) { _quillController.undo(); setState(() {}); } }
  void _redo() { if (_quillController.hasRedo) { _quillController.redo(); setState(() {}); } }

  void _showAddTagDialog() async {
    final String? newTag = await showAddTagDialog(context);
    if (newTag != null && newTag.isNotEmpty) {
      _commitTag(newTag);
    }
  }
  void _commitTag(String tag) { final trimmed = tag.trim(); if (trimmed.isNotEmpty && !_tags.contains(trimmed)) { setState(() { _tags.add(trimmed); _isDirty = true; }); } }
  void _removeTag(String tag) { setState(() { _tags.remove(tag); _isDirty = true; }); }

  void _pickCategory() async {
    final String? selected = await showSetCategorySheet(context, currentCategory: _category);

    if (selected != null) {
      setState(() {
        _category = selected.isEmpty ? null : selected;
        _isDirty = true;
      });
    }
  }

  String _formatHeaderDate(DateTime date) {
    return DateFormat('M月d日 a h:mm', 'zh_CN').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.brightness == Brightness.light ? Colors.white : const Color(0xFF1A1C1E);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _saveNote(closePage: true);
      },
      child: Scaffold(
        backgroundColor: surfaceColor,
        // 🟢 允许 Scaffold 随键盘调整大小，解决 RenderFlex overflow
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: surfaceColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
            onPressed: () => _saveNote(closePage: true),
          ),
          actions: [
            if (_isDirty)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  onPressed: () => _saveNote(closePage: false),
                  icon: Icon(Icons.check_rounded, color: theme.colorScheme.primary),
                  tooltip: '保存',
                ),
              ),
            IconButton(
              icon: Icon(Icons.more_vert_rounded, color: theme.colorScheme.onSurface),
              onPressed: () {},
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 🟢 使用 Expanded 包裹滚动区域，确保占用剩余空间
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [

                    // 1. 标题
                    TextField(
                      controller: _titleController,
                      focusNode: _titleFocusNode,
                      decoration: InputDecoration(
                        hintText: '标题',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.outline.withValues(alpha: 0.3),
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
                          height: 1.3
                      ),
                      textInputAction: TextInputAction.next,
                      maxLines: null,
                    ),

                    const SizedBox(height: 12),

                    // 2. 元信息 (时间 | 字数)
                    ValueListenableBuilder<int>(
                      valueListenable: _wordCountNotifier,
                      builder: (context, count, _) {
                        final dateStr = _editingNote != null
                            ? _formatHeaderDate(_editingNote!.updatedAt)
                            : _formatHeaderDate(DateTime.now());

                        return Text(
                          '$dateStr  |  $count字',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // 3. 🟢 优化后的分类与标签栏
                    Wrap(
                      spacing: 12, // 增加水平间距
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // 🟢 分类 Chip (饱满的胶囊样式)
                        InkWell(
                          onTap: _pickCategory,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // 增加 Padding，不再细长
                            decoration: BoxDecoration(
                              // 使用 MD3 风格的 Surface Container
                              color: _category == null
                                  ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                                  : theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                              border: _category == null
                                  ? Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1))
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _category == null ? Icons.folder_open_outlined : Icons.folder_rounded,
                                  size: 16,
                                  color: _category == null
                                      ? theme.colorScheme.onSurfaceVariant
                                      : theme.colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _category ?? '未分类',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _category == null
                                        ? theme.colorScheme.onSurfaceVariant
                                        : theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 标签列表
                        ..._tags.map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('#$tag', style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.w500
                              )),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => _removeTag(tag),
                                child: Icon(Icons.close_rounded, size: 14, color: theme.colorScheme.secondary.withValues(alpha: 0.7)),
                              )
                            ],
                          ),
                        )),

                        // 🟢 添加标签按钮 (文字 + 图标，更清晰)
                        InkWell(
                          onTap: _showAddTagDialog,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              // 虚线或淡色边框效果
                              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                    Icons.add_rounded,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8)
                                ),
                                const SizedBox(width: 4),
                                Text(
                                    '添加标签',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                        fontWeight: FontWeight.w500
                                    )
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // 4. 正文编辑器
                    quill.QuillEditor.basic(
                      controller: _quillController,
                      focusNode: _editorFocusNode,
                      config: quill.QuillEditorConfig(
                        placeholder: '记点什么...',
                        autoFocus: false,
                        scrollable: false, // 禁用内部滚动，由外层 ListView 滚动
                        expands: false,
                        padding: EdgeInsets.zero,
                        showCursor: !_isImageSelected,
                        embedBuilders: [
                          ImageEmbedBuilder(
                            imageService: _imageService,
                            onSelectionChange: (isSelected) {
                              if (_isImageSelected != isSelected) {
                                setState(() {
                                  _isImageSelected = isSelected;
                                  _quillController.readOnly = isSelected;
                                });
                              }
                            },
                          ),
                        ],
                        customStyles: quill.DefaultStyles(
                          paragraph: quill.DefaultTextBlockStyle(
                              TextStyle(
                                  fontSize: 17,
                                  height: 1.6,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85)
                              ),
                              const quill.HorizontalSpacing(0, 0),
                              const quill.VerticalSpacing(0, 0),
                              const quill.VerticalSpacing(0, 0),
                              null
                          ),
                          h1: quill.DefaultTextBlockStyle(
                              TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.5, color: theme.colorScheme.onSurface),
                              const quill.HorizontalSpacing(0, 0), const quill.VerticalSpacing(16, 0), const quill.VerticalSpacing(0, 0), null
                          ),
                        ),
                      ),
                    ),

                    // 底部留白
                    const SizedBox(height: 300),
                  ],
                ),
              ),

              SafeArea(
                top: false,
                child: EditorBottomToolbar(
                  controller: _quillController,
                  activePanel: _activePanel,
                  onPanelChanged: _togglePanel,
                  onUndo: _undo,
                  onRedo: _redo,
                  onPickImage: _pickAndInsertImage,
                  onFinish: () => _saveNote(closePage: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}