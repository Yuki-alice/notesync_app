import 'package:flutter/material.dart';
import '../../../models/note.dart';

// 这是一个辅助函数，用于显示弹窗并返回结果
Future<Note?> showCreateNoteDialog({
  required BuildContext context,
  Note? existingNote,
}) {
  return showDialog<Note>(
    context: context,
    builder: (context) => CreateNoteDialog(existingNote: existingNote),
  );
}

class CreateNoteDialog extends StatefulWidget {
  final Note? existingNote;

  const CreateNoteDialog({super.key, this.existingNote});

  @override
  State<CreateNoteDialog> createState() => _CreateNoteDialogState();
}

class _CreateNoteDialogState extends State<CreateNoteDialog> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final TextEditingController _tagController = TextEditingController();

  // 用于存储当前的标签列表
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    // 如果是编辑模式，回显数据
    _titleController = TextEditingController(text: widget.existingNote?.title ?? '');
    _contentController = TextEditingController(text: widget.existingNote?.content ?? '');

    // 复制原有的标签列表，避免直接修改原对象
    if (widget.existingNote != null) {
      _tags = List.from(widget.existingNote!.tags);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingNote != null;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          children: [
            // 顶部标题栏
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                isEditing ? '编辑笔记' : '新建笔记',
                style: theme.textTheme.headlineSmall,
              ),
            ),

            // 可滚动的内容区域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题输入
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: '标题',
                        border: OutlineInputBorder(),
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // 内容输入
                    TextField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: '内容',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                      maxLines: 8,
                      minLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // 标签管理区域
                    Text('标签', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),

                    // 标签输入框
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _tagController,
                            decoration: InputDecoration(
                              hintText: '输入标签...',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onSubmitted: (_) => _addTag(), // 按回车添加
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: _addTag,
                          icon: const Icon(Icons.add),
                          tooltip: '添加标签',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 已添加标签展示 (Wrap + Chip)
                    if (_tags.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tags.map((tag) {
                          return InputChip(
                            label: Text(tag),
                            onDeleted: () => _removeTag(tag),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          );
                        }).toList(),
                      )
                    else
                      Text(
                        '暂无标签',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),

                    const SizedBox(height: 24), // 底部留白
                  ],
                ),
              ),
            ),

            // 底部按钮栏
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final title = _titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('标题不能为空')),
                        );
                        return;
                      }

                      final resultNote = Note(
                        id: widget.existingNote?.id ?? '',
                        title: title,
                        content: _contentController.text.trim(),
                        tags: _tags, // 保存标签列表
                        createdAt: widget.existingNote?.createdAt ?? DateTime.now(),
                        updatedAt: DateTime.now(),
                      );

                      Navigator.pop(context, resultNote);
                    },
                    child: const Text('保存'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}