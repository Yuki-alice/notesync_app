import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/notes_provider.dart';
import '../../../../core/services/image_storage_service.dart';
import '../../../../models/note.dart';

// --- 1. 悬浮菜单管理器 ---
class OverlayMenuManager {
  static OverlayEntry? _currentEntry;

  static void show({
    required BuildContext context,
    required LayerLink layerLink,
    required VoidCallback onDismiss,
    required Widget child,
  }) {
    hide();

    final overlayState = Overlay.of(context);

    _currentEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (_) {
                hide();
                onDismiss();
              },
              onPanStart: (_) {
                hide();
                onDismiss();
              },
              child: Container(color: Colors.transparent),
            ),
          ),
          CompositedTransformFollower(
            link: layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 12),
            targetAnchor: Alignment.bottomCenter,
            followerAnchor: Alignment.topCenter,
            child: Material(
              type: MaterialType.transparency,
              child: child,
            ),
          ),
        ],
      ),
    );

    overlayState.insert(_currentEntry!);
  }

  static void hide() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

// --- 2. 可交互图片组件 ---
class InteractableImage extends StatefulWidget {
  final String imageUrl;
  final bool isFullWidth;
  final quill.QuillController controller;
  final quill.Embed node;
  final Function(bool) onWidthToggle;
  final VoidCallback onAddCaption;
  final VoidCallback onDelete;

  const InteractableImage({
    super.key,
    required this.imageUrl,
    required this.isFullWidth,
    required this.controller,
    required this.node,
    required this.onWidthToggle,
    required this.onAddCaption,
    required this.onDelete,
  });

  @override
  State<InteractableImage> createState() => _InteractableImageState();
}

class _InteractableImageState extends State<InteractableImage> {
  final LayerLink _layerLink = LayerLink();

  void _handleTap() {
    FocusScope.of(context).unfocus();
    // 延时一小段时间，确保 UI 稳定后再显示菜单
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _showFloatingToolbar();
    });
  }

  void _showFloatingToolbar() {
    OverlayMenuManager.show(
      context: context,
      layerLink: _layerLink,
      onDismiss: () {},
      child: _FloatingToolbar(
        isFullWidth: widget.isFullWidth,
        onToggleWidth: () {
          OverlayMenuManager.hide();
          widget.onWidthToggle(!widget.isFullWidth);
        },
        onAddCaption: () {
          OverlayMenuManager.hide();
          widget.onAddCaption();
        },
        onDelete: () {
          OverlayMenuManager.hide();
          widget.onDelete();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: widget.isFullWidth ? 16.0 : 8.0),
          width: widget.isFullWidth ? double.infinity : null,
          alignment: Alignment.center,
          child: widget.isFullWidth
              ? _buildFullWidthImage()
              : _buildConstrainedImage(),
        ),
      ),
    );
  }

  Widget _buildFullWidthImage() {
    return Image.file(
      File(widget.imageUrl),
      fit: BoxFit.fitWidth,
      width: double.infinity,
      errorBuilder: _buildErrorWidget,
    );
  }

  Widget _buildConstrainedImage() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: 450,
        maxWidth: MediaQuery.of(context).size.width * 0.9,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(widget.imageUrl),
          fit: BoxFit.contain,
          errorBuilder: _buildErrorWidget,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, Object error, StackTrace? stackTrace) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
          SizedBox(height: 8),
          Text('图片加载失败', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

// --- 3. 图片构建器 ---
class _ImageEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final String imageUrl = embedContext.node.value.data;
    if (imageUrl.isEmpty) return const SizedBox();

    final isFullWidth = embedContext.node.style.attributes['width']?.value == '100%';

    return InteractableImage(
      imageUrl: imageUrl,
      isFullWidth: isFullWidth,
      controller: embedContext.controller,
      node: embedContext.node,
      onWidthToggle: (newValue) => _toggleImageWidth(embedContext.controller, embedContext.node, newValue),
      onAddCaption: () => _addCaption(embedContext.controller, embedContext.node),
      onDelete: () => _deleteImage(embedContext.controller, embedContext.node),
    );
  }

  // 🔴 关键修复：使用“删除+重新插入”策略，彻底解决属性不可修改的问题
  // 🔴 修复版：切换宽度 (分步操作，兼容性最强)
  void _toggleImageWidth(quill.QuillController controller, quill.Embed node, bool enableFullWidth) {
    final offset = getEmbedNodeOffset(controller, node);
    if (offset != -1) {
      final String imageUrl = node.value.data;

      // 1. 删除旧节点
      controller.document.delete(offset, 1);

      // 2. 插入新节点 (insert 只有两个参数：位置和数据)
      controller.document.insert(offset, quill.BlockEmbed.image(imageUrl));

      // 3. 应用样式 (如果是满宽)
      if (enableFullWidth) {
        // 使用 AttributeScope.inline，这通常是图片等行内元素样式的正确作用域
        // 这样可以避免 "Apply delta rules failed" 错误
        controller.formatText(
            offset,
            1,
            quill.Attribute('width', quill.AttributeScope.inline, '100%')
        );
      }

      // 4. 强制刷新 UI
      // 延时一帧确保 Quill 内部状态更新完毕
      Future.delayed(Duration.zero, () {
        controller.updateSelection(
            TextSelection.collapsed(offset: offset + 1),
            quill.ChangeSource.local
        );
      });
    }
  }

  // 🔴 稳健性修复：添加描述
  void _addCaption(quill.QuillController controller, quill.Embed node) {
    final offset = getEmbedNodeOffset(controller, node);
    if (offset != -1) {
      final index = offset + 1;
      // 1. 插入题注文本
      const captionText = '在此添加题注';
      controller.document.insert(index, '\n$captionText');

      // 2. 准备样式范围 (跳过换行符，只选中文字)
      final textStart = index + 1;
      final textLength = captionText.length;

      // 3. 应用样式
      // 小号字体
      controller.formatText(textStart, textLength, quill.Attribute.small);
      // 居中对齐 (作用于整行)
      controller.formatText(textStart, textLength, quill.Attribute.centerAlignment);
      // 灰色文字 (视觉优化)
      controller.formatText(
          textStart,
          textLength,
          quill.Attribute('color', quill.AttributeScope.inline, '#2F4F4F')
      );

      // 4. 选中文字方便直接修改
      Future.delayed(Duration.zero, () {
        controller.updateSelection(
            TextSelection(baseOffset: textStart, extentOffset: textStart + textLength),
            quill.ChangeSource.local
        );
      });
    }
  }

  // 删除图片
  void _deleteImage(quill.QuillController controller, quill.Embed node) {
    final offset = getEmbedNodeOffset(controller, node);
    if (offset != -1) {
      controller.replaceText(offset, 1, '', const TextSelection.collapsed(offset: 0));
      // 清理残留换行
      if (offset < controller.document.length && controller.document.toPlainText()[offset] == '\n') {
        controller.replaceText(offset, 1, '', const TextSelection.collapsed(offset: 0));
      }
    }
  }

  // 节点查找辅助函数
  int getEmbedNodeOffset(quill.QuillController controller, quill.Embed node) {
    var offset = 0;
    for (final child in controller.document.root.children) {
      if (child == node) return offset;
      if (child is quill.Line) {
        for (final leaf in child.children) {
          if (leaf == node) return offset + leaf.offset;
        }
      }
      offset += child.length;
    }
    // 降级查找
    final docLength = controller.document.length;
    for (var i = 0; i < docLength - 1; i++) {
      final data = controller.document.queryChild(i);
      if (data.node == node) return i;
    }
    return -1;
  }
}

