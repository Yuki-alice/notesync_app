import 'package:isar/isar.dart';
part 'tag.g.dart';

@collection
class Tag {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String id;

  String name;
  String? color;
  bool isDeleted;
  DateTime createdAt;

  Tag({
    required this.id,
    required this.name,
    this.color,
    this.isDeleted = false,
    required this.createdAt,
  });

  Tag copyWith({
    String? id,
    String? name,
    String? color,
    bool? isDeleted,
    DateTime? createdAt,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ==========================================
  // 🌟 JSON 序列化 (用于局域网和云端同步)
  // ==========================================
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'isDeleted': isDeleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String?,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}