import 'package:hive/hive.dart';
import 'dart:convert'; // 用于解析 JSON

part 'note.g.dart';

@HiveType(typeId: 0)
class Note extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String content; // 存储纯文本(旧) 或 Delta JSON字符串(新)

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime updatedAt;

  @HiveField(5)
  final List<String> tags; // 标签列表

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
  });

  // 辅助属性：判断内容是否为富文本 (简单判断是否以 JSON 数组/对象开头)
  bool get isRichText {
    final trimmed = content.trim();
    return trimmed.startsWith('[') || trimmed.startsWith('{');
  }

  // 核心方法：获取用于显示和搜索的纯文本
  // 如果是富文本 JSON，这里会提取出其中的文字部分
  String get plainText {
    if (!isRichText) return content;

    try {
      final List<dynamic> delta = jsonDecode(content);
      final buffer = StringBuffer();

      for (final op in delta) {
        if (op is Map<String, dynamic> && op.containsKey('insert')) {
          final insert = op['insert'];
          if (insert is String) {
            buffer.write(insert);
          } else {
            // 如果插入的是对象（如图片），可以用占位符代替，或者忽略
            buffer.write('[图片]');
          }
        }
      }
      return buffer.toString().trim();
    } catch (e) {
      // 解析失败则降级返回原始内容
      return content;
    }
  }

  // 格式化时间 getter
  String get formattedUpdatedAt {
    final now = DateTime.now();
    final diff = now.difference(updatedAt);

    if (diff.inDays == 0) {
      return "${updatedAt.hour.toString().padLeft(2,'0')}:${updatedAt.minute.toString().padLeft(2,'0')}";
    } else if (diff.inDays < 7) {
      return "${diff.inDays}天前";
    } else {
      return "${updatedAt.year}-${updatedAt.month.toString().padLeft(2,'0')}-${updatedAt.day.toString().padLeft(2,'0')}";
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
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
    );
  }
}