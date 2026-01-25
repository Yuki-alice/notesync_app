import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../widgets/common/dialogs/create_note_dialog.dart';
import '../../../../widgets/common/dialogs/note_detail_dialog.dart';
import '../../../../models/note.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  @override
  void initState() {
    super.initState();
    // 初始化笔记数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotesProvider>(context, listen: false).init();
    });
  }

  // 打开创建/编辑笔记弹窗
  void _openNoteDialog({Note? note}) async {
    final result = await showCreateNoteDialog(
      context: context,
      existingNote: note,
    );
    if (result != null) {
      final provider = Provider.of<NotesProvider>(context, listen: false);
      if (note == null) {
        await provider.addNote(title: result.title, content: result.content);
      } else {
        await provider.updateNote(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的笔记'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNoteDialog(),
        child: const Icon(Icons.add),
      ),
      body: Consumer<NotesProvider>(
        builder: (ctx, provider, _) {
          final notes = provider.notes;
          if (notes.isEmpty) {
            return const Center(child: Text('暂无笔记，点击右下角添加'));
          }
          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (ctx, index) {
              final note = notes[index];
              return Slidable(
                key: Key(note.id),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (_) => _openNoteDialog(note: note),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      icon: Icons.edit,
                      label: '编辑',
                    ),
                    SlidableAction(
                      onPressed: (_) async {
                        await provider.deleteNote(note.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('笔记已删除')),
                          );
                        }
                      },
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: '删除',
                    ),
                  ],
                ),
                child: ListTile(
                  title: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '更新于: ${note.formattedUpdatedAt}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                  onTap: () => showNoteDetailDialog(context, note),
                ),
              );
            },
          );
        },
      ),
    );
  }
}