import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/notes_provider.dart';
import '../../../../core/services/image_storage_service.dart';
import '../../../../models/note.dart';

// --- 图片构建器 (保持不变) ---
class _ImageEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final String imageUrl = embedContext.node.value.data;
    if (imageUrl.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 500, maxWidth: MediaQuery.of(context).size.width),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(imageUrl), fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 150, width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32), SizedBox(height: 8), Text('图片加载失败', style: TextStyle(color: Colors.grey))]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- 工具栏面板状态枚举 ---
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
  late TextEditingController _tagController;
  final FocusNode _editorFocusNode = FocusNode();
  final FocusNode _titleFocusNode = FocusNode();
  List<String> _tags = [];
  final ImageStorageService _imageService = ImageStorageService();

  _ToolbarPanel _activePanel = _ToolbarPanel.none;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _tagController = TextEditingController();
    _tags = widget.note?.tags.toList() ?? [];
    _initQuillController();

    // 监听焦点，失焦时收起面板
    _editorFocusNode.addListener(() {
      if (!_editorFocusNode.hasFocus && _activePanel != _ToolbarPanel.none) {
        // 延时一下，防止点击工具栏按钮时因为短暂失焦导致面板闪烁关闭
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_editorFocusNode.hasFocus) {
            // 只有当焦点真的不在编辑器且不在工具栏操作时才关闭
          }
        });
      }
    });
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
      final doc = quill.Document()..insert(0, widget.note?.content ?? '');
      _quillController = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
  }

  @override
  void dispose() {
    _quillController.dispose();
    _titleController.dispose();
    _tagController.dispose();
    _editorFocusNode.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickAndInsertImage() async {
    FocusScope.of(context).unfocus();
    setState(() => _activePanel = _ToolbarPanel.none);
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
    }
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
      setState(() {
        _tags.add(trimmed);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    if (title.isEmpty && _quillController.document.isEmpty()) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final contentJson = jsonEncode(_quillController.document.toDelta().toJson());
    final provider = Provider.of<NotesProvider>(context, listen: false);
    if (widget.note == null) {
      await provider.addNote(title: title.isEmpty ? '无标题' : title, content: contentJson, tags: _tags);
    } else {
      await provider.updateNote(widget.note!.copyWith(title: title, content: contentJson, tags: _tags, updatedAt: DateTime.now()));
    }
    if (mounted) Navigator.pop(context);
  }

  void _togglePanel(_ToolbarPanel panel) {
    setState(() {
      if (_activePanel == panel) {
        _activePanel = _ToolbarPanel.none;
      } else {
        _activePanel = panel;
        _editorFocusNode.requestFocus();
      }
    });
  }

  void _undo() {
    if (_quillController.hasUndo) {
      _quillController.undo();
      setState(() {});
    }
  }

  void _redo() {
    if (_quillController.hasRedo) {
      _quillController.redo();
      setState(() {});
    }
  }

  // --- 修复关键：辅助方法生成 Options，避免使用 copyWith ---
  quill.QuillToolbarToggleStyleButtonOptions _getToggleStyleOptions(
      IconData icon, {
        String? tooltip,
        double iconSize = 20, // 二级面板图标大小较小
        bool isSecondaryPanel = true, // 标记是否为二级面板
      }) {
    final theme = Theme.of(context);
    return quill.QuillToolbarToggleStyleButtonOptions(
      iconData: icon,
      iconSize: iconSize,
      tooltip: tooltip,
      iconTheme: quill.QuillIconTheme(
        iconButtonSelectedData: quill.IconButtonData(
          style: IconButton.styleFrom(
            backgroundColor: isSecondaryPanel
                ? theme.colorScheme.primary.withOpacity(0.1) // 二级面板用更浅的背景
                : theme.colorScheme.primaryContainer,
            foregroundColor: isSecondaryPanel
                ? theme.colorScheme.primary // 二级面板用主色
                : theme.colorScheme.primary,
          ),
        ),
        iconButtonUnselectedData: quill.IconButtonData(
          style: IconButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7), // 二级面板用稍浅的颜色
          ),
        ),
      ),
    );
  }

  quill.QuillToolbarColorButtonOptions _getColorButtonOptions(
      String tooltip, {
        IconData? iconData,
        double iconSize = 20, // 减小颜色按钮图标大小
      }) {
    final theme = Theme.of(context);
    return quill.QuillToolbarColorButtonOptions(
      tooltip: tooltip,
      iconSize: iconSize,
      iconData: iconData,
      iconTheme: quill.QuillIconTheme(
        iconButtonUnselectedData: quill.IconButtonData(
          style: IconButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7), // 二级面板用稍浅的颜色
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurfaceVariant),
          onPressed: () => Navigator.pop(context),
        ),
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
                      decoration: InputDecoration(
                        hintText: '标题',
                        hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5), fontSize: 24, fontWeight: FontWeight.bold),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [..._tags.map((tag) => Padding(padding: const EdgeInsets.only(right: 8), child: Chip(label: Text(tag, style: const TextStyle(fontSize: 11)), onDeleted: () => _removeTag(tag), visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, labelPadding: const EdgeInsets.symmetric(horizontal: 8), backgroundColor: theme.colorScheme.surfaceContainerHigh, side: BorderSide.none, shape: const StadiumBorder()))), SizedBox(width: 60, child: TextField(controller: _tagController, decoration: InputDecoration(hintText: '+标签', hintStyle: TextStyle(fontSize: 12, color: theme.colorScheme.primary), border: InputBorder.none, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8)), style: TextStyle(fontSize: 12, color: theme.colorScheme.primary), onSubmitted: _addTag))]),
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
                          embedBuilders: [_ImageEmbedBuilder()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- 底部工具栏 ---
            _buildBottomToolbar(theme),
          ],
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
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2)
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 弹出面板层 - 优化分割线
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
            child: _activePanel != _ToolbarPanel.none
                ? Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.15), // 更浅的分割线
                    width: 0.8, // 更细的线条
                  ),
                ),
                gradient: LinearGradient( // 添加渐变背景
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    panelBgColor.withOpacity(0.95),
                    panelBgColor,
                  ],
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SizeTransition(
                    sizeFactor: anim,
                    child: child,
                  ),
                ),
                child: _buildActivePanelContent(theme),
              ),
            )
                : const SizedBox.shrink(),
          ),

          // 2. 主工具栏层
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), // 增加垂直内边距
            child: Row(
              children: [
                // 左侧功能图标区
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // 撤销
                        _ToolbarIconButton(
                          icon: Icons.undo_rounded,
                          tooltip: '撤销',
                          onPressed: _undo,
                          isActive: false,
                          activeColor: activeIconColor,
                          inactiveColor: iconColor,
                          iconSize: toolbarIconSize,
                        ),
                        const SizedBox(width: 8),
                        // 重做
                        _ToolbarIconButton(
                          icon: Icons.redo_rounded,
                          tooltip: '重做',
                          onPressed: _redo,
                          isActive: false,
                          activeColor: activeIconColor,
                          inactiveColor: iconColor,
                          iconSize: toolbarIconSize,
                        ),
                        Container(
                            height: 20,
                            width: 1,
                            color: theme.colorScheme.outlineVariant.withOpacity(0.3), // 更浅的分割线
                            margin: const EdgeInsets.symmetric(horizontal: 12)
                        ),

                        // 样式面板 (Aa)
                        _ToolbarIconButton(
                          icon: Icons.text_fields_outlined,
                          tooltip: '文本样式',
                          isActive: _activePanel == _ToolbarPanel.textStyle,
                          onPressed: () => _togglePanel(_ToolbarPanel.textStyle),
                          activeColor: activeIconColor,
                          inactiveColor: iconColor,
                          iconSize: toolbarIconSize,
                        ),
                        const SizedBox(width: 8),
                        // 段落面板
                        _ToolbarIconButton(
                          icon: Icons.text_snippet_outlined,
                          tooltip: '段落样式',
                          isActive: _activePanel == _ToolbarPanel.paragraphStyle,
                          onPressed: () => _togglePanel(_ToolbarPanel.paragraphStyle),
                          activeColor: activeIconColor,
                          inactiveColor: iconColor,
                          iconSize: toolbarIconSize,
                        ),
                        const SizedBox(width: 8),
                        // 颜色面板 (集成)
                        _ToolbarIconButton(
                          icon: Icons.palette_outlined,
                          tooltip: '颜色',
                          isActive: _activePanel == _ToolbarPanel.color,
                          onPressed: () => _togglePanel(_ToolbarPanel.color),
                          activeColor: activeIconColor,
                          inactiveColor: iconColor,
                          iconSize: toolbarIconSize,
                        ),
                        const SizedBox(width: 8),
                        // 插入图片
                        _ToolbarIconButton(
                          icon: Icons.insert_photo_outlined,
                          tooltip: '插入图片',
                          isActive: false,
                          onPressed: _pickAndInsertImage,
                          activeColor: activeIconColor,
                          inactiveColor: iconColor,
                          iconSize: toolbarIconSize,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: _saveNote,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('完成', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建面板内容 (使用优化图标和大小)
  Widget _buildActivePanelContent(ThemeData theme) {
    switch (_activePanel) {
      case _ToolbarPanel.textStyle:
        return _buildPanelRow([
          quill.QuillToolbarToggleStyleButton(
            controller: _quillController,
            attribute: quill.Attribute.bold,
            options: _getToggleStyleOptions(
              Icons.format_bold_outlined,
              tooltip: '粗体',
              iconSize: 20,
              isSecondaryPanel: true,
            ),
          ),
          quill.QuillToolbarToggleStyleButton(
            controller: _quillController,
            attribute: quill.Attribute.italic,
            options: _getToggleStyleOptions(
              Icons.format_italic_outlined,
              tooltip: '斜体',
              iconSize: 20,
              isSecondaryPanel: true,
            ),
          ),
          quill.QuillToolbarToggleStyleButton(
            controller: _quillController,
            attribute: quill.Attribute.underline,
            options: _getToggleStyleOptions(
              Icons.format_underline_outlined,
              tooltip: '下划线',
              iconSize: 20,
              isSecondaryPanel: true,
            ),
          ),
          quill.QuillToolbarToggleStyleButton(
            controller: _quillController,
            attribute: quill.Attribute.strikeThrough,
            options: _getToggleStyleOptions(
              Icons.strikethrough_s_outlined,
              tooltip: '删除线',
              iconSize: 20,
              isSecondaryPanel: true,
            ),
          ),
          quill.QuillToolbarToggleStyleButton(
            controller: _quillController,
            attribute: quill.Attribute.inlineCode,
            options: _getToggleStyleOptions(
              Icons.code_outlined,
              tooltip: '行内代码',
              iconSize: 20,
              isSecondaryPanel: true,
            ),
          ),
        ]);

      case _ToolbarPanel.paragraphStyle:
        return _buildPanelRow([
          quill.QuillToolbarToggleStyleButton(
            controller: _quillController,
            attribute: quill.Attribute.h1,
            options: _getToggleStyleOptions(
              Icons.title_outlined,
              tooltip: '标题 1',
              iconSize: 20,
              isSecondaryPanel: true,
            ),
          ),
          quill.QuillToolbarToggleStyleButton(
            controller: _quillController,
            attribute: quill.Attribute.h2,
            options: _getToggleStyleOptions(
              Icons.text_fields_outlined,
              tooltip: '标题 2',
              iconSize: 20,
              isSecondaryPanel: true,
            ),
          ),
          quill.QuillToolbarToggleStyleButton(
            controller: _quillController,
            attribute: quill.Attribute.ul,
            options: _getToggleStyleOptions(
              Icons.list_outlined,
              tooltip: '无序列表',
              iconSize: 20,
              isSecondaryPanel: true,
            ),
          ),
          quill.QuillToolbarToggleStyleButton(
            controller: _quillController,
            attribute: quill.Attribute.ol,
            options: _getToggleStyleOptions(
              Icons.format_list_numbered_outlined,
              tooltip: '有序列表',
              iconSize: 20,
              isSecondaryPanel: true,
            ),
          ),
          quill.QuillToolbarToggleStyleButton(
            controller: _quillController,
            attribute: quill.Attribute.blockQuote,
            options: _getToggleStyleOptions(
              Icons.format_quote_outlined,
              tooltip: '引用',
              iconSize: 20,
              isSecondaryPanel: true,
            ),
          ),
        ]);

      case _ToolbarPanel.color:
        return _buildPanelRow([
          // 字体颜色
          quill.QuillToolbarColorButton(
            controller: _quillController,
            isBackground: false,
            options: _getColorButtonOptions(
              '字体颜色',
              iconData: Icons.format_color_text_outlined,
              iconSize: 20,
            ),
          ),
          const SizedBox(width: 20),
          // 背景高亮
          quill.QuillToolbarColorButton(
            controller: _quillController,
            isBackground: true,
            options: _getColorButtonOptions(
              '背景高亮',
              iconData: Icons.format_color_fill_outlined,
              iconSize: 20,
            ),
          ),
          const SizedBox(width: 20),
          // 清除格式
          quill.QuillToolbarClearFormatButton(
            controller: _quillController,
            options: quill.QuillToolbarClearFormatButtonOptions(
              iconData: Icons.format_clear_outlined,
              iconSize: 20,
              iconTheme: quill.QuillIconTheme(
                iconButtonUnselectedData: quill.IconButtonData(
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ),
        ]);

      case _ToolbarPanel.none:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPanelRow(List<Widget> children) {
    return Container(
      key: ValueKey(_activePanel),
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: children),
      ),
    );
  }
}

// 自定义主工具栏图标按钮
class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;
  final Color activeColor;
  final Color inactiveColor;
  final String? tooltip;
  final double iconSize;

  const _ToolbarIconButton({
    required this.icon,
    required this.isActive,
    required this.onPressed,
    required this.activeColor,
    required this.inactiveColor,
    this.tooltip,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isActive ? activeColor.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        tooltip: tooltip,
        color: isActive ? activeColor : inactiveColor,
        iconSize: iconSize,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ),
    );
  }
}