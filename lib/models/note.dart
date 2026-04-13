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


  List<String> tagIds;
  @Index()
  String? categoryId;

  // 🌟 V2 核心：注入版本控制引擎！
  int version;
  String? lastModifiedBy;

  bool isPinned;
  bool isDeleted;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.tagIds = const [],
    this.categoryId,
    this.version = 1,
    this.lastModifiedBy,
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

  String? get firstImagePath {
    final paths = extractAllImagePaths(content);
    return paths.isNotEmpty ? paths.first : null;
  }

  String get formattedUpdatedAt {
    return DateFormatter.formatRelativeTime(updatedAt);
  }

  String get formattedCreatedAt {
    return DateFormatter.formatFullDateTime(createdAt);
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tagIds,
    String? categoryId,
    bool clearCategory = false,
    int? version,
    String? lastModifiedBy,
    bool? isPinned,
    bool? isDeleted,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tagIds: tagIds ?? this.tagIds,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      version: version ?? this.version,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
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
    } catch (e) {}
    return paths;
  }
  // ==========================================
  // 🌟 JSON 序列化 (用于局域网和云端同步)
  // ==========================================
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'tagIds': tagIds,
      'categoryId': categoryId,
      'version': version,
      'lastModifiedBy': lastModifiedBy,
      'isPinned': isPinned,
      'isDeleted': isDeleted,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      tagIds: (json['tagIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      categoryId: json['categoryId'] as String?,
      version: json['version'] as int? ?? 1,
      lastModifiedBy: json['lastModifiedBy'] as String?,
      isPinned: json['isPinned'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
    );
  }
}