// --- 4. 悬浮工具栏 UI ---
class _FloatingToolbar extends StatefulWidget {
  final bool isFullWidth;
  final VoidCallback onToggleWidth;
  final VoidCallback onAddCaption;
  final VoidCallback onDelete;

  const _FloatingToolbar({
    required this.isFullWidth,
    required this.onToggleWidth,
    required this.onAddCaption,
    required this.onDelete,
  });

  @override
  State<_FloatingToolbar> createState() => _FloatingToolbarState();
}

class _FloatingToolbarState extends State<_FloatingToolbar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: Alignment.topCenter,
        child: Container(
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 4)),
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 1)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 4),
              _buildIconBtn(
                icon: widget.isFullWidth ? Icons.photo_size_select_small_rounded : Icons.fit_screen_rounded,
                tooltip: widget.isFullWidth ? '还原尺寸' : '适应屏幕',
                onTap: widget.onToggleWidth,
              ),
              _buildDivider(),
              _buildIconBtn(
                icon: Icons.edit_note_rounded,
                tooltip: '添加描述',
                onTap: widget.onAddCaption,
              ),
              _buildDivider(),
              _buildIconBtn(
                icon: Icons.delete_outline_rounded,
                tooltip: '删除图片',
                onTap: widget.onDelete,
                isDestructive: true,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconBtn({required IconData icon, required VoidCallback onTap, String? tooltip, bool isDestructive = false}) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Icon(icon, size: 20, color: isDestructive ? Colors.redAccent : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 16, color: Colors.grey.withOpacity(0.2));
  }
}

