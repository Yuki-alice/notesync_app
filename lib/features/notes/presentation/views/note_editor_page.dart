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

  void _toggleImageWidth(quill.QuillController controller, quill.Embed node, bool enableFullWidth) {
    final offset = getEmbedNodeOffset(controller, node);
    if (offset != -1) {
      final String imageUrl = node.value.data;

      controller.document.delete(offset, 1);
      controller.document.insert(offset, quill.BlockEmbed.image(imageUrl));

      if (enableFullWidth) {
        controller.formatText(
            offset,
            1,
            quill.Attribute('width', quill.AttributeScope.inline, '100%')
        );
      }

      Future.delayed(Duration.zero, () {
        controller.updateSelection(
            TextSelection.collapsed(offset: offset + 1),
            quill.ChangeSource.local
        );
      });
    }
  }

  void _addCaption(quill.QuillController controller, quill.Embed node) {
    final offset = getEmbedNodeOffset(controller, node);
    if (offset != -1) {
      final index = offset + 1;
      const captionText = '在此添加题注';
      controller.document.insert(index, '\n$captionText');

      final textStart = index + 1;
      final textLength = captionText.length;

      controller.formatText(textStart, textLength, quill.Attribute.small);
      controller.formatText(textStart, textLength, quill.Attribute.centerAlignment);
      controller.formatText(
          textStart,
          textLength,
          quill.Attribute('color', quill.AttributeScope.inline, '#2F4F4F')
      );

      Future.delayed(Duration.zero, () {
        controller.updateSelection(
            TextSelection(baseOffset: textStart, extentOffset: textStart + textLength),
            quill.ChangeSource.local
        );
      });
    }
  }

  void _deleteImage(quill.QuillController controller, quill.Embed node) {
    final offset = getEmbedNodeOffset(controller, node);
    if (offset != -1) {
      controller.replaceText(offset, 1, '', const TextSelection.collapsed(offset: 0));
      if (offset < controller.document.length && controller.document.toPlainText()[offset] == '\n') {
        controller.replaceText(offset, 1, '', const TextSelection.collapsed(offset: 0));
      }
    }
  }

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
  final FocusNode _editorFocusNode = FocusNode();
  final FocusNode _titleFocusNode = FocusNode();
  List<String> _tags = [];
  String? _category;
  final ImageStorageService _imageService = ImageStorageService();

  _ToolbarPanel _activePanel = _ToolbarPanel.none;

  // 🟢 标记内容是否发生变更
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
          if (mounted && !_editorFocusNode.hasFocus) {}
        });
      }
    });

    // 🟢 监听标题变化
    _titleController.addListener(_markAsDirty);

    // 🟢 监听 Quill 内容变化 (修复了 item3 报错)
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
      _markAsDirty(); // 插入图片也是修改
    }
  }

  void _showAddTagDialog() {
    final theme = Theme.of(context);
    String tempTag = '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加标签'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入标签名称 (例如: 重要)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.tag_rounded),
          ),
          onChanged: (v) => tempTag = v,
          onSubmitted: (v) {
            _commitTag(v);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              _commitTag(tempTag);
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _commitTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
      setState(() {
        _tags.add(trimmed);
        _isDirty = true; // 标签变化也是修改
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _isDirty = true; // 标签变化也是修改
    });
  }

  // 🟢 保存逻辑，支持仅保存或保存并退出
  Future<void> _saveNote({bool closePage = false}) async {
    // 只有当有内容变动或它是新笔记时才保存
    // 如果没有变动且是现有笔记，直接根据 closePage 决定是否退出
    if (!_isDirty && widget.note != null) {
      if (closePage && mounted) Navigator.pop(context);
      return;
    }

    final title = _titleController.text.trim();

    // 如果是空笔记（无标题且无内容），不创建新记录，直接退出
    if (title.isEmpty && _quillController.document.isEmpty()) {
      if (closePage && mounted) Navigator.pop(context);
      return;
    }

    final contentJson = jsonEncode(_quillController.document.toDelta().toJson());
    final provider = Provider.of<NotesProvider>(context, listen: false);

    if (widget.note == null) {
      // 新增笔记
      await provider.addNote(
        title: title.isEmpty ? '未命名笔记' : title,
        content: contentJson,
        tags: _tags,
        category: _category,
      );
    } else {
      // 更新笔记
      await provider.updateNote(widget.note!.copyWith(
          title: title,
          content: contentJson,
          tags: _tags,
          category: _category,
          updatedAt: DateTime.now()
      ));
    }

    // 保存成功，重置脏状态
    _isDirty = false;

    // 强制刷新界面以更新“已保存”状态（如果有 UI 指示器）
    if (mounted) setState(() {});

    if (closePage && mounted) Navigator.pop(context);
  }

  void _pickCategory() async {
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final categories = provider.categories;
    final theme = Theme.of(context);
    final textController = TextEditingController();

    final String? selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true, // 允许弹窗随键盘高度调整
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, // 键盘避让
          left: 24,
          right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '设置分类',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // 1. 输入框
            TextField(
              controller: textController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '输入新分类...',
                prefixIcon: const Icon(Icons.create_new_folder_outlined),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                // 后缀确认按钮
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_circle_rounded),
                  color: theme.colorScheme.primary,
                  onPressed: () => Navigator.pop(ctx, textController.text.trim()),
                ),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),

            const SizedBox(height: 24),

            // 2. 现有分类 (流式布局)
            if (categories.isNotEmpty) ...[
              Text(
                '选择已有分类',
                style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // "无分类" 选项
                      ActionChip(
                        avatar: const Icon(Icons.folder_off_outlined, size: 18),
                        label: const Text('无分类'),
                        onPressed: () => Navigator.pop(ctx, ''), // 返回空字符串表示清除
                        backgroundColor: theme.colorScheme.surfaceContainer,
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                        shape: const StadiumBorder(),
                      ),
                      // 动态分类
                      ...categories.map((category) {
                        final isSelected = _category == category;
                        return FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (_) => Navigator.pop(ctx, category),
                          checkmarkColor: theme.colorScheme.onSecondaryContainer,
                          selectedColor: theme.colorScheme.secondaryContainer,
                          backgroundColor: theme.colorScheme.surfaceContainerHigh,
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? theme.colorScheme.onSecondaryContainer
                                : theme.colorScheme.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    // 处理结果
    if (selected != null) {
      setState(() {
        _category = selected.isEmpty ? null : selected;
        _isDirty = true; // 分类变化也是修改
      });
    }
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

    // 🟢 核心修改：使用 PopScope 拦截系统返回（如侧滑手势或物理按键）
    return PopScope(
      canPop: false, // 禁止直接退出
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // 触发退出保存逻辑
        await _saveNote(closePage: true);
      },
      child: Scaffold(
        backgroundColor: surfaceColor,
        appBar: AppBar(
          backgroundColor: surfaceColor,
          scrolledUnderElevation: 0,
          elevation: 0,
          // 🟢 自定义左上角返回按钮
          leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurfaceVariant),
              // 点击返回时保存并退出
              onPressed: () => _saveNote(closePage: true)
          ),
          actions: [
            // 🟢 可选：手动保存按钮（仅当有未保存修改时显示）
            if (_isDirty)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton.icon(
                  onPressed: () => _saveNote(closePage: false),
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text("保存"),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                  ),
                ),
              ),
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

                      // 🔴 美化后的头部信息栏：分类 + 标签流
                      Wrap(
                        spacing: 8, // 水平间距
                        runSpacing: 8, // 垂直间距 (多行时)
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // 1. 分类胶囊 (保持不变)
                          ActionChip(
                            avatar: Icon(
                              _category == null ? Icons.folder_open_rounded : Icons.folder_rounded,
                              size: 16,
                              color: _category == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary,
                            ),
                            label: Text(_category ?? '未分类'),
                            onPressed: _pickCategory,
                            backgroundColor: _category == null ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.primaryContainer.withOpacity(0.3),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: _category == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary,
                              fontWeight: _category == null ? FontWeight.normal : FontWeight.bold,
                            ),
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),

                          // 2. 现有标签列表 (带删除功能的胶囊)
                          ..._tags.map((tag) => InputChip(
                            label: Text('#$tag'),
                            onDeleted: () => _removeTag(tag),
                            deleteIcon: const Icon(Icons.close_rounded, size: 14),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            labelStyle: TextStyle(fontSize: 11, color: theme.colorScheme.secondary),
                            backgroundColor: theme.colorScheme.secondaryContainer.withOpacity(0.3),
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                          )),

                          // 3. 添加标签按钮 (小加号)
                          ActionChip(
                            label: const Icon(Icons.add_rounded, size: 16),
                            onPressed: _showAddTagDialog, // 点击弹窗
                            backgroundColor: theme.colorScheme.surfaceContainerHigh, // 灰色背景
                            side: BorderSide.none,
                            shape: const CircleBorder(), // 圆形按钮
                            padding: const EdgeInsets.all(4), // 紧凑内边距
                            visualDensity: VisualDensity.compact,
                          ),
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
                            embedBuilders: [_ImageEmbedBuilder()],
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
                  // 🟢 点击完成时，执行保存并退出
                  onPressed: () => _saveNote(closePage: true),
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