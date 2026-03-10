import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../widgets/common/app_empty_state.dart';
import '../../../../core/constants/app_dimens.dart';

// 🟢 引入我们抽离出来的三个弹窗组件
import '../../../../widgets/common/dialogs/add_category_dialog.dart';
import '../../../../widgets/common/dialogs/delete_category_dialog.dart';
import '../../../../widgets/common/dialogs/rename_category_dialog.dart';


class CategoryManagementPage extends StatelessWidget {
  const CategoryManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('分类管理', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Consumer<NotesProvider>(
        builder: (context, provider, child) {
          final categories = provider.categories;

          if (categories.isEmpty) {
            return const AppEmptyState(
              message: '暂无分类',
              subMessage: '点击右下角按钮添加你的第一个分类',
              icon: Icons.folder_open_rounded,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppDimens.pagePadding),
            itemCount: categories.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppDimens.listSpacing),
            itemBuilder: (context, index) {
              final category = categories[index];

              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimens.cardRadius)),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.folder_rounded, color: theme.colorScheme.onSecondaryContainer),
                  ),
                  title: Text(
                    category,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ✏️ 重命名按钮
                      IconButton.filledTonal(
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        tooltip: '重命名',
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.surface,
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          // 🟢 调用重命名弹窗
                          final newName = await showRenameCategoryDialog(context, category);
                          if (newName != null && context.mounted) {
                            provider.renameCategory(category, newName);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      // 🗑️ 删除按钮
                      IconButton.filledTonal(
                        icon: Icon(Icons.delete_rounded, size: 18, color: theme.colorScheme.error),
                        tooltip: '删除',
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.errorContainer.withOpacity(0.5),
                          foregroundColor: theme.colorScheme.error,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          // 🟢 调用删除确认弹窗
                          final confirm = await showDeleteCategoryDialog(context, category);
                          if (confirm == true && context.mounted) {
                            provider.deleteCategory(category);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          HapticFeedback.selectionClick();
          // 🟢 调用新建分类弹窗
          final newCategory = await showAddCategoryDialog(context);
          if (newCategory != null && context.mounted) {
            Provider.of<NotesProvider>(context, listen: false).addCategory(newCategory);
          }
        },
        icon: const Icon(Icons.create_new_folder_rounded),
        label: const Text('新分类', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 4,
      ),
    );
  }
}