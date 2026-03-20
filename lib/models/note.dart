import 'dart:convert';
import '../utils/date_formatter.dart';
import 'package:isar/isar.dart';
part 'note.g.dart';

@collection
class Note {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String id;

  String title;
  String content;
  DateTime createdAt;
  DateTime updatedAt;
  List<String> tags;
  String? category;
  bool isPinned;
  bool isDeleted;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.category,
    this.isPinned = false,
    this.isDeleted = false,
  });

  bool get isRichText {
    final trimmed = content.trim();
    return trimmed.startsWith('[') || trimmed.startsWith('{');
  }

  String get plainText {
    if (!isRichText) return content;
    try {
      final List<dynamic> delta = jsonDecode(content);
      final buffer = StringBuffer();
      for (final op in delta) {
        if (op is Map<String, dynamic> && op.containsKey('insert')) {
          final insert = op['insert'];
          if (insert is String) buffer.write(insert);
        }
      }
      return buffer.toString();
    } catch (e) {
      return '';
    }
  }
  /// 获取第一张图片的路径（用于卡片封面展示）
  String? get firstImagePath {
    final paths = extractAllImagePaths(content);
    return paths.isNotEmpty ? paths.first : null;
  }

  /// 格式化更新时间 (使用相对时间：如"刚刚", "3小时前"，让笔记列表更具呼吸感)
  String get formattedUpdatedAt {
    return DateFormatter.formatRelativeTime(updatedAt);
  }

  /// 格式化创建时间 (使用绝对时间)
  String get formattedCreatedAt {
    return DateFormatter.formatFullDateTime(createdAt);
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    String? category,
    bool clearCategory = false,
    bool? isPinned,
    bool? isDeleted,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      category: clearCategory ? null : (category ?? this.category),
      isPinned: isPinned ?? this.isPinned,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  static List<String> extractAllImagePaths(String content) {
    final List<String> paths = [];
    final trimmed = content.trim();
    if (!trimmed.startsWith('[') && !trimmed.startsWith('{')) return paths;

    try {
      final List<dynamic> delta = jsonDecode(content);
      for (final op in delta) {
        if (op is Map<String, dynamic> && op.containsKey('insert')) {
          final insert = op['insert'];
          if (insert is Map<String, dynamic> && insert.containsKey('image')) {
            paths.add(insert['image'] as String);
          }
        }
      }
    } catch (e) {
      // 忽略解析错误
    }
    return paths;
  }
}