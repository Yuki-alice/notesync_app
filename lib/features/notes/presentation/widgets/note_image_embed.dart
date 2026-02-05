import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../../core/services/image_storage_service.dart';

// --- 1. 图片构建器 (连接 Quill 和 ImageService) ---
class ImageEmbedBuilder extends quill.EmbedBuilder {
  final ImageStorageService imageService;

  ImageEmbedBuilder({required this.imageService});

  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    // 这里的 path 可能是相对路径，也可能是绝对路径
    final String path = embedContext.node.value.data;
    if (path.isEmpty) return const SizedBox();

    final isFullWidth = embedContext.node.style.attributes['width']?.value == '100%';

    // 使用 FutureBuilder 异步解析真实路径
    return FutureBuilder<File?>(
      future: imageService.getLocalFile(path),
      builder: (context, snapshot) {
        return InteractableImage(
          imageFile: snapshot.data,
          path: path,
          isFullWidth: isFullWidth,
          controller: embedContext.controller,
          node: embedContext.node,
          onWidthToggle: (newValue) => _toggleImageWidth(embedContext.controller, embedContext.node, newValue),
          onAddCaption: () => _addCaption(embedContext.controller, embedContext.node),
          onDelete: () => _deleteImage(embedContext.controller, embedContext.node),
        );
      },
    );
  }

  // --- 辅助操作方法 ---
  void _toggleImageWidth(quill.QuillController controller, quill.Embed node, bool enableFullWidth) {
    final offset = getEmbedNodeOffset(controller, node);
    if (offset != -1) {
      final String imageUrl = node.value.data;
      controller.document.delete(offset, 1);
      controller.document.insert(offset, quill.BlockEmbed.image(imageUrl));
      if (enableFullWidth) {
        controller.formatText(offset, 1, quill.Attribute('width', quill.AttributeScope.inline, '100%'));
      }
      // 恢复光标位置
      Future.delayed(Duration.zero, () {
        controller.updateSelection(TextSelection.collapsed(offset: offset + 1), quill.ChangeSource.local);
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
      controller.formatText(textStart, captionText.length, quill.Attribute.small);
      controller.formatText(textStart, captionText.length, quill.Attribute.centerAlignment);
      controller.formatText(textStart, captionText.length, quill.Attribute('color', quill.AttributeScope.inline, '#2F4F4F'));
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
  final quill.QuillController controller;
  final quill.Embed node;
  final Function(bool) onWidthToggle;
  final VoidCallback onAddCaption;
  final VoidCallback onDelete;

  const InteractableImage({
    super.key,
    required this.imageFile,
    required this.path,
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
          child: widget.isFullWidth ? _buildFullWidthImage() : _buildConstrainedImage(),
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
    return Hero(
      tag: widget.path,
      child: SizedBox(width: double.infinity, child: _buildImageContent()),
    );
  }

  Widget _buildConstrainedImage() {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 450, maxWidth: MediaQuery.of(context).size.width * 0.9),
      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Hero(tag: widget.path, child: _buildImageContent())),
    );
  }

  Widget _buildErrorWidget(BuildContext context, String msg) {
    return Container(
      height: 150, width: double.infinity,
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
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

// --- 3. 悬浮工具栏 (UI 部分) ---
class _FloatingToolbar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 4),
            _buildIconBtn(icon: isFullWidth ? Icons.photo_size_select_small_rounded : Icons.fit_screen_rounded, onTap: onToggleWidth),
            _buildDivider(),
            _buildIconBtn(icon: Icons.edit_note_rounded, onTap: onAddCaption),
            _buildDivider(),
            _buildIconBtn(icon: Icons.delete_outline_rounded, onTap: onDelete, isDestructive: true),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBtn({required IconData icon, required VoidCallback onTap, bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Icon(icon, size: 20, color: isDestructive ? Colors.redAccent : Colors.black87),
      ),
    );
  }

  Widget _buildDivider() => Container(width: 1, height: 16, color: Colors.grey.withOpacity(0.2));
}

// --- 4. 菜单管理器 ---
class OverlayMenuManager {
  static OverlayEntry? _currentEntry;

  static void show({required BuildContext context, required LayerLink layerLink, required VoidCallback onDismiss, required Widget child}) {
    hide();
    final overlayState = Overlay.of(context);
    _currentEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTapDown: (_) { hide(); onDismiss(); }, child: Container(color: Colors.transparent))),
          CompositedTransformFollower(link: layerLink, offset: const Offset(0, 12), targetAnchor: Alignment.bottomCenter, followerAnchor: Alignment.topCenter, child: child),
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