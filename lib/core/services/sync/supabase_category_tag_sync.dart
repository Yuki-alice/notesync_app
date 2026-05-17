// 分类和标签同步
// 负责分类（Category）和标签（Tag）的双向增量同步，包括：
// - 分类黑名单处理与基于 updatedAt 的增量同步
// - 标签黑名单处理与存在性比对同步

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/category_repository.dart';
import '../../repositories/tag_repository.dart';
import '../../../models/category.dart';
import '../../../models/tag.dart';

import '../../constants/sync_constants.dart';
import 'sync_models.dart';
import 'supabase_retry_wrapper.dart';

class SupabaseCategoryTagSync {
  final SupabaseClient _supabase;
  final CategoryRepository? _categoryRepo;
  final TagRepository? _tagRepo;
  final SupabaseRetryWrapper _retry;

  SupabaseCategoryTagSync(
    this._supabase,
    this._categoryRepo,
    this._tagRepo,
    this._retry,
  );

  Future<void> syncCategoriesAndTags(String userId, SharedPreferences prefs) async {
    if (_categoryRepo == null || _tagRepo == null) return;

    await _syncCategories(userId, prefs);
    await _syncTags(userId, prefs);
  }

  // =========================================================================
  // 分类同步
  // =========================================================================

  Future<void> _syncCategories(String userId, SharedPreferences prefs) async {
    // ----- 1. 处理分类黑名单 (物理删除) -----
    final deletedCats = prefs.getStringList(deletedCategoriesKey) ?? [];
    if (deletedCats.isNotEmpty) {
      await _retry.withRetry(
        operation: () => _supabase.from('categories').delete().inFilter('id', deletedCats),
        operationName: '删除云端分类',
      );
      await prefs.setStringList(deletedCategoriesKey, []);
      SyncLogger.info('CATE', '成功清空本地分类黑名单');
    }

    // ----- 2. 分类双向增量同步 (基于 updatedAt 时间戳) -----
    final localCats = _categoryRepo!.getAllCategories();
    final cloudCatsData = await _retry.withRetry(
      operation: () => _supabase.from('categories').select().eq('user_id', userId),
      operationName: '拉取云端分类',
    );

    final localCatsMap = {for (var c in localCats) c.id: c};
    final cloudCatsMap = {for (var map in cloudCatsData) map['id'] as String: map};

    final catsToPush = <Map<String, dynamic>>[];

    Map<String, dynamic> catToPayload(Category c) => {
      'id': c.id,
      'user_id': userId,
      'name': c.name,
      'color': c.color,
      'icon': c.icon,
      'sort_order': c.sortOrder,
      'is_deleted': c.isDeleted,
      'created_at': c.createdAt.toUtc().toIso8601String(),
      'updated_at': c.updatedAt.toUtc().toIso8601String(),
    };

    // (1) 遍历本地，决定谁有资格推送给云端
    for (var localCat in localCats) {
      final cloudData = cloudCatsMap[localCat.id];
      if (cloudData == null) {
        catsToPush.add(catToPayload(localCat));
      } else {
        final cloudTime = DateTime.parse(cloudData['updated_at']).toLocal();
        if (localCat.updatedAt.difference(cloudTime).inSeconds > timeBuffer.inSeconds) {
          catsToPush.add(catToPayload(localCat));
        }
      }
    }

    // (2) 遍历云端，决定谁应该被拉回本地
    bool localCatChanged = false;
    for (var cloudData in cloudCatsData) {
      final cloudId = cloudData['id'] as String;
      final localCat = localCatsMap[cloudId];
      final cloudTime = DateTime.parse(cloudData['updated_at']).toLocal();

      final cloudCatModel = Category(
        id: cloudId,
        name: cloudData['name'],
        color: cloudData['color'],
        icon: cloudData['icon'],
        sortOrder: (cloudData['sort_order'] as num?)?.toDouble() ?? SyncConstants.defaultSortOrder,
        isDeleted: cloudData['is_deleted'] ?? false,
        createdAt: DateTime.parse(cloudData['created_at']).toLocal(),
        updatedAt: cloudTime,
      );

      if (localCat == null) {
        await _categoryRepo!.addCategory(cloudCatModel);
        localCatChanged = true;
      } else {
        if (cloudTime.difference(localCat.updatedAt).inSeconds > timeBuffer.inSeconds) {
          await _categoryRepo!.updateCategory(cloudCatModel);
          localCatChanged = true;
        }
      }
    }

    // 执行分类推送
    if (catsToPush.isNotEmpty) {
      await _retry.withRetry(
        operation: () => _supabase.from('categories').upsert(catsToPush),
        operationName: '推送分类到云端',
      );
      SyncLogger.info('CATE', '推送 ${catsToPush.length} 个分类更新到云端');
    }
    if (localCatChanged) {
      SyncLogger.info('CATE', '从云端拉取并更新了本地分类');
    }
  }

