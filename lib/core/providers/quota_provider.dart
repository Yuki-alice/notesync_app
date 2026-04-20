import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_quota.dart';
import '../services/storage_quota_service.dart';

/// 配额状态管理 Provider
/// 
/// 负责：
/// 1. 管理用户配额状态
/// 2. 监听配额变化
/// 3. 提供配额检查快捷方法
/// 4. 处理配额超限提示
class QuotaProvider with ChangeNotifier {
  final StorageQuotaService _quotaService = StorageQuotaService();
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _refreshTimer;

  UserQuota? _quota;
  List<PlanConfig> _planConfigs = [];
  bool _isLoading = false;
  String? _error;

  // 配额警告状态
  bool _hasShownWarning = false;
  bool _hasShownExceeded = false;

  // Getters
  UserQuota? get quota => _quota;
  List<PlanConfig> get planConfigs => _planConfigs;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasQuota => _quota != null;

  // 便捷访问配额属性
  PlanType? get currentPlan => _quota?.planType;
  String? get planName => _quota?.planName;
  double? get usedStorageMb => _quota?.storageUsedMb;
  int? get storageLimitMb => _quota?.storageLimitMb;
  double? get storageUsageRatio => _quota?.storageUsageRatio;
  int? get storageUsagePercent => _quota?.storageUsagePercent;
  bool? get isStorageExceeded => _quota?.isExceeded;
  bool? get isStorageNearLimit => _quota?.isNearLimit;
  bool? get isStorageWarning => _quota?.isWarning;

  QuotaProvider() {
    _initialize();
  }

  /// 初始化
  void _initialize() {
    _loadQuota();
    _loadPlanConfigs();
    _setupAuthListener();
    _setupRefreshTimer();
  }

  /// 设置认证状态监听
  void _setupAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn) {
        _loadQuota();
        _loadPlanConfigs();
      } else if (event == AuthChangeEvent.signedOut) {
        _quota = null;
        _hasShownWarning = false;
        _hasShownExceeded = false;
        notifyListeners();
      }
    });
  }

  /// 设置定时刷新（每5分钟）
  void _setupRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (Supabase.instance.client.auth.currentUser != null) {
        refreshQuota(silent: true);
      }
    });
  }

  /// 加载用户配额
  Future<void> _loadQuota() async {
    if (_isLoading) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _quota = await _quotaService.getUserQuota();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 加载套餐配置
  Future<void> _loadPlanConfigs() async {
    try {
      _planConfigs = await _quotaService.getPlanConfigs();
      notifyListeners();
    } catch (e) {
      // 静默失败，使用默认配置
    }
  }

  /// 刷新配额
  /// 
  /// [silent] 是否在后台静默刷新（不显示 loading）
  Future<void> refreshQuota({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      _quota = await _quotaService.getUserQuota(forceRefresh: true);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  /// 检查存储配额并返回结果
  Future<QuotaCheckResult> checkStorageQuota(int requiredBytes) async {
    return await _quotaService.checkStorageQuota(requiredBytes: requiredBytes);
  }

  /// 检查笔记数量配额
  Future<QuotaCheckResult> checkNoteCountQuota({int additional = 1}) async {
    return await _quotaService.checkNoteCountQuota(additionalNotes: additional);
  }

  /// 检查图片数量配额
  Future<QuotaCheckResult> checkImageCountQuota({int additional = 1}) async {
    return await _quotaService.checkImageCountQuota(additionalImages: additional);
  }

  /// 综合检查上传配额
  /// 
  /// 返回是否可以继续上传
  Future<bool> canUpload({
    required int contentLength,
    int imageCount = 0,
    int imageBytes = 0,
  }) async {
    // 检查笔记数量
    final noteCheck = await checkNoteCountQuota();
    if (!noteCheck.canProceed) {
      return false;
    }

    // 检查存储空间
    final storageCheck = await checkStorageQuota(contentLength + imageBytes);
    if (!storageCheck.canProceed) {
      return false;
    }

    // 检查图片数量
    if (imageCount > 0) {
      final imageCheck = await checkImageCountQuota(additional: imageCount);
      if (!imageCheck.canProceed) {
        return false;
      }
    }

    return true;
  }

  /// 显示配额警告对话框
  /// 
  /// 在适当的时机调用此方法检查并显示警告
  void checkAndShowWarnings(BuildContext context) {
    if (_quota == null) return;

    // 检查是否已超限
    if (_quota!.isExceeded && !_hasShownExceeded) {
      _hasShownExceeded = true;
      _showExceededDialog(context);
      return;
    }

    // 检查是否接近上限（90%）
    if (_quota!.isWarning && !_hasShownWarning) {
      _hasShownWarning = true;
      _showWarningDialog(context);
      return;
    }

    // 检查是否需要注意（80%）
    if (_quota!.isNearLimit && !_hasShownWarning) {
      // 可以显示一个轻量提示，但不阻断用户
      _showNearLimitSnackBar(context);
    }
  }

  /// 显示超限对话框
  void _showExceededDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.storage_rounded,
          color: Theme.of(context).colorScheme.error,
          size: 48,
        ),
        title: const Text('存储空间已用尽'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('您的云端存储空间已使用 ${_quota!.storageUsagePercent}%，'
                 '超出 ${_quota!.formattedUsedStorage} / ${_quota!.formattedLimitStorage}。'),
            const SizedBox(height: 16),
            const Text('您需要：'),
            const SizedBox(height: 8),
            _buildOptionText('1. 升级套餐获取更多空间'),
            _buildOptionText('2. 删除不需要的笔记或图片'),
            _buildOptionText('3. 清理废纸篓释放空间'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后再说'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 导航到升级页面
            },
            child: const Text('立即升级'),
          ),
        ],
      ),
    );
  }

  /// 显示警告对话框
  void _showWarningDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange,
          size: 48,
        ),
        title: const Text('存储空间即将用尽'),
        content: Text('您的云端存储空间已使用 ${_quota!.storageUsagePercent}%，'
                      '剩余空间 ${_quota!.formattedRemainingStorage}。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 导航到升级页面
            },
            child: const Text('升级空间'),
          ),
        ],
      ),
    );
  }

  /// 显示接近上限提示
  void _showNearLimitSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('存储空间已使用 ${_quota!.storageUsagePercent}%'),
        action: SnackBarAction(
          label: '查看',
          onPressed: () {
            // TODO: 导航到配额管理页面
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Widget _buildOptionText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  /// 获取当前套餐配置
  PlanConfig? getCurrentPlanConfig() {
    if (_quota == null) return null;
    return _planConfigs.firstWhere(
      (p) => p.planType == _quota!.planType,
      orElse: () => _planConfigs.firstWhere(
        (p) => p.planType == PlanType.free,
        orElse: () => PlanConfig(
          id: 'fallback',
          planType: PlanType.free,
          planName: '免费版',
          storageLimitMb: 100,
          features: {},
          isActive: true,
          sortOrder: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ),
    );
  }

  /// 获取下一个升级套餐
  PlanConfig? getNextUpgradePlan() {
    final current = getCurrentPlanConfig();
    if (current == null) return null;

    final currentIndex = _planConfigs.indexWhere((p) => p.planType == current.planType);
    if (currentIndex < 0 || currentIndex >= _planConfigs.length - 1) return null;

    return _planConfigs[currentIndex + 1];
  }

  /// 清除警告状态（用户手动关闭后调用）
  void clearWarningState() {
    _hasShownWarning = false;
    _hasShownExceeded = false;
  }

  /// 清理资源
  @override
  void dispose() {
    _authSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
}
