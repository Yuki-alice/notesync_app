import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../../models/user_quota.dart';
import '../../models/note.dart';

/// 存储配额服务
/// 
/// 负责：
/// 1. 获取用户配额信息
/// 2. 检查配额限制
/// 3. 记录存储使用日志
/// 4. 刷新配额统计
class StorageQuotaService {
  final _supabase = Supabase.instance.client;
  final _deviceInfo = DeviceInfoPlugin();

  // 缓存
  UserQuota? _cachedQuota;
  DateTime? _lastFetchTime;
  static const Duration _cacheValidity = Duration(minutes: 5);

  // 设备标识缓存
  String? _deviceId;

  /// 获取当前用户配额
  /// 
  /// [forceRefresh] 是否强制刷新缓存
  Future<UserQuota?> getUserQuota({bool forceRefresh = false}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    // 检查缓存有效性
    if (!forceRefresh && 
        _cachedQuota != null && 
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheValidity) {
      return _cachedQuota;
    }

    try {
      final response = await _supabase
          .from('user_quotas')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) {
        // 如果用户没有配额记录，创建一个默认的
        return await _createDefaultQuota(user.id);
      }

      // 🌟 实时计算实际使用量
      final usageStats = await _calculateRealUsage(user.id);
      
      // 更新响应数据中的使用量
      final updatedResponse = Map<String, dynamic>.from(response);
      updatedResponse['storage_used_mb'] = usageStats['storage_used_mb'];
      updatedResponse['note_count_used'] = usageStats['note_count_used'];
      updatedResponse['image_count_used'] = usageStats['image_count_used'];
      updatedResponse['last_calculated_at'] = DateTime.now().toIso8601String();

      _cachedQuota = UserQuota.fromJson(updatedResponse);
      _lastFetchTime = DateTime.now();
      return _cachedQuota;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取用户配额失败: $e');
      }
      return _cachedQuota;
    }
  }

  /// 🌟 实时计算用户实际使用量
  Future<Map<String, dynamic>> _calculateRealUsage(String userId) async {
    try {
      // 1. 计算笔记内容大小
      final notesResponse = await _supabase
          .from('notes')
          .select('content')
          .eq('user_id', userId)
          .eq('is_deleted', false);
      
      double notesSizeMb = 0;
      int noteCount = 0;
      if (notesResponse != null) {
        noteCount = (notesResponse as List).length;
        for (final note in notesResponse) {
          final content = note['content'] as String? ?? '';
          notesSizeMb += (content.length * 2) / (1024 * 1024); // UTF-16 估算
        }
      }

      // 2. 计算图片大小（使用现有的 attachments 表）
      final imagesResponse = await _supabase
          .from('attachments')
          .select('file_size')
          .eq('user_id', userId);
      
      double imagesSizeMb = 0;
      int imageCount = 0;
      if (imagesResponse != null) {
        imageCount = (imagesResponse as List).length;
        for (final img in imagesResponse) {
          final fileSize = img['file_size'] as int? ?? 0;
          imagesSizeMb += fileSize / (1024 * 1024);
        }
      }

      final totalStorageMb = notesSizeMb + imagesSizeMb;

      if (kDebugMode) {
        print('📊 配额计算: 笔记 $noteCount 篇 (${notesSizeMb.toStringAsFixed(2)} MB), '
              '图片 $imageCount 张 (${imagesSizeMb.toStringAsFixed(2)} MB), '
              '总计 ${totalStorageMb.toStringAsFixed(2)} MB');
      }

      return {
        'storage_used_mb': totalStorageMb,
        'note_count_used': noteCount,
        'image_count_used': imageCount,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ 计算使用量失败: $e');
      }
      return {
        'storage_used_mb': 0.0,
        'note_count_used': 0,
        'image_count_used': 0,
      };
    }
  }

  /// 创建默认配额记录
  Future<UserQuota?> _createDefaultQuota(String userId) async {
    try {
      final response = await _supabase
          .from('user_quotas')
          .insert({
            'user_id': userId,
            'storage_limit_mb': 100,
            'storage_used_mb': 0,
            'note_count_limit': 100,
            'note_count_used': 0,
            'image_count_limit': 500,
            'image_count_used': 0,
            'plan_type': 'free',
            'plan_name': '免费版',
          })
          .select()
          .single();

      return UserQuota.fromJson(response);
    } catch (e) {
      if (kDebugMode) {
        print('❌ 创建默认配额失败: $e');
      }
      return null;
    }
  }

  /// 检查是否有足够的存储空间
  /// 
  /// [requiredBytes] 需要的字节数
  /// [resourceType] 资源类型
  Future<QuotaCheckResult> checkStorageQuota({
    required int requiredBytes,
    ResourceType resourceType = ResourceType.note,
  }) async {
    final quota = await getUserQuota();
    if (quota == null) {
      return QuotaCheckResult.failed(
        limitType: QuotaLimitType.storage,
        message: '无法获取配额信息，请检查网络连接',
      );
    }

    final requiredMb = requiredBytes / 1024 / 1024;
    final projectedUsage = quota.storageUsedMb + requiredMb;

    // 检查存储限制
    if (projectedUsage > quota.storageLimitMb) {
      return QuotaCheckResult.failed(
        limitType: QuotaLimitType.storage,
        message: '存储空间不足，需要 ${_formatBytes(requiredBytes)}，'
                 '剩余 ${quota.formattedRemainingStorage}',
        requiredSpace: requiredMb,
        availableSpace: quota.remainingStorageMb,
      );
    }

    return QuotaCheckResult.success();
  }

  /// 检查笔记数量限制
  Future<QuotaCheckResult> checkNoteCountQuota({
    int additionalNotes = 1,
  }) async {
    final quota = await getUserQuota();
    if (quota == null) {
      return QuotaCheckResult.failed(
        limitType: QuotaLimitType.noteCount,
        message: '无法获取配额信息',
      );
    }

    // 如果限制为0或null，表示无限制
    if (quota.noteCountLimit <= 0) {
      return QuotaCheckResult.success();
    }

    final projectedCount = quota.noteCountUsed + additionalNotes;
    if (projectedCount > quota.noteCountLimit) {
      return QuotaCheckResult.failed(
        limitType: QuotaLimitType.noteCount,
        message: '笔记数量已达上限 (${quota.noteCountLimit}条)，'
                 '请升级套餐或删除不需要的笔记',
        requiredSpace: additionalNotes.toDouble(),
        availableSpace: (quota.noteCountLimit - quota.noteCountUsed).toDouble(),
      );
    }

    return QuotaCheckResult.success();
  }

  /// 检查图片数量限制
  Future<QuotaCheckResult> checkImageCountQuota({
    int additionalImages = 1,
  }) async {
    final quota = await getUserQuota();
    if (quota == null) {
      return QuotaCheckResult.failed(
        limitType: QuotaLimitType.imageCount,
        message: '无法获取配额信息',
      );
    }

    if (quota.imageCountLimit <= 0) {
      return QuotaCheckResult.success();
    }

    final projectedCount = quota.imageCountUsed + additionalImages;
    if (projectedCount > quota.imageCountLimit) {
      return QuotaCheckResult.failed(
        limitType: QuotaLimitType.imageCount,
        message: '图片数量已达上限 (${quota.imageCountLimit}张)，'
                 '请升级套餐或清理不需要的图片',
        requiredSpace: additionalImages.toDouble(),
        availableSpace: (quota.imageCountLimit - quota.imageCountUsed).toDouble(),
      );
    }

    return QuotaCheckResult.success();
  }

  /// 综合检查：上传笔记前的完整配额检查
  Future<QuotaCheckResult> checkBeforeUploadNote({
    required Note note,
    List<File>? images,
  }) async {
    // 1. 检查笔记数量
    final noteCheck = await checkNoteCountQuota();
    if (!noteCheck.canProceed) return noteCheck;

    // 2. 计算所需存储空间
    int requiredBytes = note.content.length * 2; // 粗略估计
    int imageCount = images?.length ?? 0;

    // 计算图片大小
    if (images != null) {
      for (final image in images) {
        if (await image.exists()) {
          requiredBytes += await image.length();
        }
      }
    }

    // 3. 检查存储空间
    final storageCheck = await checkStorageQuota(
      requiredBytes: requiredBytes,
      resourceType: ResourceType.note,
    );
    if (!storageCheck.canProceed) return storageCheck;

    // 4. 检查图片数量
    if (imageCount > 0) {
      final imageCheck = await checkImageCountQuota(additionalImages: imageCount);
      if (!imageCheck.canProceed) return imageCheck;
    }

    return QuotaCheckResult.success();
  }

  /// 记录存储使用日志
  Future<void> logStorageUsage({
    required OperationType operationType,
    required ResourceType resourceType,
    required int bytesChanged,
    String? resourceId,
    Map<String, dynamic> metadata = const {},
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final deviceId = await _getDeviceId();
      final platform = _getPlatform();

      await _supabase.from('storage_usage_logs').insert({
        'user_id': user.id,
        'operation_type': operationType.value,
        'resource_type': resourceType.value,
        'resource_id': resourceId,
        'bytes_changed': bytesChanged,
        'device_id': deviceId,
        'platform': platform,
        'metadata': metadata,
      });

      // 清除缓存，下次获取时会重新加载
      _cachedQuota = null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 记录存储日志失败: $e');
      }
    }
  }

  /// 刷新用户配额统计
  /// 
  /// 调用 Supabase RPC 函数重新计算
  Future<UserQuota?> refreshQuota() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      await _supabase.rpc('refresh_user_quota', params: {'p_user_id': user.id});
      return await getUserQuota(forceRefresh: true);
    } catch (e) {
      if (kDebugMode) {
        print('❌ 刷新配额失败: $e');
      }
      return _cachedQuota;
    }
  }

  /// 获取所有可用套餐配置
  Future<List<PlanConfig>> getPlanConfigs() async {
    try {
      final response = await _supabase
          .from('plan_configs')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      return (response as List)
          .map((json) => PlanConfig.fromJson(json))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取套餐配置失败: $e');
      }
      return _getDefaultPlanConfigs();
    }
  }

  /// 获取存储使用历史（用于图表）
  Future<List<Map<String, dynamic>>> getStorageHistory({
    int days = 30,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('storage_quota_history')
          .select()
          .eq('user_id', user.id)
          .gte('recorded_date', DateTime.now().subtract(Duration(days: days)).toIso8601String())
          .order('recorded_date', ascending: true);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取存储历史失败: $e');
      }
      return [];
    }
  }

  /// 获取最近的操作日志
  Future<List<StorageUsageLog>> getRecentLogs({
    int limit = 50,
    OperationType? operationType,
    ResourceType? resourceType,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      var query = _supabase
          .from('storage_usage_logs')
          .select()
          .eq('user_id', user.id);

      if (operationType != null) {
        query = query.eq('operation_type', operationType.value);
      }
      if (resourceType != null) {
        query = query.eq('resource_type', resourceType.value);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);
      return (response as List)
          .map((json) => StorageUsageLog.fromJson(json))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取操作日志失败: $e');
      }
      return [];
    }
  }

  /// 清除缓存
  void clearCache() {
    _cachedQuota = null;
    _lastFetchTime = null;
  }

  // ==================== 私有方法 ====================

  /// 获取设备标识
  Future<String> _getDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        _deviceId = info.id;
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        _deviceId = info.identifierForVendor;
      } else if (Platform.isWindows) {
        final info = await _deviceInfo.windowsInfo;
        _deviceId = info.deviceId;
      } else if (Platform.isMacOS) {
        final info = await _deviceInfo.macOsInfo;
        _deviceId = info.systemGUID;
      } else if (Platform.isLinux) {
        final info = await _deviceInfo.linuxInfo;
        _deviceId = info.machineId;
      } else {
        _deviceId = 'unknown';
      }
    } catch (e) {
      _deviceId = 'unknown';
    }

    return _deviceId ?? 'unknown';
  }

  /// 获取平台标识
  String _getPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// 格式化字节数
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
  }

  /// 默认套餐配置（网络失败时使用）
  List<PlanConfig> _getDefaultPlanConfigs() {
    final now = DateTime.now();
    return [
      PlanConfig(
        id: 'default-free',
        planType: PlanType.free,
        planName: '免费版',
        planDescription: '适合轻度使用的个人用户',
        storageLimitMb: 100,
        noteCountLimit: 100,
        imageCountLimit: 500,
        todoCountLimit: 50,
        features: {'sync': true, 'webdav': false, 'priority_support': false},
        monthlyPriceCents: 0,
        yearlyPriceCents: 0,
        isActive: true,
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      ),
      PlanConfig(
        id: 'default-pro',
        planType: PlanType.pro,
        planName: '专业版',
        planDescription: '适合重度笔记用户',
        storageLimitMb: 2048,
        features: {'sync': true, 'webdav': true, 'priority_support': true},
        monthlyPriceCents: 1200,
        yearlyPriceCents: 10800,
        isActive: true,
        sortOrder: 2,
        createdAt: now,
        updatedAt: now,
      ),
      PlanConfig(
        id: 'default-team',
        planType: PlanType.team,
        planName: '团队版',
        planDescription: '适合小团队协作',
        storageLimitMb: 10240,
        features: {'sync': true, 'webdav': true, 'priority_support': true, 'team_collab': true},
        monthlyPriceCents: 4800,
        yearlyPriceCents: 43200,
        isActive: true,
        sortOrder: 3,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}

/// 存储配额异常
class QuotaExceededException implements Exception {
  final QuotaLimitType limitType;
  final String message;
  final double? required;
  final double? available;

  QuotaExceededException({
    required this.limitType,
    required this.message,
    this.required,
    this.available,
  });

  @override
  String toString() => 'QuotaExceededException: $message';
}
