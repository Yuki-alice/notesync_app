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
}