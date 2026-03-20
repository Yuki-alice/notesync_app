import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../../core/services/image_storage_service.dart';

bool globalImageLock = false;

class ImageEmbedBuilder extends quill.EmbedBuilder {
  final ImageStorageService imageService;
  final ValueChanged<bool>? onSelectionChange;

  ImageEmbedBuilder({required this.imageService, this.onSelectionChange});

  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final String path = embedContext.node.value.data;
    if (path.isEmpty) return const SizedBox();

    return InteractableImage(
      imageService: imageService,
      path: path,
      isFullWidth: embedContext.node.style.attributes['width']?.value == '100%',
      caption: embedContext.node.style.attributes['caption']?.value,
      controller: embedContext.controller,
      node: embedContext.node,
      onSelectionChange: onSelectionChange,
      onWidthToggle:
          (newValue) => _updateAttribute(
            embedContext.controller,
            embedContext.node,
            'width',
            newValue ? '100%' : null,
          ),
      onCaptionChange:
          (newCaption) => _updateAttribute(
            embedContext.controller,
            embedContext.node,
            'caption',
            newCaption,
          ),
      onDelete: () => _deleteImage(embedContext.controller, embedContext.node),
    );
  }

  void _updateAttribute(
    quill.QuillController controller,
    quill.Embed node,
    String key,
    dynamic value,
  ) {
    final offset = getEmbedNodeOffset(controller, node);
    if (offset != -1) {
      controller.formatText(
        offset,
        1,
        quill.Attribute(key, quill.AttributeScope.inline, value),
      );
    }
  }

  void _deleteImage(quill.QuillController controller, quill.Embed node) {
    final offset = getEmbedNodeOffset(controller, node);
    if (offset != -1) {
      controller.replaceText(
        offset,
        1,
        '',
        const TextSelection.collapsed(offset: 0),
      );
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

class InteractableImage extends StatefulWidget {
  final ImageStorageService imageService;
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
    required this.imageService,
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
  File? _resolvedFile;
  bool _isLoading = true;
  late String _heroTag;
  Offset? _lastTapDownPosition;

  Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    _heroTag = 'preview_${widget.path}_${widget.node.hashCode}';
    _loadImage();
  }

  void _loadImage() async {
    final file = await widget.imageService.getLocalFile(widget.path);
    if (mounted) {
      setState(() {
        _resolvedFile = file;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    if (_isSelected) OverlayMenuManager.hide();
    _lockTimer?.cancel();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _lastTapDownPosition = details.localPosition;
  }

  void _handleTap() {
    _lockTimer?.cancel();
    globalImageLock = true; // 🌟 持续上锁！
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    if (_isSelected) {
      _resetSelection();
      return;
    }

    setState(() => _isSelected = true);
    Future.delayed(Duration.zero, () {
      if (mounted && widget.onSelectionChange != null) {
        widget.onSelectionChange!(true);
      }
    });

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    double dx = _lastTapDownPosition?.dx ?? (size.width / 2);
    if (dx < 100) dx = 100;
    if (dx > size.width - 100) dx = size.width - 100;

    final menuOffset = Offset(dx, (_lastTapDownPosition?.dy ?? 20) - 15);
    _showFloatingToolbar(menuOffset);
  }

  void _resetSelection() {
    if (mounted) {
      setState(() => _isSelected = false);
      OverlayMenuManager.hide();
      globalImageLock = false; // 🌟 图片取消选中时释放锁定！

      FocusManager.instance.primaryFocus?.unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');

      Future.delayed(Duration.zero, () {
        if (mounted && widget.onSelectionChange != null) {
          widget.onSelectionChange!(false);
        }
      });
    }
  }

  void _viewFullImage() {
    OverlayMenuManager.hide();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.95),
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder:
            (context, animation, _) => FadeTransition(
              opacity: animation,
              child: FullScreenImageViewer(
                imageFile: _resolvedFile,
                heroTag: _heroTag,
              ),
            ),
      ),
    );
    _resetSelection();
  }

  void _showCaptionDialog() {
    OverlayMenuManager.hide();
    final textController = TextEditingController(text: widget.caption);
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
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
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
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
        onViewFullImage: _viewFullImage,
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
      child: Listener(
        onPointerDown: (_) {
          // 瞬间关门放狗，没收 Quill 的键盘呼叫权！
          globalImageLock = true;
          FocusManager.instance.primaryFocus?.unfocus();
          SystemChannels.textInput.invokeMethod('TextInput.hide');

          _lockTimer?.cancel();
          _lockTimer = Timer(const Duration(milliseconds: 300), () {
            if (mounted && !_isSelected) {
              globalImageLock = false;
            }
          });
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _handleTapDown,
          onTap: _handleTap,
          onDoubleTap: () {},
          onLongPress: () {},

          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: Colors.transparent),
            padding: EdgeInsets.symmetric(
              vertical: widget.isFullWidth ? 16.0 : 8.0,
              horizontal: 4.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.all(borderWidth),
                  decoration: BoxDecoration(
                    color:
                        _isSelected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(outerRadius),
                    boxShadow:
                        _isSelected
                            ? [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.2,
                                ),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                            : [],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(imageRadius),
                    clipBehavior: Clip.antiAlias,
                    child: Hero(
                      tag: _heroTag,
                      child:
                          widget.isFullWidth
                              ? _buildFullWidthImage()
                              : _buildConstrainedImage(),
                    ),
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
      ),
    );
  }

  Widget _buildImageContent() {
    if (_isLoading) {
      return Container(
        height: 150,
        width: double.infinity,
        color: Colors.grey[100],
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_resolvedFile == null) {
      return Container(
        height: 150,
        width: double.infinity,
        color: Colors.grey[100],
        child: const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Colors.grey,
            size: 32,
          ),
        ),
      );
    }
    return Image.file(
      _resolvedFile!,
      fit: widget.isFullWidth ? BoxFit.fitWidth : BoxFit.contain,
      gaplessPlayback: true,
    );
  }

  Widget _buildFullWidthImage() {
    return SizedBox(width: double.infinity, child: _buildImageContent());
  }

  Widget _buildConstrainedImage() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: 450,
        maxWidth: MediaQuery.of(context).size.width * 0.9,
      ),
      child: _buildImageContent(),
    );
  }
}

