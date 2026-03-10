// 文件路径: lib/features/notes/presentation/widgets/note_image_embed.dart
import 'dart:async'; // 引入 async
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../../core/services/image_storage_service.dart';

class ImageEmbedBuilder extends quill.EmbedBuilder {
  final ImageStorageService imageService;
  final ValueChanged<bool>? onSelectionChange;

  ImageEmbedBuilder({
    required this.imageService,
    this.onSelectionChange,
  });

  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final String path = embedContext.node.value.data;
    if (path.isEmpty) return const SizedBox();

    final isFullWidth = embedContext.node.style.attributes['width']?.value == '100%';
    final String? caption = embedContext.node.style.attributes['caption']?.value;

    return FutureBuilder<File?>(
      future: imageService.getLocalFile(path),
      builder: (context, snapshot) {
        return InteractableImage(
          imageFile: snapshot.data,
          path: path,
          isFullWidth: isFullWidth,
          caption: caption,
          controller: embedContext.controller,
          node: embedContext.node,
          onSelectionChange: onSelectionChange,
          onWidthToggle: (newValue) => _updateAttribute(embedContext.controller, embedContext.node, 'width', newValue ? '100%' : null),
          onCaptionChange: (newCaption) => _updateAttribute(embedContext.controller, embedContext.node, 'caption', newCaption),
          onDelete: () => _deleteImage(embedContext.controller, embedContext.node),
        );
      },
    );
  }

  void _updateAttribute(quill.QuillController controller, quill.Embed node, String key, dynamic value) {
    final offset = getEmbedNodeOffset(controller, node);
    if (offset != -1) {
      controller.formatText(offset, 1, quill.Attribute(key, quill.AttributeScope.inline, value));
    }
  }

  void _deleteImage(quill.QuillController controller, quill.Embed node) {
    final offset = getEmbedNodeOffset(controller, node);
    if (offset != -1) {
      controller.replaceText(offset, 1, '', const TextSelection.collapsed(offset: 0));
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
    return -1;
  }
}

// --- 2. 可交互图片组件 UI ---
class InteractableImage extends StatefulWidget {
  final File? imageFile;
  final String path;
  final bool isFullWidth;
  final String? caption;
  final quill.QuillController controller;
  final quill.Embed node;
  final Function(bool) onWidthToggle;
  final Function(String?) onCaptionChange;
  final VoidCallback onDelete;
  final ValueChanged<bool>? onSelectionChange;

  const InteractableImage({
    super.key,
    required this.imageFile,
    required this.path,
    required this.isFullWidth,
    this.caption,
    required this.controller,
    required this.node,
    required this.onWidthToggle,
    required this.onCaptionChange,
    required this.onDelete,
    this.onSelectionChange,
  });

  @override
  State<InteractableImage> createState() => _InteractableImageState();
}

class _InteractableImageState extends State<InteractableImage> {
  final LayerLink _layerLink = LayerLink();
  bool _isSelected = false;

  @override
  void dispose() {
    if (_isSelected) {
      OverlayMenuManager.hide();
    }
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (_isSelected) {
      _resetSelection();
      return;
    }

    setState(() => _isSelected = true);

    // 🟢 核心修复：使用 Future.delayed(Duration.zero)
    // 将“通知父级”的操作推迟到下一个事件循环，完全避开当前的 Focus/Build 流程
    // 这样可以彻底解决 "This widget has been unmounted" 崩溃
    Future.delayed(Duration.zero, () {
      if (mounted && widget.onSelectionChange != null) {
        widget.onSelectionChange!(true);
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      }
    });

    // 计算位置
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final localPosition = details.localPosition;

    // X轴居中，Y轴在点击位置下方
    final menuOffset = Offset(size.width / 2, localPosition.dy + 15);

    _showFloatingToolbar(menuOffset);
  }

  void _resetSelection() {
    if (mounted) {
      setState(() => _isSelected = false);
      OverlayMenuManager.hide();

      // 同样推迟取消选中的通知
      Future.delayed(Duration.zero, () {
        if (mounted && widget.onSelectionChange != null) {
          widget.onSelectionChange!(false);
        }
      });
    }
  }

