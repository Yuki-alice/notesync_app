import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../models/note.dart';
import '../../models/user_quota.dart';
import 'storage_quota_service.dart';

/// 同步配额验证器
/// 
/// 在同步流程中集成配额检查，防止用户超出存储限制
/// 这个类作为中间层，不直接修改原有同步服务
class SyncQuotaValidator {
  final StorageQuotaService _quotaService = StorageQuotaService();

  /// 验证批量推送笔记的配额
  /// 
  /// [notes] 要推送的笔记列表
  /// [imagesToUpload] 要上传的图片文件列表
  /// 
  /// 返回验证结果，包含是否可以继续同步
  Future<SyncQuotaValidationResult> validatePushNotes({
    required List<Note> notes,
    List<File>? imagesToUpload,
  }) async {
    if (notes.isEmpty && (imagesToUpload == null || imagesToUpload.isEmpty)) {
      return SyncQuotaValidationResult.canProceed();
    }

    // 1. 检查笔记数量配额
    final noteCheck = await _quotaService.checkNoteCountQuota(
      additionalNotes: notes.where((n) => !n.isDeleted).length,
    );
    if (!noteCheck.canProceed) {
      return SyncQuotaValidationResult.failed(
        reason: SyncBlockReason.noteCountLimit,
        message: noteCheck.message ?? '笔记数量已达上限',
        quotaCheckResult: noteCheck,
      );
    }

    // 2. 计算所需存储空间
    int totalBytesNeeded = 0;

    // 笔记内容大小
    for (final note in notes) {
      // 估算：内容长度 * 2（UTF-16）+ 元数据开销
      totalBytesNeeded += (note.title.length + note.content.length) * 2 + 1024;
    }

    // 图片大小
    int imageCount = 0;
    if (imagesToUpload != null) {
      for (final image in imagesToUpload) {
        if (await image.exists()) {
          totalBytesNeeded += await image.length();
          imageCount++;
        }
      }
    }

    // 3. 检查存储空间配额
    final storageCheck = await _quotaService.checkStorageQuota(
      requiredBytes: totalBytesNeeded,
      resourceType: ResourceType.note,
    );
    if (!storageCheck.canProceed) {
      return SyncQuotaValidationResult.failed(
        reason: SyncBlockReason.storageLimit,
        message: storageCheck.message ?? '存储空间不足',
        quotaCheckResult: storageCheck,
        requiredBytes: totalBytesNeeded,
      );
    }

    // 4. 检查图片数量配额
    if (imageCount > 0) {
      final imageCheck = await _quotaService.checkImageCountQuota(
        additionalImages: imageCount,
      );
      if (!imageCheck.canProceed) {
        return SyncQuotaValidationResult.failed(
          reason: SyncBlockReason.imageCountLimit,
          message: imageCheck.message ?? '图片数量已达上限',
          quotaCheckResult: imageCheck,
        );
      }
    }

    return SyncQuotaValidationResult.canProceed(requiredBytes: totalBytesNeeded);
  }

  /// 验证单个笔记上传
  Future<SyncQuotaValidationResult> validateSingleNoteUpload({
    required Note note,
    List<File>? images,
  }) async {
    return validatePushNotes(
      notes: [note],
      imagesToUpload: images,
    );
  }

  /// 验证图片上传
  Future<SyncQuotaValidationResult> validateImageUpload({
    required List<File> images,
  }) async {
    int totalBytes = 0;
    for (final image in images) {
      if (await image.exists()) {
        totalBytes += await image.length();
      }
    }

    // 检查存储空间
    final storageCheck = await _quotaService.checkStorageQuota(
      requiredBytes: totalBytes,
      resourceType: ResourceType.image,
    );
    if (!storageCheck.canProceed) {
      return SyncQuotaValidationResult.failed(
        reason: SyncBlockReason.storageLimit,
        message: storageCheck.message ?? '存储空间不足，无法上传图片',
        quotaCheckResult: storageCheck,
        requiredBytes: totalBytes,
      );
    }

    // 检查图片数量
    final imageCheck = await _quotaService.checkImageCountQuota(
      additionalImages: images.length,
    );
    if (!imageCheck.canProceed) {
      return SyncQuotaValidationResult.failed(
        reason: SyncBlockReason.imageCountLimit,
        message: imageCheck.message ?? '图片数量已达上限',
        quotaCheckResult: imageCheck,
      );
    }

    return SyncQuotaValidationResult.canProceed(requiredBytes: totalBytes);
  }

  /// 在同步完成后刷新配额
  Future<void> refreshQuotaAfterSync() async {
    try {
      await _quotaService.refreshQuota();
      if (kDebugMode) {
        print('🔄 同步后配额已刷新');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ 同步后刷新配额失败: $e');
      }
    }
  }

  /// 记录同步操作日志
  Future<void> logSyncOperation({
    required OperationType operation,
    required ResourceType resourceType,
    required int bytesChanged,
    String? resourceId,
  }) async {
    try {
      await _quotaService.logStorageUsage(
        operationType: operation,
        resourceType: resourceType,
        bytesChanged: bytesChanged,
        resourceId: resourceId,
        metadata: {'source': 'sync'},
      );
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ 记录同步日志失败: $e');
      }
    }
  }
}

/// 同步配额验证结果
class SyncQuotaValidationResult {
  final bool canProceed;
  final SyncBlockReason? blockReason;
  final String? message;
  final QuotaCheckResult? quotaCheckResult;
  final int? requiredBytes;

  const SyncQuotaValidationResult({
    required this.canProceed,
    this.blockReason,
    this.message,
    this.quotaCheckResult,
    this.requiredBytes,
  });

  factory SyncQuotaValidationResult.canProceed({int? requiredBytes}) {
    return SyncQuotaValidationResult(
      canProceed: true,
      requiredBytes: requiredBytes,
    );
  }

  factory SyncQuotaValidationResult.failed({
    required SyncBlockReason reason,
    required String message,
    QuotaCheckResult? quotaCheckResult,
    int? requiredBytes,
  }) {
    return SyncQuotaValidationResult(
      canProceed: false,
      blockReason: reason,
      message: message,
      quotaCheckResult: quotaCheckResult,
      requiredBytes: requiredBytes,
    );
  }

  bool get isStorageLimit => blockReason == SyncBlockReason.storageLimit;
  bool get isNoteLimit => blockReason == SyncBlockReason.noteCountLimit;
  bool get isImageLimit => blockReason == SyncBlockReason.imageCountLimit;

  /// 获取用户友好的错误消息
  String get userFriendlyMessage {
    if (message != null && message!.isNotEmpty) {
      return message!;
    }
    
    switch (blockReason) {
      case SyncBlockReason.storageLimit:
        return '云端存储空间不足，请升级套餐或清理空间';
      case SyncBlockReason.noteCountLimit:
        return '笔记数量已达上限，请升级套餐或删除不需要的笔记';
      case SyncBlockReason.imageCountLimit:
        return '图片数量已达上限，请升级套餐或清理不需要的图片';
      default:
        return '配额检查失败，请稍后重试';
    }
  }
}

/// 同步被阻断原因
enum SyncBlockReason {
  storageLimit,
  noteCountLimit,
  imageCountLimit,
}
