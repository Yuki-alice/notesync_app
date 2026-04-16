import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../viewmodels/note_editor_viewmodel.dart';
import '../../../../../utils/toast_utils.dart';
import '../../views/note_export_preview_page.dart';
import '../shared/note_rich_card.dart';

class ShareDialog extends StatefulWidget {
  final String noteTitle;
  final NoteEditorViewModel viewModel;

  const ShareDialog({
    super.key,
    required this.noteTitle,
    required this.viewModel,
  });

  @override
  State<ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<ShareDialog> {
  // 🌟 独立管理的截屏 Key，彻底解决 Duplicate GlobalKey 报错
  final GlobalKey _exportKey = GlobalKey();

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 🌟 离屏渲染黑科技：将高定画卷藏在屏幕之外进行渲染
          // 无论手机还是电脑，我们在幕后始终渲染这张高清卡片，供长图和 PDF 提取！
          Positioned(
            left: -10000,
            top: -10000,
            child: RepaintBoundary(
              key: _exportKey,
              child: SharedNoteRichCard(
                title: widget.noteTitle,
                controller: widget.viewModel.quillController,
                theme: theme,
                width: 800, // 给定一个黄金阅读宽度
              ),
            ),
          ),

          // 正常展示的分享弹窗 UI
          AlertDialog(
            backgroundColor: colorScheme.surface,
            surfaceTintColor: colorScheme.surfaceTint,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Row(
              children: [
                Icon(Icons.share_rounded, color: colorScheme.primary),
                const SizedBox(width: 12),
                const Text('分享与导出', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildShareOption(
                      context,
                      Icons.image_outlined,
                      '导出精美长图',
                      '生成带背景的高定画卷',
                          () => _exportAsImage(context)
                  ),
                  const SizedBox(height: 8),
                  _buildShareOption(
                      context,
                      Icons.article_outlined,
                      '导出 Markdown',
                      '标准 .md 格式，支持图片链接',
                          () => _exportAsMarkdown(context)
                  ),
                  const SizedBox(height: 8),
                  _buildShareOption(
                      context,
                      Icons.picture_as_pdf_outlined,
                      '导出为 PDF',
                      '高保真排版，适合正式分发',
                          () => _exportAsPDF(context)
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShareOption(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: colorScheme.primary.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: colorScheme.onPrimaryContainer, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: colorScheme.outline)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 📸 方案一：长图导出 (智能分流)
  // =========================================================================
  Future<void> _exportAsImage(BuildContext context) async {
    // 📱 手机端：跳转到精美长图预览页（支持手势缩放与分享）
    if (_isMobile) {
      Navigator.pop(context);
      final deltaJson = jsonEncode(widget.viewModel.quillController.document.toDelta().toJson());
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => NoteExportPreviewPage(title: widget.noteTitle, deltaJson: deltaJson)
          )
      );
      return;
    }

    // 💻 电脑端：提取离屏图层并呼出“另存为”
    try {
      final boundary = _exportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // 等待一帧，确保离屏组件已绘制完成
      if (boundary.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      if (!context.mounted) return;
      Navigator.pop(context);

      final FileSaveLocation? result = await getSaveLocation(
        suggestedName: '${widget.noteTitle.isEmpty ? '未命名' : widget.noteTitle}.png',
        acceptedTypeGroups: [const XTypeGroup(label: 'PNG Image', extensions: ['png'])],
      );

      if (result != null) {
        String finalPath = result.path;
        if (!finalPath.toLowerCase().endsWith('.png')) finalPath += '.png';
        await File(finalPath).writeAsBytes(pngBytes);
        if (context.mounted) ToastUtils.showSuccess(context, '✨ 长图已成功保存！');
      }
    } catch (e) {
      if (context.mounted) ToastUtils.showError(context, '导出长图失败');
    }
  }

  // =========================================================================
  // 🧠 核心：Quill Delta 转标准 Markdown 引擎
  // =========================================================================
  String _generateMarkdownContent(quill.Document document, String title) {
    final delta = document.toDelta();
    final buffer = StringBuffer();
    String lineBuffer = '';

    buffer.writeln('# ${title.isEmpty ? '无标题文档' : title}\n');

    for (final op in delta.toList()) {
      if (op.data is String) {
        final text = op.data as String;
        final attrs = op.attributes ?? {};
        final lines = text.split('\n');

        for (int i = 0; i < lines.length; i++) {
          String chunk = lines[i];

          // 行内样式
          if (chunk.isNotEmpty) {
            if (attrs['bold'] == true) chunk = '**$chunk**';
            if (attrs['italic'] == true) chunk = '*$chunk*';
            if (attrs['strike'] == true) chunk = '~~$chunk~~';
            if (attrs['code'] == true) chunk = '`$chunk`';
            if (attrs['link'] != null) chunk = '[$chunk](${attrs['link']})';
            lineBuffer += chunk;
          }

          // 块级样式结算 (基于换行符)
          if (i < lines.length - 1) {
            String prefix = '';
            if (attrs['header'] == 1) prefix = '# ';
            else if (attrs['header'] == 2) prefix = '## ';
            else if (attrs['header'] == 3) prefix = '### ';
            else if (attrs['list'] == 'bullet') prefix = '- ';
            else if (attrs['list'] == 'ordered') prefix = '1. ';
            else if (attrs['blockquote'] == true) prefix = '> ';

            if (attrs['code-block'] == true) {
              buffer.write('    $lineBuffer\n');
            } else {
              buffer.write('$prefix$lineBuffer\n');
            }
            lineBuffer = '';
          }
        }
      } else if (op.data is Map) {
        // 富媒体嵌入
        final data = op.data as Map;
        if (data.containsKey('image')) {
          lineBuffer += '![图片](${data['image']})';
        } else if (data.containsKey('video')) {
          lineBuffer += '[视频](${data['video']})';
        } else if (data.containsKey('divider')) {
          lineBuffer += '\n---\n';
        }
      }
    }

    if (lineBuffer.isNotEmpty) {
      buffer.write(lineBuffer);
    }
    return buffer.toString();
  }

  // =========================================================================
  // 📝 方案二：Markdown 导出 (智能分流)
  // =========================================================================
  Future<void> _exportAsMarkdown(BuildContext context) async {
    try {
      final String markdownStr = _generateMarkdownContent(
          widget.viewModel.quillController.document,
          widget.noteTitle
      );

      if (!context.mounted) return;
      Navigator.pop(context);

      if (_isMobile) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/${widget.noteTitle.isEmpty ? '未命名' : widget.noteTitle}.md';
        await File(path).writeAsString(markdownStr);
        await Share.shareXFiles([XFile(path)], text: '分享 Markdown 文档');
      } else {
        final FileSaveLocation? res = await getSaveLocation(
          suggestedName: '${widget.noteTitle.isEmpty ? '未命名' : widget.noteTitle}.md',
          acceptedTypeGroups: [const XTypeGroup(label: 'Markdown File', extensions: ['md'])],
        );
        if (res != null) {
          String finalPath = res.path;
          if (!finalPath.toLowerCase().endsWith('.md')) finalPath += '.md';
          await File(finalPath).writeAsString(markdownStr);
          if (context.mounted) ToastUtils.showSuccess(context, '✨ Markdown 已成功导出！');
        }
      }
    } catch (e) {
      debugPrint('MD 导出失败: $e');
      if (context.mounted) ToastUtils.showError(context, '导出 Markdown 失败');
    }
  }

  // =========================================================================
  // 📑 方案四：高保真 PDF 导出 (智能分流)
  // =========================================================================
  Future<void> _exportAsPDF(BuildContext context) async {
    try {
      final boundary = _exportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      if (boundary.debugNeedsPaint) {
        await Future.delayed(const Duration(milliseconds: 50));
      }

      ui.Image uiImage = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      Uint8List pngBytes = byteData.buffer.asUint8List();

      if (!context.mounted) return;
      Navigator.pop(context);

      final pdf = pw.Document();
      final image = pw.MemoryImage(pngBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            uiImage.width.toDouble() * 72 / 300,
            uiImage.height.toDouble() * 72 / 300,
          ),
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Center(child: pw.Image(image));
          },
        ),
      );

      final pdfBytes = await pdf.save();

      if (_isMobile) {
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/${widget.noteTitle.isEmpty ? 'NoteSync_Export' : widget.noteTitle}.pdf';
        await File(filePath).writeAsBytes(pdfBytes);
        await Share.shareXFiles([XFile(filePath)], text: '分享 PDF 文档');
      } else {
        final FileSaveLocation? result = await getSaveLocation(
          suggestedName: '${widget.noteTitle.isEmpty ? '未命名文档' : widget.noteTitle}.pdf',
          acceptedTypeGroups: [const XTypeGroup(label: 'PDF Document', extensions: ['pdf'])],
        );

        if (result != null) {
          String finalPath = result.path;
          if (!finalPath.toLowerCase().endsWith('.pdf')) finalPath += '.pdf';
          await File(finalPath).writeAsBytes(pdfBytes);
          if (context.mounted) ToastUtils.showSuccess(context, '✨ PDF 已成功导出！');
        }
      }
    } catch (e) {
      debugPrint('PDF导出错误: $e');
      if (context.mounted) ToastUtils.showError(context, '导出 PDF 失败，请重试');
    }
  }
}