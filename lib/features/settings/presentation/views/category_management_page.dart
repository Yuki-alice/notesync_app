import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🟢 引入 HapticFeedback
import 'package:provider/provider.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../widgets/common/app_empty_state.dart'; // 🟢 引入通用组件
import '../../../../core/constants/app_dimens.dart'; // 🟢 引入常量



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
            // 🟢 使用统一空状态组件
            return AppEmptyState(
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
                      IconButton.filledTonal(
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        tooltip: '重命名',
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.surface,
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _showEditDialog(context, provider, category),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: Icon(Icons.delete_rounded, size: 18, color: theme.colorScheme.error),
                        tooltip: '删除',
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.errorContainer.withOpacity(0.5),
                          foregroundColor: theme.colorScheme.error,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact(); // 🟢 触感反馈
                          _showDeleteDialog(context, provider, category);
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
        onPressed: () {
          HapticFeedback.selectionClick(); // 🟢 触感反馈
          _showAddDialog(context);
        },
        icon: const Icon(Icons.create_new_folder_rounded),
        label: const Text('新分类', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 4,
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建分类'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '例如：工作、生活...',
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Provider.of<NotesProvider>(context, listen: false).addCategory(controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, NotesProvider provider, String oldName) {
    final controller = TextEditingController(text: oldName);
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名分类'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '该分类下的所有笔记将自动更新',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty && controller.text.trim() != oldName) {
                provider.renameCategory(oldName, controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, NotesProvider provider, String category) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        icon: Icon(Icons.delete_forever_rounded, size: 48, color: theme.colorScheme.error),
        title: Text('删除 "$category"?', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('此分类将被移除。\n属于该分类的笔记不会被删除，它们将变为"未分类"状态。', textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error, foregroundColor: theme.colorScheme.onError),
            onPressed: () {
              provider.deleteCategory(category);
              Navigator.pop(ctx);
            },
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
  }
}