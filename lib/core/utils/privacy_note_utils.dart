import '../../models/note.dart';
import '../services/privacy_service.dart';

/// 隐私笔记工具类
/// 
/// 提供隐私笔记的加密/解密功能
class PrivacyNoteUtils {
  /// 将普通笔记转换为隐私笔记（加密内容）
  static Note encryptNote(Note note) {
    if (!PrivacyService().isUnlocked) {
      throw Exception('隐私服务未解锁，无法加密笔记');
    }

    final encryptedTitle = PrivacyService().encryptText(note.title);
    final encryptedContent = PrivacyService().encryptText(note.content);

    return note.copyWith(
      title: encryptedTitle,
      content: encryptedContent,
      isPrivate: true,
      updatedAt: DateTime.now(),
    );
  }

  /// 将隐私笔记转换为普通笔记（解密内容）
  static Note decryptNote(Note note) {
    if (!note.isPrivate) return note;
    
    if (!PrivacyService().isUnlocked) {
      // 未解锁时返回占位符
      return note.copyWith(
        title: '🔒 私密笔记',
        content: '[加密内容，请解锁查看]',
      );
    }

    final decryptedTitle = PrivacyService().decryptText(note.title);
    final decryptedContent = PrivacyService().decryptText(note.content);

    return note.copyWith(
      title: decryptedTitle,
      content: decryptedContent,
      isPrivate: false,
      updatedAt: DateTime.now(),
    );
  }

  /// 批量解密笔记（用于列表展示）
  static List<Note> decryptNotesForDisplay(List<Note> notes) {
    if (!PrivacyService().isUnlocked) {
      return notes.map((note) {
        if (!note.isPrivate) return note;
        return note.copyWith(
          title: '🔒 私密笔记',
          content: '[加密内容，请解锁查看]',
        );
      }).toList();
    }

    return notes.map((note) {
      if (!note.isPrivate) return note;
      return decryptNote(note);
    }).toList();
  }

  /// 检查笔记是否需要解锁才能查看
  static bool needsUnlock(Note note) {
    return note.isPrivate && !PrivacyService().isUnlocked;
  }

  /// 获取笔记的显示标题（不解密）
  static String getDisplayTitle(Note note) {
    if (!note.isPrivate) return note.title;
    if (PrivacyService().isUnlocked) {
      return PrivacyService().decryptText(note.title);
    }
    return '🔒 私密笔记';
  }

  /// 获取笔记的显示内容预览（不解密）
  static String getDisplayPreview(Note note) {
    if (!note.isPrivate) return note.plainText;
    if (PrivacyService().isUnlocked) {
      return PrivacyService().decryptText(note.plainText);
    }
    return '••••••';
  }
}
