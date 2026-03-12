
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:crop_image/crop_image.dart';
import 'package:path_provider/path_provider.dart';

class ImageCropPage extends StatefulWidget {
  final File imageFile;
  const ImageCropPage({super.key, required this.imageFile});

  @override
  State<ImageCropPage> createState() => _ImageCropPageState();
}

class _ImageCropPageState extends State<ImageCropPage> {
  // 核心：裁剪控制器，锁定 1:1 正方形
  final _controller = CropController(
    aspectRatio: 1,
    defaultCrop:  Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
  );
  bool _isCropping = false;

  Future<void> _cropAndSave() async {
    setState(() => _isCropping = true);
    try {
      // 1. 获取裁剪后的像素数据
      final ui.Image bitmap = await _controller.croppedBitmap();
      final data = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();

      // 2. 将字节数据保存为临时文件
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(bytes);

      // 3. 携带裁剪后的文件返回上一页
      if (mounted) Navigator.pop(context, tempFile);

    } catch (e) {
      debugPrint('纯 Flutter 裁剪失败: $e');
      if (mounted) Navigator.pop(context, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black, // 裁剪时使用纯黑背景更具沉浸感
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('调整头像', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isCropping)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))))
          else
            TextButton(
              onPressed: _cropAndSave,
              child: Text('完成', style: TextStyle(color: theme.colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: CropImage(
            controller: _controller,
            image: Image.file(widget.imageFile),
            paddingSize: 24.0,
            alwaysMove: true, // 允许自由拖拽和缩放
            // 🟢 细节：裁剪网格使用你 App 的主题色，极其优雅！
            gridColor: theme.colorScheme.primary.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}