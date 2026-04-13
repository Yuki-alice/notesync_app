import 'package:isar/isar.dart';
part 'category.g.dart';

@collection
class Category {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String id;

  String name;
  String? color;
  String? icon;
  double sortOrder;
  bool isDeleted;
  DateTime createdAt;
  DateTime updatedAt;

  Category({
    required this.id,
    required this.name,
    this.color,
    this.icon,
    this.sortOrder = 0.0,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Category copyWith({
    String? id,
    String? name,
    String? color,
    String? icon,
    double? sortOrder,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
      'icon': icon,
      'sortOrder': sortOrder,
      'isDeleted': isDeleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toDouble() ?? 0.0,
      isDeleted: json['isDeleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}