import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/todos_provider.dart';
import '../../../../models/note.dart';
import '../../../../models/todo.dart';
import '../../../../widgets/common/dialogs/note_detail_dialog.dart'; // 确保导入

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 获取 Provider
    final notesProvider = Provider.of<NotesProvider>(context);
    final todosProvider = Provider.of<TodosProvider>(context);

    // 获取过滤后的列表 (同步操作，非常快)
    final filteredNotes = notesProvider.searchNotes(_searchQuery);
    final filteredTodos = todosProvider.searchTodos(_searchQuery);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '搜索笔记或待办...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          autofocus: false,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
      ),
      body: _searchQuery.isEmpty
          ? Center(child: Text('输入关键词开始搜索', style: TextStyle(color: Theme.of(context).colorScheme.outline)))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (filteredNotes.isNotEmpty) ...[
            Text('笔记 (${filteredNotes.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8),
            ...filteredNotes.map((note) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(note.title, maxLines: 1),
                subtitle: Text(note.content, maxLines: 1, overflow: TextOverflow.ellipsis),
                leading: const Icon(Icons.note),
                onTap: () => showNoteDetailDialog(context, note),
              ),
            )),
            const SizedBox(height: 16),
          ],

          if (filteredTodos.isNotEmpty) ...[
            Text('待办 (${filteredTodos.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8),
            ...filteredTodos.map((todo) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(todo.title,
                    style: TextStyle(
                        decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                        color: todo.isCompleted ? Colors.grey : null
                    )),
                leading: Checkbox(
                  value: todo.isCompleted,
                  onChanged: (_) => todosProvider.toggleTodoStatus(todo.id),
                ),
              ),
            )),
          ],

          if (filteredNotes.isEmpty && filteredTodos.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.only(top: 32.0),
              child: Text('没有找到匹配的内容'),
            )),
        ],
      ),
    );
  }
}