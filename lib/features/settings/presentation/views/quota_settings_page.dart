import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/providers/quota_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../models/user_quota.dart';
import '../../../../utils/toast_utils.dart';

/// 云端存储配额管理页面
/// 
/// 展示用户当前的存储配额使用情况，提供升级方案
class QuotaSettingsPage extends StatefulWidget {
  const QuotaSettingsPage({super.key});

  @override
  State<QuotaSettingsPage> createState() => _QuotaSettingsPageState();
}

class _QuotaSettingsPageState extends State<QuotaSettingsPage> {
  @override
  void initState() {
    super.initState();
    // 页面加载时刷新配额
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuotaProvider>().refreshQuota(silent: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          '云端存储配额',
          style: GoogleFonts.notoSans(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () => context.read<QuotaProvider>().refreshQuota(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新配额',
          ),
        ],
      ),
      body: Consumer<QuotaProvider>(
        builder: (context, quotaProvider, child) {
          if (quotaProvider.isLoading && quotaProvider.quota == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!auth.isAuthenticated) {
            return _buildNotLoggedInView(theme);
          }

          final quota = quotaProvider.quota;
          if (quota == null) {
            return _buildErrorView(theme, quotaProvider.error);
          }

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              // 当前配额卡片
              _buildQuotaCard(theme, quota),
              const SizedBox(height: 24),

              // 使用详情
              _buildUsageDetails(theme, quota),
              const SizedBox(height: 24),

              // 套餐对比
              _buildPlanComparison(theme, quotaProvider),
              const SizedBox(height: 24),

              // 升级按钮
              if (quota.planType != PlanType.team)
                _buildUpgradeButton(theme, quotaProvider),
            ],
          );
        },
      ),
    );
  }

  /// 未登录视图
  Widget _buildNotLoggedInView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '请先登录',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '登录后可查看云端存储配额',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 错误视图
  Widget _buildErrorView(ThemeData theme, String? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error ?? '无法获取配额信息',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.read<QuotaProvider>().refreshQuota(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  /// 配额主卡片
  Widget _buildQuotaCard(ThemeData theme, UserQuota quota) {
    final isWarning = quota.isWarning;
    final isExceeded = quota.isExceeded;
    
    Color progressColor = theme.colorScheme.primary;
    if (isExceeded) {
      progressColor = theme.colorScheme.error;
    } else if (isWarning) {
      progressColor = Colors.orange;
    } else if (quota.isNearLimit) {
      progressColor = Colors.amber;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primaryContainer.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 套餐标签
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  quota.planName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
              if (isExceeded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_rounded, size: 14, color: theme.colorScheme.onError),
                      const SizedBox(width: 4),
                      Text(
                        '已超限',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onError,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // 存储使用情况
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                quota.formattedUsedStorage,
                style: GoogleFonts.notoSans(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '/ ${quota.formattedLimitStorage}',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: quota.storageUsageRatio.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: theme.colorScheme.surface.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: 12),

          // 使用百分比
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '已使用 ${quota.storageUsagePercent}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              Text(
                '剩余 ${quota.formattedRemainingStorage}',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 使用详情
  Widget _buildUsageDetails(ThemeData theme, UserQuota quota) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '使用详情',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _buildDetailRow(
                theme,
                icon: Icons.note_rounded,
                title: '笔记数量',
                used: quota.noteCountUsed,
                limit: quota.noteCountLimit,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
              const SizedBox(height: 16),
              _buildDetailRow(
                theme,
                icon: Icons.image_rounded,
                title: '图片数量',
                used: quota.imageCountUsed,
                limit: quota.imageCountLimit,
                color: theme.colorScheme.secondary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required int used,
    required int limit,
    required Color color,
  }) {
    final ratio = limit > 0 ? used / limit : 0.0;
    final isLimited = limit > 0;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              if (isLimited)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Text(
                  '无限制',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Text(
          isLimited ? '$used / $limit' : '$used',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  /// 套餐对比
  Widget _buildPlanComparison(ThemeData theme, QuotaProvider quotaProvider) {
    final plans = quotaProvider.planConfigs;
    if (plans.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '套餐对比',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        ...plans.map((plan) => _buildPlanCard(theme, plan, quotaProvider)),
      ],
    );
  }

  Widget _buildPlanCard(
    ThemeData theme,
    PlanConfig plan,
    QuotaProvider quotaProvider,
  ) {
    final isCurrentPlan = quotaProvider.currentPlan == plan.planType;
    final isRecommended = plan.planType == PlanType.pro && !isCurrentPlan;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCurrentPlan
            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
            : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: isCurrentPlan
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : isRecommended
                ? Border.all(color: Colors.amber, width: 2)
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    plan.planName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (isCurrentPlan) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '当前',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                  if (isRecommended) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '推荐',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (plan.monthlyPriceCents != null && plan.monthlyPriceCents! > 0)
                Text(
                  plan.formattedMonthlyPrice!,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                )
              else
                Text(
                  '免费',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (plan.planDescription != null) ...[
            const SizedBox(height: 4),
            Text(
              plan.planDescription!,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildPlanFeature(theme, Icons.storage_rounded, '${_formatStorage(plan.storageLimitMb)} 存储空间'),
          if (plan.noteCountLimit != null)
            _buildPlanFeature(theme, Icons.note_rounded, '${plan.noteCountLimit} 条笔记'),
          if (plan.imageCountLimit != null)
            _buildPlanFeature(theme, Icons.image_rounded, '${plan.imageCountLimit} 张图片'),
          if (plan.features['webdav'] == true)
            _buildPlanFeature(theme, Icons.cloud_sync_rounded, 'WebDAV 同步'),
          if (plan.features['priority_support'] == true)
            _buildPlanFeature(theme, Icons.support_agent_rounded, '优先客服支持'),
        ],
      ),
    );
  }

  Widget _buildPlanFeature(ThemeData theme, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  /// 升级按钮
  Widget _buildUpgradeButton(ThemeData theme, QuotaProvider quotaProvider) {
    final nextPlan = quotaProvider.getNextUpgradePlan();
    if (nextPlan == null) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => _showUpgradeDialog(context, nextPlan),
        icon: const Icon(Icons.rocket_launch_rounded),
        label: Text('升级到 ${nextPlan.planName}'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  /// 显示升级对话框
  void _showUpgradeDialog(BuildContext context, PlanConfig plan) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '升级到 ${plan.planName}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '解锁更多存储空间和高级功能',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            
            // 价格选项
            if (plan.yearlyPriceCents != null && plan.yearlyPriceCents! > 0) ...[
              _buildPriceOption(
                theme,
                title: '年付',
                price: plan.formattedYearlyPrice!,
                subtitle: '相当于 ${plan.formattedYearlyMonthlyPrice}/月',
                badge: plan.yearlySavingsPercent != null ? '省 ${plan.yearlySavingsPercent}%' : null,
                isRecommended: true,
              ),
              const SizedBox(height: 12),
            ],
            if (plan.monthlyPriceCents != null && plan.monthlyPriceCents! > 0)
              _buildPriceOption(
                theme,
                title: '月付',
                price: plan.formattedMonthlyPrice!,
                subtitle: '按月订阅，随时取消',
              ),
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  ToastUtils.showInfo(context, '支付功能开发中...');
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('立即升级'),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('稍后再说'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceOption(
    ThemeData theme, {
    required String title,
    required String price,
    required String subtitle,
    String? badge,
    bool isRecommended = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRecommended
            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
            : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: isRecommended
            ? Border.all(color: theme.colorScheme.primary)
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatStorage(int mb) {
    if (mb < 1024) return '$mb MB';
    return '${(mb / 1024).toStringAsFixed(0)} GB';
  }
}
