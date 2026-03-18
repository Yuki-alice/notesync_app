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
    // 还原富文本数据
    final doc = quill.Document.fromJson(jsonDecode(widget.deltaJson));
    _controller = quill.QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0));

    // 给 Quill 引擎一点时间渲染图片，然后再截图
    Future.delayed(const Duration(milliseconds: 50), _captureImage);
  }

  Future<void> _captureImage() async {
    try {
      RenderRepaintBoundary boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (mounted) {
        setState(() {
          _imageBytes = byteData!.buffer.asUint8List();
          _isCaptured = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, '生成预览失败，请重试');
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 状态一：正在后台渲染长图 (显示 Loading 遮罩层)
    if (!_isCaptured) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Stack(
          children: [
            // 底层：真实渲染的干净排版 UI (用户看不见)
            SingleChildScrollView(
              child: RepaintBoundary(
                key: _boundaryKey,
                child: Container(
                  color: theme.scaffoldBackgroundColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.title.isNotEmpty)
                        Text(widget.title, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 34, fontWeight: FontWeight.bold, height: 1.3)),
                      if (widget.title.isNotEmpty)
                        const SizedBox(height: 24),
                      quill.QuillEditor.basic(
                        controller: _controller, focusNode: FocusNode(),
                        config: quill.QuillEditorConfig(
                          scrollable: false, expands: false, showCursor: false,
                          embedBuilders: [ImageEmbedBuilder(imageService: _imageService, onSelectionChange: (_) {})],
                          customStyles: quill.DefaultStyles(
                            paragraph: quill.DefaultTextBlockStyle(TextStyle(fontSize: 17, height: 1.6, color: theme.colorScheme.onSurface.withOpacity(0.85)), const quill.HorizontalSpacing(0, 0), const quill.VerticalSpacing(0, 0), const quill.VerticalSpacing(0, 0), null),
                            h1: quill.DefaultTextBlockStyle(TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.5, color: theme.colorScheme.onSurface), const quill.HorizontalSpacing(0, 0), const quill.VerticalSpacing(16, 0), const quill.VerticalSpacing(0, 0), null),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      // 专属底栏水印
                      Center(
                        child: Column(
                          children: [
                            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withOpacity(0.5), shape: BoxShape.circle), child: Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary, size: 24)),
                            const SizedBox(height: 16),
                            Text('NoteSync', style: TextStyle(color: theme.colorScheme.primary, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                            const SizedBox(height: 6),
                            Text('记录碎片的灵感与美好', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, letterSpacing: 0.5)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
            // 顶层：Loading 遮罩
            Container(
              color: theme.colorScheme.surface,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('正在生成精美长图...', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            )
          ],
        ),
      );
    }

    // 状态二：截图完成，显示可缩放的交互预览页
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('长图预览', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: () async {
                final directory = await getTemporaryDirectory();
                final imagePath = '${directory.path}/share_${DateTime.now().millisecondsSinceEpoch}.png';
                final file = File(imagePath);
                await file.writeAsBytes(_imageBytes!);
                await Share.shareXFiles([XFile(imagePath)], text: '分享笔记');
              }
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5, maxScale: 3.0,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Container(
                      decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 12))]),
                      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_imageBytes!)),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: BoxDecoration(color: theme.colorScheme.surface, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, -4))]),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), backgroundColor: theme.colorScheme.primary, foregroundColor: theme.colorScheme.onPrimary),
                icon: const Icon(Icons.save_alt_rounded),
                label: const Text('保存到本地相册', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                onPressed: () async {
                  try {
                    final directory = await getTemporaryDirectory();
                    final imagePath = '${directory.path}/share_${DateTime.now().millisecondsSinceEpoch}.png';
                    await File(imagePath).writeAsBytes(_imageBytes!);

                    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
                      await Gal.putImage(imagePath);
                      if (context.mounted) ToastUtils.showSuccess(context, '已保存到相册 ✨');
                    } else {
                      final dlDir = await getDownloadsDirectory();
                      await File(imagePath).copy('${dlDir?.path}/NoteSync_${DateTime.now().millisecondsSinceEpoch}.png');
                      if (context.mounted) ToastUtils.showSuccess(context, '已保存到下载文件夹 ✨');
                    }
                  } catch (e) {
                    if (context.mounted) ToastUtils.showError(context, '保存失败或没有权限');
                  }
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}