class _FloatingToolbar extends StatelessWidget {
  final bool isFullWidth;
  final bool hasCaption;
  final VoidCallback onViewFullImage;
  final VoidCallback onToggleWidth;
  final VoidCallback onEditCaption;
  final VoidCallback onDelete;

  const _FloatingToolbar({
    required this.isFullWidth,
    required this.hasCaption,
    required this.onViewFullImage,
    required this.onToggleWidth,
    required this.onEditCaption,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: Alignment.bottomCenter,
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolbarButton(
                icon: Icons.image_rounded,
                tooltip: '查看大图',
                onTap: onViewFullImage,
              ),
              Container(
                width: 1,
                height: 16,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              _ToolbarButton(
                icon:
                    isFullWidth
                        ? Icons.close_fullscreen_rounded
                        : Icons.fullscreen_rounded,
                tooltip: isFullWidth ? '默认大小' : '适应屏幕',
                onTap: onToggleWidth,
              ),
              Container(
                width: 1,
                height: 16,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              _ToolbarButton(
                icon:
                    hasCaption
                        ? Icons.edit_note_rounded
                        : Icons.add_comment_rounded,
                tooltip: '题注',
                onTap: onEditCaption,
                active: hasCaption,
              ),
              Container(
                width: 1,
                height: 16,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
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
    final color =
        isDestructive
            ? theme.colorScheme.error
            : (active
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}

class OverlayMenuManager {
  static OverlayEntry? _currentEntry;
  static void show({
    required BuildContext context,
    required LayerLink layerLink,
    required Offset offset,
    required VoidCallback onDismiss,
    required Widget child,
  }) {
    hide();
    _currentEntry = OverlayEntry(
      builder:
          (context) => Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) {
                    hide();
                    onDismiss();
                  },
                  onTap: () {},
                  onTapUp: (_) {},
                  onTapCancel: () {},
                  onDoubleTap: () {},
                  onLongPress: () {},
                  onPanDown: (_) {
                    hide();
                    onDismiss();
                  },
                  child: Container(color: Colors.transparent),
                ),
              ),
              CompositedTransformFollower(
                link: layerLink,
                showWhenUnlinked: false,
                offset: offset,
                targetAnchor: Alignment.topLeft,
                followerAnchor: Alignment.bottomCenter,
                child: child,
              ),
            ],
          ),
    );
    Overlay.of(context).insert(_currentEntry!);
  }

  static void hide() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final File? imageFile;
  final String heroTag;
  const FullScreenImageViewer({
    super.key,
    required this.imageFile,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: Hero(
                  tag: heroTag,
                  child:
                      imageFile != null
                          ? Image.file(imageFile!, fit: BoxFit.contain)
                          : const Icon(
                            Icons.broken_image,
                            color: Colors.white,
                            size: 64,
                          ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.4),
                padding: const EdgeInsets.all(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