  void _showCaptionDialog() {
    OverlayMenuManager.hide();
    final textController = TextEditingController(text: widget.caption);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑题注'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入图片描述...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final text = textController.text.trim();
              widget.onCaptionChange(text.isEmpty ? null : text);
              Navigator.pop(ctx);
              _resetSelection();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showFloatingToolbar(Offset offset) {
    OverlayMenuManager.show(
      context: context,
      layerLink: _layerLink,
      offset: offset,
      onDismiss: _resetSelection,
      child: _FloatingToolbar(
        isFullWidth: widget.isFullWidth,
        hasCaption: widget.caption != null && widget.caption!.isNotEmpty,
        onToggleWidth: () {
          widget.onWidthToggle(!widget.isFullWidth);
          _resetSelection();
        },
        onEditCaption: _showCaptionDialog,
        onDelete: () {
          OverlayMenuManager.hide();
          widget.onDelete();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double borderWidth = _isSelected ? 2.5 : 0.0;
    const double imageRadius = 12.0;
    final double outerRadius = imageRadius + borderWidth;

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _handleTapDown, // 保持使用 onTapDown
        child: Container(
          padding: EdgeInsets.symmetric(
              vertical: widget.isFullWidth ? 16.0 : 8.0,
              horizontal: 4.0
          ),
          decoration: const BoxDecoration(color: Colors.transparent),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(borderWidth),
                decoration: BoxDecoration(
                  color: _isSelected ? theme.colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(outerRadius),
                  boxShadow: _isSelected ? [
                    BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        blurRadius: 12,
                        spreadRadius: 2
                    )
                  ] : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(imageRadius),
                  clipBehavior: Clip.antiAlias,
                  child: widget.isFullWidth
                      ? _buildFullWidthImage()
                      : _buildConstrainedImage(),
                ),
              ),
              if (widget.caption != null && widget.caption!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                  child: Text(
                    widget.caption!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageContent() {
    if (widget.imageFile == null) {
      return _buildErrorWidget(context, "加载中...");
    }
    return Image.file(
      widget.imageFile!,
      fit: widget.isFullWidth ? BoxFit.fitWidth : BoxFit.contain,
      errorBuilder: (ctx, err, stack) => _buildErrorWidget(ctx, "加载失败"),
    );
  }

  Widget _buildFullWidthImage() {
    return SizedBox(width: double.infinity, child: _buildImageContent());
  }

  Widget _buildConstrainedImage() {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 450, maxWidth: MediaQuery.of(context).size.width * 0.9),
      child: _buildImageContent(),
    );
  }

  Widget _buildErrorWidget(BuildContext context, String msg) {
    return Container(
      height: 150, width: double.infinity,
      color: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
          const SizedBox(height: 8),
          Text(msg, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

// --- 3. 悬浮工具栏 ---
class _FloatingToolbar extends StatelessWidget {
  final bool isFullWidth;
  final bool hasCaption;
  final VoidCallback onToggleWidth;
  final VoidCallback onEditCaption;
  final VoidCallback onDelete;

  const _FloatingToolbar({
    required this.isFullWidth,
    required this.hasCaption,
    required this.onToggleWidth,
    required this.onEditCaption,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: Alignment.topCenter,
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2), width: 0.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                  spreadRadius: -2
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolbarButton(
                icon: isFullWidth ? Icons.close_fullscreen_rounded : Icons.fullscreen_rounded,
                tooltip: isFullWidth ? '默认大小' : '适应屏幕',
                onTap: onToggleWidth,
              ),
              _VerticalDivider(),
              _ToolbarButton(
                icon: hasCaption ? Icons.edit_note_rounded : Icons.add_comment_rounded,
                tooltip: '题注',
                onTap: onEditCaption,
                active: hasCaption,
              ),
              _VerticalDivider(),
              _ToolbarButton(
                icon: Icons.delete_rounded,
                tooltip: '删除',
                onTap: onDelete,
                isDestructive: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool active;
  final String tooltip;

  const _ToolbarButton({
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
    this.active = false,
    this.tooltip = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? theme.colorScheme.error
        : (active ? theme.colorScheme.primary : theme.colorScheme.onSurface);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1,
        height: 16,
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3)
    );
  }
}

// --- 4. 菜单管理器 ---
class OverlayMenuManager {
  static OverlayEntry? _currentEntry;

  static void show({
    required BuildContext context,
    required LayerLink layerLink,
    required Offset offset,
    required VoidCallback onDismiss,
    required Widget child
  }) {
    hide();
    final overlayState = Overlay.of(context);
    _currentEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
              child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) {
                    hide();
                    onDismiss();
                  },
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (scrollNotification) {
                      hide();
                      onDismiss();
                      return true;
                    },
                    child: Container(color: Colors.transparent),
                  )
              )
          ),
          CompositedTransformFollower(
              link: layerLink,
              showWhenUnlinked: false,
              offset: offset,
              targetAnchor: Alignment.topLeft,
              followerAnchor: Alignment.topCenter,
              child: child
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