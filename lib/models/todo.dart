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
  // ==========================================
  // 🌟 JSON 序列化 (用于局域网和云端同步)
  // ==========================================
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'sortOrder': sortOrder,
      'categoryId': categoryId,
      'version': version,
      'lastModifiedBy': lastModifiedBy,
      'isDeleted': isDeleted,
      // 嵌套序列化子任务
      'subTasks': subTasks.map((st) => st.toMap()).toList(),
    };
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String,
      title: json['title'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      description: json['description'] as String? ?? '',
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate'] as String) : null,
      sortOrder: (json['sortOrder'] as num?)?.toDouble() ?? 0.0,
      categoryId: json['categoryId'] as String?,
      version: json['version'] as int? ?? 1,
      lastModifiedBy: json['lastModifiedBy'] as String?,
      isDeleted: json['isDeleted'] as bool? ?? false,
      // 解析嵌套的子任务
      subTasks: (json['subTasks'] as List<dynamic>?)
          ?.map((e) => SubTask.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
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