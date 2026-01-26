import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/todos_provider.dart';
import '../../../../models/note.dart';
import '../../../../models/todo.dart';

import '../../../../widgets/common/dialogs/create_todo_dialog.dart';
import '../../../notes/presentation/views/note_editor_page.dart';

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

  void _openNote(Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NoteEditorPage(note: note)),
    );
  }

  void _openTodo(Todo todo) async {
    final provider = Provider.of<TodosProvider>(context, listen: false);
    final result = await showCreateTodoDialog(
      context: context,
      existingTodo: todo,
    );
    if (result != null) {
      await provider.updateTodo(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notesProvider = Provider.of<NotesProvider>(context);
    final todosProvider = Provider.of<TodosProvider>(context);

    // 获取过滤后的列表
    final filteredNotes = notesProvider.searchNotes(_searchQuery);
    final filteredTodos = todosProvider.searchTodos(_searchQuery);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索笔记或待办...',
              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              border: InputBorder.none,
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _searchController.clear(),
              )
                  : null,
            ),
            textInputAction: TextInputAction.search,
            autofocus: true,
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
      ),
      body: _searchQuery.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 64, color: theme.colorScheme.outline.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('输入关键词搜索', style: TextStyle(color: theme.colorScheme.outline)),
          ],
        ),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (filteredNotes.isNotEmpty) ...[
            _SectionHeader(title: '笔记', count: filteredNotes.length),
            ...filteredNotes.map((note) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
              ),
              child: ListTile(
                title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                // 🔴 关键修复：使用 plainText 而不是 content
                subtitle: Text(
                  note.plainText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                leading: Icon(Icons.article_outlined, color: theme.colorScheme.primary),
                onTap: () => _openNote(note),
              ),
            )),
            const SizedBox(height: 16),
          ],

          if (filteredTodos.isNotEmpty) ...[
            _SectionHeader(title: '待办', count: filteredTodos.length),
            ...filteredTodos.map((todo) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
              ),
              child: ListTile(
                title: Text(
                    todo.title,
                    style: TextStyle(
                      decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                      color: todo.isCompleted ? theme.colorScheme.outline : theme.colorScheme.onSurface,
                    )
                ),
                leading: Transform.scale(
                  scale: 0.9,
                  child: Checkbox(
                    value: todo.isCompleted,
                    onChanged: (_) => todosProvider.toggleTodoStatus(todo.id),
                    shape: const CircleBorder(),
                  ),
                ),
                onTap: () => _openTodo(todo),
              ),
            )),
          ],

          if (filteredNotes.isEmpty && filteredTodos.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.only(top: 64.0),
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text('没有找到相关内容'),
                ],
              ),
            )),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        '$title ($count)',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}