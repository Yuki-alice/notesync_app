import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../widgets/common/dialogs/create_note_dialog.dart';
import '../../../../models/note.dart';

import 'note_editor_page.dart';

class NotesPage extends StatelessWidget {
  const NotesPage({super.key});

  // 🔴 修改处：跳转到全屏编辑器
  void _openEditor(BuildContext context, {Note? note}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NoteEditorPage(note: note)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('我的笔记')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context), // 🔴 调用新方法
        label: const Text('新建'),
        icon: const Icon(Icons.add),
      ),
      body: Consumer<NotesProvider>(
        builder: (ctx, provider, _) {
          final notes = provider.notes;
          if (notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.dashboard_customize_outlined,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text('暂无笔记，开始记录吧', style: theme.textTheme.bodyLarge),
                ],
              ),
            );
          }

          return MasonryGridView.count(
            padding: const EdgeInsets.all(12),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return _NoteGridCard(
                note: note,
                onTap: () => _openEditor(context, note: note), // 🔴 调用新方法
                onLongPress: () {
                  // 长按删除逻辑保持不变...
                  showDialog(
                    context: context,
                    builder:
                        (ctx) => AlertDialog(
                          title: const Text('删除笔记'),
                          content: const Text('确定要删除这条笔记吗？此操作无法撤销。'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                              ),
                              onPressed: () async {
                                Navigator.pop(ctx);
                                await provider.deleteNote(note.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('笔记已删除')),
                                  );
                                }
                              },
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// 专门为网格布局设计的卡片组件
class _NoteGridCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NoteGridCard({
    required this.note,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shadowColor: Colors.transparent,
      // 使用更现代的平面风格
      color: theme.colorScheme.surfaceContainerLow,
      // 使用 M3 新的色彩角色
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), // 圆角矩形
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // 重要：让卡片高度包裹内容
            children: [
              // 标题
              if (note.title.isNotEmpty) ...[
                Text(
                  note.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],

              // 内容预览 (瀑布流的关键是高度不一，所以这里不限制行数，或者限制较多行数)
              if (note.plainText.isNotEmpty) ...[
                // 🔴 改为判断 plainText
                Text(
                  note.plainText, // 🔴 改为显示 plainText
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 底部信息栏：标签和时间
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标签行
                  if (note.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children:
                            note.tags.take(3).map((tag) {
                              // 最多显示3个标签
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tag,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
                                    fontSize: 10,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  // 时间
                  Text(
                    note.formattedUpdatedAt,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
