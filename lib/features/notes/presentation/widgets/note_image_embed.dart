// 文件路径: lib/features/notes/presentation/widgets/note_image_embed.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../../core/services/image_storage_service.dart';

class ImageEmbedBuilder extends quill.EmbedBuilder {
  final ImageStorageService imageService;
  // 回调：通知父级选中状态变化
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
          // 传入回调
          onSelectionChange: onSelectionChange,
          onWidthToggle: (newValue) => _updateAttribute(embedContext.controller, embedContext.node, 'width', newValue ? '100%' : null),
          onCaptionChange: (newCaption) => _updateAttribute(embedContext.controller, embedContext.node, 'caption', newCaption),
          onDelete: () => _deleteImage(embedContext.controller, embedContext.node),
        );
      },
    );
  }

  // --- 辅助操作方法 ---
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

  void _handleTap() {
    // 🟢 1. 强制清除焦点和选区，防止光标出现
    FocusScope.of(context).unfocus();
    // 将选区设为 -1，彻底移除光标
    widget.controller.updateSelection(const TextSelection.collapsed(offset: -1), quill.ChangeSource.local);
    // 强制隐藏软键盘
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    final newValue = !_isSelected;
    setState(() => _isSelected = newValue);

    // 通知外部：选中状态改变
    if (widget.onSelectionChange != null) {
      widget.onSelectionChange!(newValue);
    }

    if (_isSelected) {
      _showFloatingToolbar();
    } else {
      OverlayMenuManager.hide();
    }
  }

  // 辅助方法：重置选中状态
  void _resetSelection() {
    if (mounted) {
      setState(() => _isSelected = false);
      if (widget.onSelectionChange != null) {
        widget.onSelectionChange!(false);
      }
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
              _resetSelection(); // 编辑完关闭选中
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showFloatingToolbar() {
    OverlayMenuManager.show(
      context: context,
      layerLink: _layerLink,
      onDismiss: () {
        _resetSelection();
      },
      child: _FloatingToolbar(
        isFullWidth: widget.isFullWidth,
        hasCaption: widget.caption != null && widget.caption!.isNotEmpty,
        onToggleWidth: () {
          widget.onWidthToggle(!widget.isFullWidth);
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

    // 边框宽度 (选中时显示)
    final double borderWidth = _isSelected ? 2.5 : 0.0;
    // 图片自身的圆角
    const double imageRadius = 12.0;
    // 🟢 外层容器圆角 = 图片圆角 + 边框宽度
    final double outerRadius = imageRadius + borderWidth;

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // 🟢 确保点击透明区域也能响应
        onTap: _handleTap,
        child: Container(
          // 🟢 关键修改：使用 Padding 而不是 Margin
          // 将这 4px 的空隙纳入组件内部，这样点击空隙也会触发 _handleTap (选中图片)，而不是触发编辑器的光标
          padding: EdgeInsets.symmetric(
              vertical: widget.isFullWidth ? 16.0 : 8.0,
              horizontal: 4.0
          ),
          // 🟢 必须设置背景色（即使是透明），否则透明区域的点击可能会穿透
          decoration: const BoxDecoration(color: Colors.transparent),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🟢 核心修复：使用“填充模拟边框”
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                // Padding 的厚度就是边框的厚度
                padding: EdgeInsets.all(borderWidth),
                decoration: BoxDecoration(
                  // 边框颜色 (实际上是背景色)
                  color: _isSelected ? theme.colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(outerRadius),
                  // 选中时添加柔和阴影
                  boxShadow: _isSelected ? [
                    BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.2),
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

              // 题注 (在边框外)
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

    return Material(
      color: Colors.transparent,
      child: Container(
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 6)
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolbarButton(
              icon: isFullWidth ? Icons.close_fullscreen_rounded : Icons.fullscreen_rounded,
              tooltip: isFullWidth ? '恢复默认' : '适应屏幕',
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
              icon: Icons.copy_rounded,
              tooltip: '复制',
              onTap: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制图片'), duration: Duration(seconds: 1)));
              },
            ),
            _VerticalDivider(),
            _ToolbarButton(
              icon: Icons.delete_outline_rounded,
              tooltip: '删除',
              onTap: onDelete,
              isDestructive: true,
            ),
          ],
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
        : (active ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1,
        height: 20,
        color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)
    );
  }
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
          Positioned.fill(
              child: GestureDetector(
                // 🟢 核心修复：改为 opaque，拦截点击事件，防止穿透到编辑器
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) {
                    hide();
                    onDismiss();
                  },
                  child: Container(color: Colors.transparent)
              )
          ),
          CompositedTransformFollower(
              link: layerLink,
              offset: const Offset(0, 8),
              targetAnchor: Alignment.bottomCenter,
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