// --- 5. 编辑器主页面 ---
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

    // 监听：失去焦点时处理
    _editorFocusNode.addListener(() {
      if (!_editorFocusNode.hasFocus && _activePanel != _ToolbarPanel.none) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted && !_editorFocusNode.hasFocus) {
            // 失去焦点
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
    OverlayMenuManager.hide();
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

  quill.QuillToolbarToggleStyleButtonOptions _getToggleStyleOptions(
      IconData icon, {
        String? tooltip,
        double iconSize = 20,
        bool isSecondaryPanel = true,
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
                ? theme.colorScheme.primary.withOpacity(0.1)
                : theme.colorScheme.primaryContainer,
            foregroundColor: isSecondaryPanel
                ? theme.colorScheme.primary
                : theme.colorScheme.primary,
          ),
        ),
        iconButtonUnselectedData: quill.IconButtonData(
          style: IconButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ),
    );
  }

  quill.QuillToolbarColorButtonOptions _getColorButtonOptions(
      String tooltip, {
        IconData? iconData,
        double iconSize = 20,
      }) {
    final theme = Theme.of(context);
    return quill.QuillToolbarColorButtonOptions(
      tooltip: tooltip,
      iconSize: iconSize,
      iconData: iconData,
      iconTheme: quill.QuillIconTheme(
        iconButtonUnselectedData: quill.IconButtonData(
          style: IconButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface.withOpacity(0.7),
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
                          scrollable: true,
                          // 注册构建器
                          embedBuilders: [
                            _ImageEmbedBuilder(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
            child: _activePanel != _ToolbarPanel.none
                ? Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.15),
                    width: 0.8,
                  ),
                ),
                gradient: LinearGradient(
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
                transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SizeTransition(sizeFactor: anim, child: child)),
                child: _buildActivePanelContent(theme),
              ),
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
                            color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                            margin: const EdgeInsets.symmetric(horizontal: 12)
                        ),
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

  Widget _buildActivePanelContent(ThemeData theme) {
    switch (_activePanel) {
      case _ToolbarPanel.textStyle:
        return _buildPanelRow([
          quill.QuillToolbarToggleStyleButton(
            controller: _quillController,
            attribute: quill.Attribute.bold,
            options: _getToggleStyleOptions(Icons.format_bold_rounded, tooltip: '加粗'),
          ),
          quill.QuillToolbarToggleStyleButton(
            controller: _quillController,
            attribute: quill.Attribute.italic,
            options: _getToggleStyleOptions(Icons.format_italic_rounded, tooltip: '斜体'),
          ),
          quill.QuillToolbarToggleStyleButton(
            controller: _quillController,
            attribute: quill.Attribute.underline,
            options: _getToggleStyleOptions(Icons.format_underlined_rounded, tooltip: '下划线'),
          ),
          quill.QuillToolbarToggleStyleButton(
            controller: _quillController,
            attribute: quill.Attribute.strikeThrough,
            options: _getToggleStyleOptions(Icons.format_strikethrough_rounded, tooltip: '删除线'),
          ),
          quill.QuillToolbarToggleStyleButton(
            controller: _quillController,
            attribute: quill.Attribute.inlineCode,
            options: _getToggleStyleOptions(Icons.code_rounded, tooltip: '代码'),
          ),
        ]);

      case _ToolbarPanel.paragraphStyle:
        return _buildPanelRow([
          quill.QuillToolbarToggleStyleButton(
            controller: _quillController,
            attribute: quill.Attribute.h1,
            options: _getToggleStyleOptions(Icons.looks_one_rounded, tooltip: '标题 1'),
          ),
          quill.QuillToolbarToggleStyleButton(
            controller: _quillController,
            attribute: quill.Attribute.h2,
            options: _getToggleStyleOptions(Icons.looks_two_rounded, tooltip: '标题 2'),
          ),
          quill.QuillToolbarToggleStyleButton(
            controller: _quillController,
            attribute: quill.Attribute.ul,
            options: _getToggleStyleOptions(Icons.format_list_bulleted_rounded, tooltip: '无序列表'),
          ),
          quill.QuillToolbarToggleStyleButton(
            controller: _quillController,
            attribute: quill.Attribute.ol,
            options: _getToggleStyleOptions(Icons.format_list_numbered_rounded, tooltip: '有序列表'),
          ),
          quill.QuillToolbarToggleStyleButton(
            controller: _quillController,
            attribute: quill.Attribute.blockQuote,
            options: _getToggleStyleOptions(Icons.format_quote_rounded, tooltip: '引用'),
          ),
        ]);

      case _ToolbarPanel.color:
        return _buildPanelRow([
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("A", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              quill.QuillToolbarColorButton(
                controller: _quillController,
                isBackground: false,
                options: _getColorButtonOptions('字体颜色', iconData: Icons.format_color_text_outlined),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.highlight_rounded, size: 18),
              quill.QuillToolbarColorButton(
                controller: _quillController,
                isBackground: true,
                options: _getColorButtonOptions('背景高亮', iconData: Icons.format_color_fill_outlined),
              ),
            ],
          ),
          const SizedBox(width: 20),
          quill.QuillToolbarClearFormatButton(
            controller: _quillController,
            options: quill.QuillToolbarClearFormatButtonOptions(
              tooltip: '清除格式',
              iconData: Icons.format_clear_rounded,
              iconTheme: quill.QuillIconTheme(
                iconButtonUnselectedData: quill.IconButtonData(
                  style: IconButton.styleFrom(foregroundColor: theme.colorScheme.onSurface),
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