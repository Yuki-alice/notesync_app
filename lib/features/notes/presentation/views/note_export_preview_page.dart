import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/services/image_storage_service.dart';
import '../../../../utils/toast_utils.dart';
import '../widgets/note_image_embed.dart';


class NoteExportPreviewPage extends StatefulWidget {
  final String title;
  final String deltaJson;

  const NoteExportPreviewPage({super.key, required this.title, required this.deltaJson});

  @override
  State<NoteExportPreviewPage> createState() => _NoteExportPreviewPageState();
}

class _NoteExportPreviewPageState extends State<NoteExportPreviewPage> {
  final GlobalKey _boundaryKey = GlobalKey();
  late quill.QuillController _controller;
  bool _isCaptured = false;
  Uint8List? _imageBytes;
  final ImageStorageService _imageService = ImageStorageService();

  @override
  void initState() {
    super.initState();
    // 🌟 1. 还原富文本数据
    try {
      final doc = quill.Document.fromJson(jsonDecode(widget.deltaJson));
      _controller = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (e) {
      _controller = quill.QuillController.basic();
    }

    // 🌟 2. 延迟捕获：给本地图片足够的解码和排版时间
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureFullNoteImage();
    });
  }

  Future<void> _captureFullNoteImage() async {
    // 缓冲 600 毫秒，确保 Quill 引擎中的 Image.file 全部绘制到屏幕上
    await Future.delayed(const Duration(milliseconds: 600));

    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // 如果 UI 还在请求重绘，再等一帧
      if (boundary.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 50));
        return _captureFullNoteImage();
      }

      // 🌟 3. 提取高清图片 (pixelRatio: 2.0 保证文字不发虚)
      final image = await boundary.toImage(pixelRatio: ui.window.devicePixelRatio ?? 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null && mounted) {
        setState(() {
          _imageBytes = byteData.buffer.asUint8List();
          _isCaptured = true;
        });
      }
    } catch (e) {
      debugPrint('Capture Error: $e');
      if (mounted) ToastUtils.showError(context, '图片生成失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        title: const Text('分享预览', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
      // 🌟 状态切换：捕获完成前显示骨架/Loading，完成后显示可操作的真实图片
      body: _isCaptured && _imageBytes != null
          ? _buildPreviewAndActions(theme)
          : _buildCapturingState(theme),
    );
  }

  /// ====================================================================
  /// 状态 A：正在幕后捕获中
  /// ====================================================================
  Widget _buildCapturingState(ThemeData theme) {
    return Stack(
      children: [
        // 🌟 【核心修复区】：我们要把完整的 Quill 扔到一个隐藏的边界里！
        // 必须用 SingleChildScrollView 包含，确保不受屏幕高度限制
        SingleChildScrollView(
          child: RepaintBoundary(
            key: _boundaryKey,
            child: Container(
              color: theme.colorScheme.surface, // 导出的图片背景色
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min, // 确保高度包裹内容
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title.isEmpty ? '未命名笔记' : widget.title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 🌟 分隔线
                  Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3), height: 1),
                  const SizedBox(height: 24),

                  quill.QuillEditor.basic(
                    controller: _controller,
                    focusNode: FocusNode(),
                    scrollController: ScrollController(),
                    config: quill.QuillEditorConfig(
                      // 🌟 修复 1：绝对不能让他滚动！必须把内容完全撑开！
                      scrollable: false,
                      expands: false,
                      autoFocus: false,
                      showCursor: false,
                      // 🌟 修复 2：必须把 ImageEmbedBuilder 带上，否则 Quill 遇到图片就装死！
                      embedBuilders: [
                        ImageEmbedBuilder(
                          imageService: _imageService,
                          onSelectionChange: (_) {}, // 预览模式不需要选中状态
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),
                  Center(
                    child: Text(
                      '--- 生成自 NoteSync ---',
                      style: TextStyle(
                          color: theme.colorScheme.outline.withValues(alpha: 0.5),
                          letterSpacing: 2.0,
                          fontSize: 12
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),

        // 覆盖在上面的遮罩 Loading
        Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在精心排版并绘制图片...', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// ====================================================================
  /// 状态 B：捕获完成，展示图片和按钮
  /// ====================================================================
  Widget _buildPreviewAndActions(ThemeData theme) {
    return Column(
      children: [
        // 预览区
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            physics: const BouncingScrollPhysics(),
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))
                  ],
                ),
                child: Image.memory(_imageBytes!), // 直接展示生成的内存图片
              ),
            ),
          ),
        ),

        // 底部操作区
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('分享长图', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    try {
                      final directory = await getTemporaryDirectory();
                      final imagePath = '${directory.path}/share_${DateTime.now().millisecondsSinceEpoch}.png';
                      await File(imagePath).writeAsBytes(_imageBytes!);
                      await Share.shareXFiles([XFile(imagePath)], text: widget.title);
                    } catch (e) {
                      if (mounted) ToastUtils.showError(context, '分享失败');
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.save_alt_rounded),
                  label: const Text('保存到相册 / 本地', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    try {
                      final directory = await getTemporaryDirectory();
                      final imagePath = '${directory.path}/share_${DateTime.now().millisecondsSinceEpoch}.png';
                      await File(imagePath).writeAsBytes(_imageBytes!);

                      if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
                        await Gal.putImage(imagePath);
                        if (mounted) ToastUtils.showSuccess(context, '已保存到相册 ✨');
                      } else {
                        final dlDir = await getDownloadsDirectory();
                        await File(imagePath).copy('${dlDir?.path}/NoteSync_${DateTime.now().millisecondsSinceEpoch}.png');
                        if (mounted) ToastUtils.showSuccess(context, '已保存到下载文件夹 ✨');
                      }
                    } catch (e) {
                      if (mounted) ToastUtils.showError(context, '保存失败或没有权限');
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}