  // =========================================================================
  // 标签同步
  // =========================================================================

  Future<void> _syncTags(String userId, SharedPreferences prefs) async {
    // 🌟 3.1 处理标签删除黑名单 (物理删除)
    final deletedTags = prefs.getStringList(deletedTagsKey) ?? [];
    if (deletedTags.isNotEmpty) {
      await _retry.withRetry(
        operation: () => _supabase.from('tags').delete().inFilter('id', deletedTags),
        operationName: '删除云端标签',
      );
      await prefs.setStringList(deletedTagsKey, []);
      SyncLogger.info('TAG', '成功清空本地标签黑名单，删除 ${deletedTags.length} 个云端标签');
    }

    // 🌟 3.2 标签双向合并同步 (标签通常不修改名字，只需比对存在性)
    final localTags = _tagRepo!.getAllTags();
    final cloudTagsData = await _retry.withRetry(
      operation: () => _supabase.from('tags').select().eq('user_id', userId),
      operationName: '拉取云端标签',
    );

    final localTagsMap = {for (var t in localTags) t.id: t};
    final cloudTagsMap = {for (var map in cloudTagsData) map['id'] as String: map};

    final tagsToPush = <Map<String, dynamic>>[];

    // (1) 遍历本地，推送本地有但云端没有的新标签
    for (var localTag in localTags) {
      if (!cloudTagsMap.containsKey(localTag.id)) {
        tagsToPush.add({
          'id': localTag.id,
          'user_id': userId,
          'name': localTag.name,
          'color': localTag.color,
          'is_deleted': localTag.isDeleted,
          'created_at': localTag.createdAt.toUtc().toIso8601String(),
        });
      }
    }

    // (2) 遍历云端，拉取云端有但本地没有的新标签
    bool localTagChanged = false;
    for (var cloudData in cloudTagsData) {
      final cloudId = cloudData['id'] as String;

      if (deletedTags.contains(cloudId)) {
        SyncLogger.info('TAG', '跳过黑名单标签: $cloudId');
        continue;
      }

      if (!localTagsMap.containsKey(cloudId)) {
        await _tagRepo!.addTag(Tag(
          id: cloudId,
          name: cloudData['name'],
          color: cloudData['color'],
          isDeleted: cloudData['is_deleted'] ?? false,
          createdAt: DateTime.parse(cloudData['created_at']).toLocal(),
          updatedAt: DateTime.parse(cloudData['updated_at'] ?? cloudData['created_at']).toLocal(),
        ));
        localTagChanged = true;
      }
    }

    // 执行标签推送
    if (tagsToPush.isNotEmpty) {
      await _retry.withRetry(
        operation: () => _supabase.from('tags').upsert(tagsToPush),
        operationName: '推送标签到云端',
      );
      SyncLogger.info('TAG', '📤 推送 ${tagsToPush.length} 个新标签到云端');
    } else {
      SyncLogger.info('TAG', '📤 无需推送标签（本地无新标签）');
    }
    if (localTagChanged) {
      SyncLogger.info('TAG', '📥 从云端拉取了新标签');
    } else {
      SyncLogger.info('TAG', '📥 无需拉取标签（云端无新标签）');
    }
  }
}
