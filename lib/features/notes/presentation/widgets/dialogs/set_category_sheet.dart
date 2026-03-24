import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/providers/notes_provider.dart';

Future<String?> showSetCategorySheet(BuildContext context, {String? currentCategory}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (context) => _SetCategorySheet(currentCategory: currentCategory),
  );
}

class _SetCategorySheet extends StatefulWidget {
  final String? currentCategory;
  const _SetCategorySheet({this.currentCategory});

  @override
  State<_SetCategorySheet> createState() => _SetCategorySheetState();
}

class _SetCategorySheetState extends State<_SetCategorySheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<NotesProvider>(context, listen: false);
    final categories = provider.categories; // 🌟 这是一个 List<Category> 对象列表
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '设置分类',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          TextField(
            controller: _controller,
            autofocus: false,
            decoration: InputDecoration(
              hintText: '输入新分类...',
              hintStyle: TextStyle(color: theme.colorScheme.outline),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              prefixIcon: Icon(Icons.create_new_folder_rounded, color: theme.colorScheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              suffixIcon: IconButton(
                onPressed: () {
                  if (_controller.text.trim().isNotEmpty) {
                    Navigator.pop(context, _controller.text.trim());
                  }
                },
                icon: const Icon(Icons.check_circle_rounded),
                color: theme.colorScheme.primary,
              ),
            ),
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) Navigator.pop(context, val.trim());
            },
          ),

          const SizedBox(height: 24),

          Text(
              '现有分类',
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 12,
            children: [
              FilterChip(
                label: const Text('无分类'),
                selected: widget.currentCategory == null,
                onSelected: (_) => Navigator.pop(context, ''),
                avatar: widget.currentCategory == null ? const Icon(Icons.check, size: 18) : null,
                backgroundColor: Colors.transparent,
                shape: StadiumBorder(side: BorderSide(color: theme.colorScheme.outline)),
                labelStyle: TextStyle(
                  color: widget.currentCategory == null ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onSurface,
                ),
              ),

              // 🌟 修复渲染逻辑
              ...categories.map((category) {
                // 传进来的是兼容层的分类名称 (String)
                final isSelected = widget.currentCategory == category.name;
                return FilterChip(
                  label: Text(category.name), // 🌟 必须取出 name 属性
                  selected: isSelected,
                  onSelected: (_) => Navigator.pop(context, category.name), // 🌟 返回选中的 name
                  selectedColor: theme.colorScheme.primaryContainer,
                  checkmarkColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}