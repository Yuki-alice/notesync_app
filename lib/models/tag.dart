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
}