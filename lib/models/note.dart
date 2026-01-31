import 'package:hive/hive.dart';
import 'dart:convert';

part 'note.g.dart';

@HiveType(typeId: 0)
class Note extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String content;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime updatedAt;

  @HiveField(5)
  final List<String> tags;

  @HiveField(6)
  final String? category;

  // 🔴 新增：是否置顶
  @HiveField(7)
  final bool isPinned;

  @HiveField(8)
  final bool isDeleted;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.category,
    this.isPinned = false, // 默认为 false
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
          // 只有当插入内容是 String 时才追加
          // 遇到 Map (即图片对象) 直接跳过，不写入任何占位符
          if (insert is String) {
            buffer.write(insert);
          }
        }
      }
      // 将连续的换行符或空白替换为单个空格，防止摘要出现大段留白
      return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    } catch (e) {
      return content;
    }
  }

  String? get firstImagePath {
    if (!isRichText) return null;
    try {
      final List<dynamic> delta = jsonDecode(content);
      for (final op in delta) {
        if (op is Map<String, dynamic> && op.containsKey('insert')) {
          final insert = op['insert'];
          if (insert is Map && insert.containsKey('image')) {
            return insert['image'] as String;
          }
        }
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  String get formattedUpdatedAt {
    final now = DateTime.now();
    // 获取“日历日”的午夜时间，确保计算的是“跨了几天”而不是“差了多少小时”
    final today = DateTime(now.year, now.month, now.day);
    final noteDate = DateTime(updatedAt.year, updatedAt.month, updatedAt.day);

    // 计算相差的天数
    final diffDays = today.difference(noteDate).inDays;

    // 格式化具体时间 (HH:mm)
    final timeStr = "${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}";

    if (diffDays == 0) {
      return "今日 $timeStr";
    } else if (diffDays == 1) {
      return "昨日 $timeStr";
    } else if (diffDays == 2) {
      return "前日 $timeStr";
    } else if (diffDays > 2 && diffDays < 7) {
      // 7天内显示星期几
      const weekDays = ["", "周一", "周二", "周三", "周四", "周五", "周六", "周日"];
      final weekStr = weekDays[updatedAt.weekday];
      return "$weekStr $timeStr";
    } else {
      // 超过一周，只显示年月日
      return "${updatedAt.year}/${updatedAt.month.toString().padLeft(2, '0')}/${updatedAt.day.toString().padLeft(2, '0')}";
    }
  }

  String get formattedCreatedAt {
    return "${createdAt.year}-${createdAt.month.toString().padLeft(2,'0')}-${createdAt.day.toString().padLeft(2,'0')} ${createdAt.hour.toString().padLeft(2,'0')}:${createdAt.minute.toString().padLeft(2,'0')}";
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    String? category,
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
      category: category ?? this.category,
      isPinned: isPinned ?? this.isPinned,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}