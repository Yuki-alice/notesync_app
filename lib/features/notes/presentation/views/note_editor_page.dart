import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/notes_provider.dart';
import '../../../../core/services/image_storage_service.dart';
import '../../../../models/note.dart';
// 🟢 引入独立的图片处理组件 (请确保该文件已存在)
import '../widgets/note_image_embed.dart';

// 工具栏激活面板枚举
enum _ToolbarPanel { none, textStyle, paragraphStyle, color }

class NoteEditorPage extends StatefulWidget {
  final Note? note;
  const NoteEditorPage({super.key, this.note});
  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late quill.QuillController _quillController;
  late TextEditingController _titleController;
  final FocusNode _editorFocusNode = FocusNode();
  final FocusNode _titleFocusNode = FocusNode();
  List<String> _tags = [];
  String? _category;

  // 🟢 实例化 ImageService
  final ImageStorageService _imageService = ImageStorageService();

  _ToolbarPanel _activePanel = _ToolbarPanel.none;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _tags = widget.note?.tags.toList() ?? [];
    _category = widget.note?.category;
    _initQuillController();

    _editorFocusNode.addListener(() {
      if (!_editorFocusNode.hasFocus && _activePanel != _ToolbarPanel.none) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_editorFocusNode.hasFocus) {
            // 失去焦点时逻辑（可选）
          }
        });
      }
    });

    _titleController.addListener(_markAsDirty);
    _quillController.document.changes.listen((quill.DocChange event) {
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
      if (widget.note != null && widget.note!.content.isNotEmpty) {
        if (widget.note!.isRichText) {
          final jsonContent = jsonDecode(widget.note!.content);
          _quillController = quill.QuillController(
            document: quill.Document.fromJson(jsonContent),
            selection: const TextSelection.collapsed(offset: 0),
          );
        } else {
          final doc = quill.Document()..insert(0, widget.note!.content);
          _quillController = quill.QuillController(
            document: doc,
            selection: const TextSelection.collapsed(offset: 0),
          );
        }
      } else {
        _quillController = quill.QuillController.basic();
      }
    } catch (e) {
      _quillController = quill.QuillController.basic();
    }
  }

  @override
  void dispose() {
    OverlayMenuManager.hide(); // 确保退出时清理悬浮菜单
    _quillController.dispose();
    _titleController.dispose();
    _editorFocusNode.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  // 🟢 修复后的插入图片逻辑
  Future<void> _pickAndInsertImage() async {
    FocusScope.of(context).unfocus();
    setState(() => _activePanel = _ToolbarPanel.none);
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final File file = File(image.path);
      // 保存到本地并获取相对路径
      final String localPath = await _imageService.saveImage(file);

      var index = _quillController.selection.baseOffset;
      final length = _quillController.document.length;
      if (index < 0) index = length - 1;

      // 插入图片Block
      _quillController.document.insert(index, quill.BlockEmbed.image(localPath));
      _quillController.document.insert(index + 1, '\n');

      setState(() {
        _quillController.updateSelection(TextSelection.collapsed(offset: index + 2), quill.ChangeSource.local);
      });
      _editorFocusNode.requestFocus();
      _markAsDirty();
    }
  }

  // ... (此处保留 _showAddTagDialog, _commitTag, _removeTag, _saveNote, _pickCategory 等所有业务逻辑方法，保持不变) ...
  // 为了确保代码可运行，我将关键的保存逻辑完整写出

  Future<void> _saveNote({bool closePage = false}) async {
    if (!_isDirty && widget.note != null) {
      if (closePage && mounted) Navigator.pop(context);
      return;
    }
    final title = _titleController.text.trim();
    if (title.isEmpty && _quillController.document.isEmpty()) {
      if (closePage && mounted) Navigator.pop(context);
      return;
    }

    final contentJson = jsonEncode(_quillController.document.toDelta().toJson());
    final provider = Provider.of<NotesProvider>(context, listen: false);

    if (widget.note == null) {
      await provider.addNote(title: title.isEmpty ? '未命名笔记' : title, content: contentJson, tags: _tags, category: _category);
    } else {
      await provider.updateNote(widget.note!.copyWith(title: title, content: contentJson, tags: _tags, category: _category, updatedAt: DateTime.now()));
    }
    _isDirty = false;
    if (mounted) setState(() {});
    if (closePage && mounted) Navigator.pop(context);
  }

  void _showAddTagDialog() {
    String tempTag = '';
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('添加标签'),
      content: TextField(autofocus: true, decoration: const InputDecoration(hintText: '输入标签名称', border: OutlineInputBorder()), onChanged: (v) => tempTag = v, onSubmitted: (v) { _commitTag(v); Navigator.pop(ctx); }),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')), FilledButton(onPressed: () { _commitTag(tempTag); Navigator.pop(ctx); }, child: const Text('添加'))],
    ));
  }

  void _commitTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed)) { setState(() { _tags.add(trimmed); _isDirty = true; }); }
  }

  void _removeTag(String tag) { setState(() { _tags.remove(tag); _isDirty = true; }); }

  void _pickCategory() async {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final categories = provider.categories;
    final theme = Theme.of(context);
    final textController = TextEditingController();
    final String? selected = await showModalBottomSheet<String>(
      context: context, isScrollControlled: true, showDragHandle: true, backgroundColor: theme.colorScheme.surface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('设置分类', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextField(controller: textController, autofocus: true, decoration: InputDecoration(hintText: '输入新分类...', prefixIcon: const Icon(Icons.create_new_folder_outlined), filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), suffixIcon: IconButton(icon: const Icon(Icons.check_circle_rounded), onPressed: () => Navigator.pop(ctx, textController.text.trim()))), onSubmitted: (v) => Navigator.pop(ctx, v.trim())),
          const SizedBox(height: 24),
          if (categories.isNotEmpty) Wrap(spacing: 8, children: [
            ActionChip(label: const Text('无分类'), onPressed: () => Navigator.pop(ctx, '')),
            ...categories.map((c) => FilterChip(label: Text(c), selected: _category == c, onSelected: (_) => Navigator.pop(ctx, c))),
          ])
        ]),
      ),
    );
    if (selected != null) setState(() { _category = selected.isEmpty ? null : selected; _isDirty = true; });
  }

  void _undo() { if (_quillController.hasUndo) { _quillController.undo(); setState(() {}); } }
  void _redo() { if (_quillController.hasRedo) { _quillController.redo(); setState(() {}); } }

  void _togglePanel(_ToolbarPanel panel) {
    setState(() {
      _activePanel = (_activePanel == panel) ? _ToolbarPanel.none : panel;
      if (_activePanel != _ToolbarPanel.none) _editorFocusNode.requestFocus();
    });
  }

  quill.QuillToolbarToggleStyleButtonOptions _getToggleStyleOptions(IconData icon, {String? tooltip, bool isSecondaryPanel = true}) {
    final theme = Theme.of(context);
    return quill.QuillToolbarToggleStyleButtonOptions(
      iconData: icon, tooltip: tooltip,
      iconTheme: quill.QuillIconTheme(iconButtonSelectedData: quill.IconButtonData(style: IconButton.styleFrom(backgroundColor: isSecondaryPanel ? theme.colorScheme.primary.withOpacity(0.1) : theme.colorScheme.primaryContainer, foregroundColor: theme.colorScheme.primary)), iconButtonUnselectedData: quill.IconButtonData(style: IconButton.styleFrom(foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7)))),
    );
  }

  quill.QuillToolbarColorButtonOptions _getColorButtonOptions(String tooltip, {IconData? iconData}) {
    final theme = Theme.of(context);
    return quill.QuillToolbarColorButtonOptions(tooltip: tooltip, iconData: iconData, iconTheme: quill.QuillIconTheme(iconButtonUnselectedData: quill.IconButtonData(style: IconButton.styleFrom(foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7)))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _saveNote(closePage: true);
      },
      child: Scaffold(
        backgroundColor: surfaceColor,
        appBar: AppBar(
          backgroundColor: surfaceColor,
          elevation: 0,
          leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurfaceVariant), onPressed: () => _saveNote(closePage: true)),
          actions: [
            if (_isDirty)
              Padding(padding: const EdgeInsets.only(right: 8.0), child: TextButton.icon(onPressed: () => _saveNote(closePage: false), icon: const Icon(Icons.save_rounded, size: 18), label: const Text("保存"), style: TextButton.styleFrom(foregroundColor: theme.colorScheme.primary))),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                          controller: _titleController,
                          focusNode: _titleFocusNode,
                          decoration: InputDecoration(hintText: '标题', hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5), fontSize: 24, fontWeight: FontWeight.bold), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold),
                          textInputAction: TextInputAction.next
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ActionChip(
                            avatar: Icon(_category == null ? Icons.folder_open_rounded : Icons.folder_rounded, size: 16, color: _category == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary),
                            label: Text(_category ?? '未分类'),
                            onPressed: _pickCategory,
                            backgroundColor: _category == null ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.primaryContainer.withOpacity(0.3),
                            labelStyle: TextStyle(fontSize: 12, color: _category == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary, fontWeight: _category == null ? FontWeight.normal : FontWeight.bold),
                            side: BorderSide.none, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                          ..._tags.map((tag) => InputChip(label: Text('#$tag'), onDeleted: () => _removeTag(tag), deleteIcon: const Icon(Icons.close_rounded, size: 14), visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, labelStyle: TextStyle(fontSize: 11, color: theme.colorScheme.secondary), backgroundColor: theme.colorScheme.secondaryContainer.withOpacity(0.3), side: BorderSide.none, shape: const StadiumBorder())),
                          ActionChip(label: const Icon(Icons.add_rounded, size: 16), onPressed: _showAddTagDialog, backgroundColor: theme.colorScheme.surfaceContainerHigh, side: BorderSide.none, shape: const CircleBorder(), padding: const EdgeInsets.all(4), visualDensity: VisualDensity.compact),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Divider(height: 1, color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                      Expanded(
                        child: quill.QuillEditor.basic(
                          controller: _quillController,
                          focusNode: _editorFocusNode,
                          config: quill.QuillEditorConfig(
                            placeholder: '开始记录...',
                            autoFocus: false,
                            expands: true,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            scrollable: true,
                            // 🟢 关键修复：注册外部的 ImageEmbedBuilder
                            embedBuilders: [
                              ImageEmbedBuilder(imageService: _imageService),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 🟢 完整保留的底部工具栏
              _buildBottomToolbar(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomToolbar(ThemeData theme) {
    final panelBgColor = theme.colorScheme.surfaceContainer;
    final iconColor = theme.colorScheme.onSurfaceVariant;
    final activeIconColor = theme.colorScheme.primary;
    const double toolbarIconSize = 24;

    return Container(
      decoration: BoxDecoration(
        color: panelBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
            child: _activePanel != _ToolbarPanel.none
                ? Container(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.15), width: 0.8)), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [panelBgColor.withOpacity(0.95), panelBgColor])),
              child: AnimatedSwitcher(duration: const Duration(milliseconds: 200), transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SizeTransition(sizeFactor: anim, child: child)), child: _buildActivePanelContent(theme)),
            )
                : const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _ToolbarIconButton(icon: Icons.undo_rounded, tooltip: '撤销', onPressed: _undo, isActive: false, activeColor: activeIconColor, inactiveColor: iconColor, iconSize: toolbarIconSize),
                        const SizedBox(width: 8),
                        _ToolbarIconButton(icon: Icons.redo_rounded, tooltip: '重做', onPressed: _redo, isActive: false, activeColor: activeIconColor, inactiveColor: iconColor, iconSize: toolbarIconSize),
                        Container(height: 20, width: 1, color: theme.colorScheme.outlineVariant.withOpacity(0.3), margin: const EdgeInsets.symmetric(horizontal: 12)),
                        _ToolbarIconButton(icon: Icons.text_fields_outlined, tooltip: '文本样式', isActive: _activePanel == _ToolbarPanel.textStyle, onPressed: () => _togglePanel(_ToolbarPanel.textStyle), activeColor: activeIconColor, inactiveColor: iconColor, iconSize: toolbarIconSize),
                        const SizedBox(width: 8),
                        _ToolbarIconButton(icon: Icons.text_snippet_outlined, tooltip: '段落样式', isActive: _activePanel == _ToolbarPanel.paragraphStyle, onPressed: () => _togglePanel(_ToolbarPanel.paragraphStyle), activeColor: activeIconColor, inactiveColor: iconColor, iconSize: toolbarIconSize),
                        const SizedBox(width: 8),
                        _ToolbarIconButton(icon: Icons.palette_outlined, tooltip: '颜色', isActive: _activePanel == _ToolbarPanel.color, onPressed: () => _togglePanel(_ToolbarPanel.color), activeColor: activeIconColor, inactiveColor: iconColor, iconSize: toolbarIconSize),
                        const SizedBox(width: 8),
                        _ToolbarIconButton(icon: Icons.insert_photo_outlined, tooltip: '插入图片', isActive: false, onPressed: _pickAndInsertImage, activeColor: activeIconColor, inactiveColor: iconColor, iconSize: toolbarIconSize),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: () => _saveNote(closePage: true),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), visualDensity: VisualDensity.compact, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('完成', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePanelContent(ThemeData theme) {
    switch (_activePanel) {
      case _ToolbarPanel.textStyle:
        return _buildPanelRow([
          quill.QuillToolbarToggleStyleButton(controller: _quillController, attribute: quill.Attribute.bold, options: _getToggleStyleOptions(Icons.format_bold_rounded, tooltip: '加粗')),
          quill.QuillToolbarToggleStyleButton(controller: _quillController, attribute: quill.Attribute.italic, options: _getToggleStyleOptions(Icons.format_italic_rounded, tooltip: '斜体')),
          quill.QuillToolbarToggleStyleButton(controller: _quillController, attribute: quill.Attribute.underline, options: _getToggleStyleOptions(Icons.format_underlined_rounded, tooltip: '下划线')),
          quill.QuillToolbarToggleStyleButton(controller: _quillController, attribute: quill.Attribute.strikeThrough, options: _getToggleStyleOptions(Icons.format_strikethrough_rounded, tooltip: '删除线')),
          quill.QuillToolbarToggleStyleButton(controller: _quillController, attribute: quill.Attribute.inlineCode, options: _getToggleStyleOptions(Icons.code_rounded, tooltip: '代码')),
        ]);
      case _ToolbarPanel.paragraphStyle:
        return _buildPanelRow([
          quill.QuillToolbarToggleStyleButton(controller: _quillController, attribute: quill.Attribute.h1, options: _getToggleStyleOptions(Icons.looks_one_rounded, tooltip: '标题 1')),
          quill.QuillToolbarToggleStyleButton(controller: _quillController, attribute: quill.Attribute.h2, options: _getToggleStyleOptions(Icons.looks_two_rounded, tooltip: '标题 2')),
          quill.QuillToolbarToggleStyleButton(controller: _quillController, attribute: quill.Attribute.ul, options: _getToggleStyleOptions(Icons.format_list_bulleted_rounded, tooltip: '无序列表')),
          quill.QuillToolbarToggleStyleButton(controller: _quillController, attribute: quill.Attribute.ol, options: _getToggleStyleOptions(Icons.format_list_numbered_rounded, tooltip: '有序列表')),
          quill.QuillToolbarToggleStyleButton(controller: _quillController, attribute: quill.Attribute.blockQuote, options: _getToggleStyleOptions(Icons.format_quote_rounded, tooltip: '引用')),
        ]);
      case _ToolbarPanel.color:
        return _buildPanelRow([
          Row(mainAxisSize: MainAxisSize.min, children: [const Text("A", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), quill.QuillToolbarColorButton(controller: _quillController, isBackground: false, options: _getColorButtonOptions('字体颜色', iconData: Icons.format_color_text_outlined))]),
          const SizedBox(width: 20),
          Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.highlight_rounded, size: 18), quill.QuillToolbarColorButton(controller: _quillController, isBackground: true, options: _getColorButtonOptions('背景高亮', iconData: Icons.format_color_fill_outlined))]),
          const SizedBox(width: 20),
          quill.QuillToolbarClearFormatButton(controller: _quillController, options: quill.QuillToolbarClearFormatButtonOptions(tooltip: '清除格式', iconData: Icons.format_clear_rounded, iconTheme: quill.QuillIconTheme(iconButtonUnselectedData: quill.IconButtonData(style: IconButton.styleFrom(foregroundColor: theme.colorScheme.onSurface))))),
        ]);
      case _ToolbarPanel.none: return const SizedBox.shrink();
    }
  }

  Widget _buildPanelRow(List<Widget> children) {
    return Container(key: ValueKey(_activePanel), height: 56, padding: const EdgeInsets.symmetric(horizontal: 16), alignment: Alignment.center, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: children)));
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;
  final Color activeColor;
  final Color inactiveColor;
  final String? tooltip;
  final double iconSize;

  const _ToolbarIconButton({required this.icon, required this.isActive, required this.onPressed, required this.activeColor, required this.inactiveColor, this.tooltip, this.iconSize = 24});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(color: isActive ? activeColor.withOpacity(0.12) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
      child: IconButton(onPressed: onPressed, icon: Icon(icon), tooltip: tooltip, color: isActive ? activeColor : inactiveColor, iconSize: iconSize, padding: const EdgeInsets.all(8), constraints: const BoxConstraints(minWidth: 44, minHeight: 44), style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap)),
    );
  }
}