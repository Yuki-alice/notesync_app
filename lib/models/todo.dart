import 'package:isar/isar.dart';
part 'todo.g.dart';

@collection
class Todo {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String id;

  String title;
  bool isCompleted;
  DateTime createdAt;
  DateTime updatedAt;
  String description;
  DateTime? dueDate;
  double sortOrder;

  // 🌟 V2 核心：关联分类与版本控制
  String? categoryId;
  int version;
  String? lastModifiedBy;

  bool isDeleted;
  List<SubTask> subTasks;

  Todo({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.dueDate,
    this.sortOrder = 0.0,
    this.categoryId,
    this.version = 1,
    this.lastModifiedBy,
    this.isDeleted = false,
    this.subTasks = const [],
  });

  Todo copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    DateTime? dueDate,
    double? sortOrder,
    String? categoryId,
    bool clearCategory = false,
    int? version,
    String? lastModifiedBy,
    bool? isDeleted,
    List<SubTask>? subTasks,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      sortOrder: sortOrder ?? this.sortOrder,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      version: version ?? this.version,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      isDeleted: isDeleted ?? this.isDeleted,
      subTasks: subTasks ?? this.subTasks,
    );
  }
}

@embedded
class SubTask {
  String id;
  String title;
  bool isCompleted;

  SubTask({
    this.id = '',
    this.title = '',
    this.isCompleted = false,
  });

  SubTask copyWith({String? id, String? title, bool? isCompleted}) {
    return SubTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'is_completed': isCompleted,
    };
  }

  factory SubTask.fromMap(Map<String, dynamic> map) {
    return SubTask(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      isCompleted: map['is_completed'] ?? false,
    );
  }
}