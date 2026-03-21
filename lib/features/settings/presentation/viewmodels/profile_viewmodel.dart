import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/auth_provider.dart';
import '../views/image_crop_page.dart';

class ProfileViewModel extends ChangeNotifier {
  final AuthProvider _authProvider;
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  File? _localSelectedImage;

  bool get isLoading => _isLoading;
  File? get localSelectedImage => _localSelectedImage;

  ProfileViewModel(this._authProvider);

  // 🟢 1. 从相册选择并跳转到自定义裁剪页
  Future<void> pickAndCropImage(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200);

      if (pickedFile != null && context.mounted) {
        // 🚀 核心改动：不再调用容易崩溃的原生裁剪器，而是跳转到我们的纯 Flutter 页面
        final File? croppedFile = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImageCropPage(imageFile: File(pickedFile.path)),
          ),
        );

        // 如果用户完成了裁剪
        if (croppedFile != null) {
          _localSelectedImage = croppedFile;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ 选择/裁剪图片失败: $e');
    }
  }

  // 🌟 修改：加入 bio 参数
  Future<String?> saveProfile(String newNickname, String? birthday, String? bio) async {
    if (newNickname.trim().isEmpty) return '昵称不能为空哦';

    _isLoading = true;
    notifyListeners();

    try {
      String? finalAvatarUrl;
      String? finalLocalPath;
      final userId = _authProvider.currentUser!.id;

      if (_localSelectedImage != null) {
        final fileExt = _localSelectedImage!.path.split('.').last;
        final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        try {
          final directory = await getApplicationDocumentsDirectory();
          final localFile = await _localSelectedImage!.copy('${directory.path}/$fileName');
          finalLocalPath = localFile.path;
        } catch (e) {
          debugPrint('⚠️ 本地头像备份失败: $e');
        }

        await _supabase.storage.from('avatars').upload(fileName, _localSelectedImage!);
        finalAvatarUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);
      }

      // 🌟 传递 bio 给状态管家
      await _authProvider.updateProfile(
        nickname: newNickname.trim(),
        avatarUrl: finalAvatarUrl,
        birthday: birthday,
        localPath: finalLocalPath,
        bio: bio?.trim(),
      );

      _cleanupOldAvatars(userId);
      return null;
    } catch (e) {
      debugPrint('❌ 保存资料失败: $e');
      return '保存失败，请稍后重试';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 🟢 自动清理旧头像逻辑 (保留最新的 2 张)
  Future<void> _cleanupOldAvatars(String userId) async {
    try {
      final files = await _supabase.storage.from('avatars').list();
      final userAvatars = files.where((file) => file.name.startsWith('$userId-')).toList();

      if (userAvatars.length > 2) {
        userAvatars.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
        final filesToDelete = userAvatars.skip(2).map((f) => f.name).toList();

        if (filesToDelete.isNotEmpty) {
          await _supabase.storage.from('avatars').remove(filesToDelete);
          debugPrint('🗑️ 云端存储优化：成功清理了 ${filesToDelete.length} 个旧头像文件');
        }
      }
    } catch (e) {
      debugPrint('⚠️ 清理旧头像失败: $e');
    }
  }

  void clearLocalImage() {
    _localSelectedImage = null;
    notifyListeners();
  }
}