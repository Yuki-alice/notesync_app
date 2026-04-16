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
    try {
      final doc = quill.Document.fromJson(jsonDecode(widget.deltaJson));
      _controller = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (e) {
      _controller = quill.QuillController.basic();
    }

    // 给富文本和图片加载预留更充足的时间
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureFullNoteImage();
    });
  }

  Future<void> _captureFullNoteImage() async {
    // 等待 800 毫秒，确保图片等资源全渲染完毕
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      if (boundary.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 100));
        return _captureFullNoteImage();
      }

      // 提取高清图片
      final image = await boundary.toImage(pixelRatio: 2.5); // 调高像素比，文字更锐利
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
        title: const Text('生成精美长图', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        elevation: 0,
      ),
      body: _isCaptured && _imageBytes != null
          ? _buildPreviewAndActions(theme)
          : _buildCapturingState(theme),
    );
  }

  /// ====================================================================
  /// 状态 A：后台高质量画布排版区 (用户不可见或被 Loading 遮挡)
  /// ====================================================================
  Widget _buildCapturingState(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    // 🌟 提取高级的渐变背景色
    final bgColor1 = isDark ? const Color(0xFF1A1D21) : Color.alphaBlend(theme.colorScheme.primary.withValues(alpha: 0.15), theme.colorScheme.surface);
    final bgColor2 = isDark ? const Color(0xFF121212) : theme.colorScheme.surfaceContainerLowest;
    final paperColor = isDark ? const Color(0xFF242424) : Colors.white;

    return Stack(
      children: [
        // 🌟 核心黑科技：InteractiveViewer 允许我们在手机上渲染比手机宽得多的 Widget！
        // 这样文字就不会被挤压，长宽比极度完美。
        InteractiveViewer(
          constrained: false, // 允许子组件突破屏幕尺寸
          child: RepaintBoundary(
            key: _boundaryKey,
            child: Container(
              // 🌟 强制设定画布宽度为 760 (黄金阅读宽度)，告别手机屏幕的面条感！
              width: 760,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [bgColor1, bgColor2],
                ),
              ),
              // 留出超大外边距，露出漂亮的高级背景
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🌟 白色卡片实体 (纸张)
                  Container(
                    decoration: BoxDecoration(
                      color: paperColor,
                      borderRadius: BorderRadius.circular(24), // 圆润的卡片感
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 40, offset: const Offset(0, 20)),
                      ],
                    ),
                    // 纸张内部的高级留白
                    padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 72),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 大标题排版
                        Text(
                          widget.title.isEmpty ? '未命名笔记' : widget.title,
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurface,
                            height: 1.3,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 优雅的分割线和时间戳
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 16, color: theme.colorScheme.outline),
                            const SizedBox(width: 8),
                            Text(
                              '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
                              style: TextStyle(color: theme.colorScheme.outline, fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),

                        // 富文本内容
                        quill.QuillEditor.basic(
                          controller: _controller,
                          focusNode: FocusNode(),
                          scrollController: ScrollController(),
                          config: quill.QuillEditorConfig(
                            scrollable: false,
                            expands: false,
                            autoFocus: false,
                            showCursor: false,
                            embedBuilders: [
                              ImageEmbedBuilder(
                                imageService: _imageService,
                                onSelectionChange: (_) {},
                              ),
                            ],
                            // 可以注入你在桌面端用的那套高级 Style
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 🌟 底部 Branding 落款
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Powered by NoteSync',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20), // 底部留白
                ],
              ),
            ),
          ),
        ),

        // 🌟 Loading 遮罩层，在图片生成好之前挡住乱跳的排版过程
        Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 3, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  '正在精心绘制排版...',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// ====================================================================
  /// 状态 B：捕获完成，展示缩放预览与分享按钮
  /// ====================================================================
  Widget _buildPreviewAndActions(ThemeData theme) {
    return Column(
      children: [
        // 预览区 (支持手势缩放查看长图细节)
        Expanded(
          child: InteractiveViewer(
            minScale: 0.1,
            maxScale: 3.0,
            boundaryMargin: const EdgeInsets.all(40),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, 10))
                    ],
                  ),
                  // 为了在预览时不显得过大卡顿，稍微裁剪圆角预览
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_imageBytes!),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 底部操作区 (Craft 风格的圆润按钮)
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, -4))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  icon: const Icon(Icons.ios_share_rounded, size: 20),
                  label: const Text('分享至微信 / 社交平台', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
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
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text('保存到手机相册', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  onPressed: () async {
                    try {
                      final directory = await getTemporaryDirectory();
                      final imagePath = '${directory.path}/share_${DateTime.now().millisecondsSinceEpoch}.png';
                      await File(imagePath).writeAsBytes(_imageBytes!);

                      if (Platform.isAndroid || Platform.isIOS) {
                        await Gal.putImage(imagePath);
                        if (mounted) ToastUtils.showSuccess(context, '✨ 长图已保存到相册');
                      } else {
                        final dlDir = await getDownloadsDirectory();
                        await File(imagePath).copy('${dlDir?.path}/NoteSync_${DateTime.now().millisecondsSinceEpoch}.png');
                        if (mounted) ToastUtils.showSuccess(context, '✨ 长图已保存到下载文件夹');
                      }
                    } catch (e) {
                      if (mounted) ToastUtils.showError(context, '保存失败，请检查相册权限');
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