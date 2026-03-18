// 文件路径: lib/models/todo.dart
import 'package:hive/hive.dart';

part 'todo.g.dart';

@HiveType(typeId: 1)
class Todo extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final bool isCompleted;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final DateTime updatedAt;

  @HiveField(5)
  final String description;

  @HiveField(6)
  final DateTime? dueDate;

  @HiveField(7)
  final double sortOrder;

  @HiveField(8)
  final bool isDeleted;

  // 🟢 新增：子任务列表，分配为 HiveField(9)
  @HiveField(9)
  final List<SubTask> subTasks;

  Todo({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.dueDate,
    this.sortOrder = 0.0,
    this.isDeleted = false,
    this.subTasks = const [], // 默认空列表
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
    bool? isDeleted,
    List<SubTask>? subTasks, // 🟢 接入 copyWith
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      // 修复之前代码这里写死 DateTime.now() 的小问题，优先使用传入的时间
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      sortOrder: sortOrder ?? this.sortOrder,
      isDeleted: isDeleted ?? this.isDeleted,
      subTasks: subTasks ?? this.subTasks, // 🟢
    );
  }
}

// 🟢 新增：子任务类。为了能存入 Hive，必须加上 @HiveType (Type ID 不能和 Todo 重复，设为 2)
@HiveType(typeId: 2)
class SubTask extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final bool isCompleted;

  SubTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  SubTask copyWith({String? id, String? title, bool? isCompleted}) {
    return SubTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  // 方便以后云端同步用到
  Map<String, dynamic> toMap() {
    return {'id': id, 'title': title, 'is_completed': isCompleted};
  }

  factory SubTask.fromMap(Map<String, dynamic> map) {
    return SubTask(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      isCompleted: map['is_completed'] ?? false,
    );
  }
}