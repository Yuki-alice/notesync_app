/// 用户存储配额模型
/// 
/// 对应 Supabase 表: user_quotas
class UserQuota {
  final String id;
  final String userId;
  
  // 存储配额
  final int storageLimitMb;
  final double storageUsedMb;
  
  // 数量限制
  final int noteCountLimit;
  final int noteCountUsed;
  final int imageCountLimit;
  final int imageCountUsed;
  
  // 套餐信息
  final PlanType planType;
  final String planName;
  
  // 时间
  final DateTime? expiresAt;
  final DateTime? lastSyncAt;
  final DateTime? lastCalculatedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserQuota({
    required this.id,
    required this.userId,
    required this.storageLimitMb,
    required this.storageUsedMb,
    required this.noteCountLimit,
    required this.noteCountUsed,
    required this.imageCountLimit,
    required this.imageCountUsed,
    required this.planType,
    required this.planName,
    this.expiresAt,
    this.lastSyncAt,
    this.lastCalculatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从 Supabase 数据创建实例
  factory UserQuota.fromJson(Map<String, dynamic> json) {
    return UserQuota(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      storageLimitMb: json['storage_limit_mb'] as int? ?? 100,
      storageUsedMb: (json['storage_used_mb'] as num?)?.toDouble() ?? 0.0,
      noteCountLimit: json['note_count_limit'] as int? ?? 100,
      noteCountUsed: json['note_count_used'] as int? ?? 0,
      imageCountLimit: json['image_count_limit'] as int? ?? 500,
      imageCountUsed: json['image_count_used'] as int? ?? 0,
      planType: PlanType.fromString(json['plan_type'] as String? ?? 'free'),
      planName: json['plan_name'] as String? ?? '免费版',
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at'] as String) 
          : null,
      lastSyncAt: json['last_sync_at'] != null 
          ? DateTime.parse(json['last_sync_at'] as String) 
          : null,
      lastCalculatedAt: json['last_calculated_at'] != null 
          ? DateTime.parse(json['last_calculated_at'] as String) 
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// 转换为 Supabase 数据
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'storage_limit_mb': storageLimitMb,
      'storage_used_mb': storageUsedMb,
      'note_count_limit': noteCountLimit,
      'note_count_used': noteCountUsed,
      'image_count_limit': imageCountLimit,
      'image_count_used': imageCountUsed,
      'plan_type': planType.value,
      'plan_name': planName,
      'expires_at': expiresAt?.toIso8601String(),
      'last_sync_at': lastSyncAt?.toIso8601String(),
      'last_calculated_at': lastCalculatedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// 创建副本并修改指定字段
  UserQuota copyWith({
    String? id,
    String? userId,
    int? storageLimitMb,
    double? storageUsedMb,
    int? noteCountLimit,
    int? noteCountUsed,
    int? imageCountLimit,
    int? imageCountUsed,
    PlanType? planType,
    String? planName,
    DateTime? expiresAt,
    DateTime? lastSyncAt,
    DateTime? lastCalculatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserQuota(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      storageLimitMb: storageLimitMb ?? this.storageLimitMb,
      storageUsedMb: storageUsedMb ?? this.storageUsedMb,
      noteCountLimit: noteCountLimit ?? this.noteCountLimit,
      noteCountUsed: noteCountUsed ?? this.noteCountUsed,
      imageCountLimit: imageCountLimit ?? this.imageCountLimit,
      imageCountUsed: imageCountUsed ?? this.imageCountUsed,
      planType: planType ?? this.planType,
      planName: planName ?? this.planName,
      expiresAt: expiresAt ?? this.expiresAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastCalculatedAt: lastCalculatedAt ?? this.lastCalculatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ==================== 便捷属性 ====================

  /// 存储使用率 (0.0 - 1.0)
  double get storageUsageRatio {
    if (storageLimitMb <= 0) return 0.0;
    return (storageUsedMb / storageLimitMb).clamp(0.0, 1.0);
  }

  /// 存储使用率百分比
  int get storageUsagePercent => (storageUsageRatio * 100).round();

  /// 剩余存储空间 (MB)
  double get remainingStorageMb => (storageLimitMb - storageUsedMb).clamp(0.0, double.infinity);

  /// 是否已超限
  bool get isExceeded => storageUsedMb > storageLimitMb;

  /// 是否接近上限 (80%)
  bool get isNearLimit => storageUsageRatio >= 0.8;

  /// 是否警告级别 (90%)
  bool get isWarning => storageUsageRatio >= 0.9;

  /// 笔记数量使用率
  double get noteUsageRatio {
    if (noteCountLimit <= 0) return 0.0;
    return (noteCountUsed / noteCountLimit).clamp(0.0, 1.0);
  }

  /// 图片数量使用率
  double get imageUsageRatio {
    if (imageCountLimit <= 0) return 0.0;
    return (imageCountUsed / imageCountLimit).clamp(0.0, 1.0);
  }

  /// 套餐是否有效（未过期）
  bool get isPlanActive {
    if (expiresAt == null) return true;
    return DateTime.now().isBefore(expiresAt!);
  }

  /// 格式化的存储使用量
  String get formattedUsedStorage => _formatStorage(storageUsedMb);

  /// 格式化的存储限制
  String get formattedLimitStorage => _formatStorage(storageLimitMb.toDouble());

  /// 格式化的剩余存储
  String get formattedRemainingStorage => _formatStorage(remainingStorageMb);

  String _formatStorage(double mb) {
    if (mb < 1) {
      return '${(mb * 1024).toStringAsFixed(0)} KB';
    } else if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    } else {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
  }

  @override
  String toString() {
    return 'UserQuota(id: $id, plan: $planName, used: $formattedUsedStorage / $formattedLimitStorage)';
  }
}

/// 套餐类型枚举
enum PlanType {
  free('free', '免费版'),
  pro('pro', '专业版'),
  team('team', '团队版'),
  enterprise('enterprise', '企业版');

  final String value;
  final String displayName;

  const PlanType(this.value, this.displayName);

  factory PlanType.fromString(String value) {
    return PlanType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PlanType.free,
    );
  }

  /// 是否付费套餐
  bool get isPaid => this != PlanType.free;

  /// 是否支持 WebDAV
  bool get supportsWebdav => this == PlanType.pro || this == PlanType.team || this == PlanType.enterprise;

  /// 是否支持自定义主题
  bool get supportsCustomThemes => this == PlanType.pro || this == PlanType.team || this == PlanType.enterprise;

  /// 是否支持优先客服
  bool get supportsPrioritySupport => this == PlanType.pro || this == PlanType.team || this == PlanType.enterprise;
}

/// 存储使用日志模型
/// 
/// 对应 Supabase 表: storage_usage_logs
class StorageUsageLog {
  final String id;
  final String userId;
  final OperationType operationType;
  final ResourceType resourceType;
  final String? resourceId;
  final int bytesChanged;
  final double? storageAfterMb;
  final String? deviceId;
  final String? platform;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const StorageUsageLog({
    required this.id,
    required this.userId,
    required this.operationType,
    required this.resourceType,
    this.resourceId,
    required this.bytesChanged,
    this.storageAfterMb,
    this.deviceId,
    this.platform,
    required this.metadata,
    required this.createdAt,
  });

  factory StorageUsageLog.fromJson(Map<String, dynamic> json) {
    return StorageUsageLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      operationType: OperationType.fromString(json['operation_type'] as String),
      resourceType: ResourceType.fromString(json['resource_type'] as String),
      resourceId: json['resource_id'] as String?,
      bytesChanged: json['bytes_changed'] as int,
      storageAfterMb: (json['storage_after_mb'] as num?)?.toDouble(),
      deviceId: json['device_id'] as String?,
      platform: json['platform'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// 操作类型
enum OperationType {
  upload('upload'),
  delete('delete'),
  update('update'),
  sync('sync'),
  cleanup('cleanup');

  final String value;
  const OperationType(this.value);

  factory OperationType.fromString(String value) {
    return OperationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => OperationType.upload,
    );
  }
}

/// 资源类型
enum ResourceType {
  note('note'),
  image('image'),
  todo('todo'),
  category('category'),
  tag('tag'),
  attachment('attachment');

  final String value;
  const ResourceType(this.value);

  factory ResourceType.fromString(String value) {
    return ResourceType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ResourceType.note,
    );
  }
}

/// 套餐配置模型
/// 
/// 对应 Supabase 表: plan_configs
class PlanConfig {
  final String id;
  final PlanType planType;
  final String planName;
  final String? planDescription;
  final int storageLimitMb;
  final int? noteCountLimit;
  final int? imageCountLimit;
  final int? todoCountLimit;
  final int? categoryCountLimit;
  final int? tagCountLimit;
  final Map<String, dynamic> features;
  final int? monthlyPriceCents;
  final int? yearlyPriceCents;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlanConfig({
    required this.id,
    required this.planType,
    required this.planName,
    this.planDescription,
    required this.storageLimitMb,
    this.noteCountLimit,
    this.imageCountLimit,
    this.todoCountLimit,
    this.categoryCountLimit,
    this.tagCountLimit,
    required this.features,
    this.monthlyPriceCents,
    this.yearlyPriceCents,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlanConfig.fromJson(Map<String, dynamic> json) {
    return PlanConfig(
      id: json['id'] as String,
      planType: PlanType.fromString(json['plan_type'] as String),
      planName: json['plan_name'] as String,
      planDescription: json['plan_description'] as String?,
      storageLimitMb: json['storage_limit_mb'] as int,
      noteCountLimit: json['note_count_limit'] as int?,
      imageCountLimit: json['image_count_limit'] as int?,
      todoCountLimit: json['todo_count_limit'] as int?,
      categoryCountLimit: json['category_count_limit'] as int?,
      tagCountLimit: json['tag_count_limit'] as int?,
      features: json['features'] as Map<String, dynamic>? ?? {},
      monthlyPriceCents: json['monthly_price_cents'] as int?,
      yearlyPriceCents: json['yearly_price_cents'] as int?,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// 格式化的月付价格
  String? get formattedMonthlyPrice {
    if (monthlyPriceCents == null || monthlyPriceCents == 0) return null;
    return '¥${(monthlyPriceCents! / 100).toStringAsFixed(0)}';
  }

  /// 格式化的年付价格
  String? get formattedYearlyPrice {
    if (yearlyPriceCents == null || yearlyPriceCents == 0) return null;
    return '¥${(yearlyPriceCents! / 100).toStringAsFixed(0)}';
  }

  /// 年付月均价格
  String? get formattedYearlyMonthlyPrice {
    if (yearlyPriceCents == null || yearlyPriceCents == 0) return null;
    return '¥${(yearlyPriceCents! / 100 / 12).toStringAsFixed(1)}';
  }

  /// 年付节省百分比
  int? get yearlySavingsPercent {
    if (monthlyPriceCents == null || yearlyPriceCents == null) return null;
    if (monthlyPriceCents == 0) return null;
    final monthlyTotal = monthlyPriceCents! * 12;
    final savings = ((monthlyTotal - yearlyPriceCents!) / monthlyTotal * 100).round();
    return savings > 0 ? savings : null;
  }
}

/// 配额检查结果
class QuotaCheckResult {
  final bool canProceed;
  final QuotaLimitType? limitType;
  final String? message;
  final double? requiredSpace;
  final double? availableSpace;

  const QuotaCheckResult({
    required this.canProceed,
    this.limitType,
    this.message,
    this.requiredSpace,
    this.availableSpace,
  });

  factory QuotaCheckResult.success() {
    return const QuotaCheckResult(canProceed: true);
  }

  factory QuotaCheckResult.failed({
    required QuotaLimitType limitType,
    required String message,
    double? requiredSpace,
    double? availableSpace,
  }) {
    return QuotaCheckResult(
      canProceed: false,
      limitType: limitType,
      message: message,
      requiredSpace: requiredSpace,
      availableSpace: availableSpace,
    );
  }

  bool get isStorageLimit => limitType == QuotaLimitType.storage;
  bool get isNoteLimit => limitType == QuotaLimitType.noteCount;
  bool get isImageLimit => limitType == QuotaLimitType.imageCount;
}

/// 配额限制类型
enum QuotaLimitType {
  storage,
  noteCount,
  imageCount,
  todoCount,
}
