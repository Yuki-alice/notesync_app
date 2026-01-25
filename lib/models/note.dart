import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

part 'note.g.dart'; // 确保执行过 build_runner 生成该文件

@HiveType(typeId: 0)
class Note extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String content;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime updatedAt;

  @HiveField(5)
  String category; // 分类字段，默认值 general

  @HiveField(6)
  List<String> tags; // 标签字段，默认空列表

  // 可选：补充其他通用字段（按需）
  @HiveField(7)
  bool isPinned;

  @HiveField(8)
  bool isArchived;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.category = 'general',
    this.tags = const [],
    this.isPinned = false,
    this.isArchived = false,
  });


  String get formattedCreatedAt => DateFormat('yyyy-MM-dd HH:mm').format(createdAt);
  String get formattedUpdatedAt => DateFormat('yyyy-MM-dd HH:mm').format(updatedAt);


  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? category,
    List<String>? tags,
    bool? isPinned,
    bool? isArchived,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      category: category ?? this.category,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  // 兼容 Repository 的 toJson 方法（Hive 可序列化，但 Repository 仍需 JSON 转换）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'category': category,
      'tags': tags,
      'isPinned': isPinned,
      'isArchived': isArchived,
    };
  }

  // 兼容 Repository 的 fromJson 静态方法
  static Note fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      category: json['category'] as String? ?? 'general',
      tags: List<String>.from(json['tags'] ?? []),
      isPinned: json['isPinned'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
    );
  }
}