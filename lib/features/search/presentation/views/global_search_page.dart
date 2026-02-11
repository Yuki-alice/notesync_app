import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/todos_provider.dart';
import '../../../../models/note.dart';
import '../../../../models/todo.dart';
import '../../../../utils/app_feedback.dart';
import '../../../../widgets/common/app_empty_state.dart';
import '../../../../widgets/common/search_highlight_text.dart';
import '../../../../core/routes/app_routes.dart';


class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    // 延迟聚焦，配合 Hero 动画更流畅
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notesProvider = Provider.of<NotesProvider>(context);
    final todosProvider = Provider.of<TodosProvider>(context);

    // 🟢 核心搜索逻辑
    final filteredNotes = _query.isEmpty
        ? <Note>[]
        : notesProvider.notes.where((note) {
      if (note.isDeleted) return false;
      final q = _query.toLowerCase();
      // 搜索：标题 OR 内容 OR 标签
      return note.title.toLowerCase().contains(q) ||
          note.plainText.toLowerCase().contains(q) ||
          note.tags.any((tag) => tag.toLowerCase().contains(q));
    }).toList();

    final filteredTodos = _query.isEmpty
        ? <Todo>[]
        : todosProvider.todos.where((todo) {
      if (todo.isDeleted) return false;
      final q = _query.toLowerCase();
      return todo.title.toLowerCase().contains(q) ||
          todo.description.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // 🟢 顶部搜索栏 (Hero 动画源)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  // 返回按钮
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)),
                  ),
                  const SizedBox(width: 12),
                  // 搜索框主体
                  Expanded(
                    child: Hero(
                      tag: 'global_search_bar', // 🟢 关键 Tag，需与入口一致
                      child: Material(
                        color: Colors.transparent,
                        child: SearchBar(
                          controller: _controller,
                          focusNode: _focusNode,
                          hintText: '搜索笔记、标签、待办...',
                          leading: const Icon(Icons.search_rounded),
                          trailing: _query.isNotEmpty
                              ? [
                            IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _controller.clear();
                                setState(() => _query = '');
                                AppFeedback.light();
                              },
                            )
                          ]
                              : null,
                          onChanged: (value) => setState(() => _query = value),
                          elevation: WidgetStateProperty.all(0),
                          backgroundColor: WidgetStateProperty.all(
                              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                          ),
                          autoFocus: false, // 由 initState 手动控制
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 🟢 搜索结果列表
            Expanded(
              child: _query.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.manage_search_rounded, size: 80, color: theme.colorScheme.surfaceContainerHighest),
                    const SizedBox(height: 16),
                    Text('输入关键词开始搜索', style: TextStyle(color: theme.colorScheme.outline)),
                  ],
                ),
              )
                  : (filteredNotes.isEmpty && filteredTodos.isEmpty)
                  ? const AppEmptyState(message: '未找到相关内容', icon: Icons.search_off_rounded)
                  : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  if (filteredNotes.isNotEmpty) ...[
                    _buildSectionHeader(context, '笔记', filteredNotes.length),
                    ...filteredNotes.map((note) => _buildNoteItem(context, note)),
                    const SizedBox(height: 24),
                  ],
                  if (filteredTodos.isNotEmpty) ...[
                    _buildSectionHeader(context, '待办', filteredTodos.length),
                    ...filteredTodos.map((todo) => _buildTodoItem(context, todo)),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Text(title, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(8)),
            child: Text('$count', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteItem(BuildContext context, Note note) {
    final theme = Theme.of(context);
    // 检查是否有匹配的标签
    final matchedTags = note.tags.where((t) => t.toLowerCase().contains(_query.toLowerCase())).toList();

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, AppRoutes.noteEditor, arguments: note),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题高亮
              Row(
                children: [
                  Icon(Icons.description, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SearchHighlightText(
                      note.title.isEmpty ? '无标题' : note.title,
                      query: _query,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // 内容高亮
              Padding(
                padding: const EdgeInsets.only(left: 24),
                child: SearchHighlightText(
                  note.plainText,
                  query: _query,
                  maxLines: 2,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                ),
              ),
              // 🟢 匹配的标签展示
              if (matchedTags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Wrap(
                    spacing: 8,
                    children: matchedTags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF176), // 强制黄色背景以突出
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.tag, size: 12, color: Colors.black),
                          Text(tag, style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )).toList(),
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodoItem(BuildContext context, Todo todo) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(
          todo.isCompleted ? Icons.check_circle_rounded : Icons.circle_outlined,
          color: todo.isCompleted ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
        title: SearchHighlightText(
          todo.title,
          query: _query,
          style: TextStyle(
            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
            color: todo.isCompleted ? theme.colorScheme.outline : null,
          ),
        ),
        subtitle: todo.description.isNotEmpty
            ? SearchHighlightText(todo.description, query: _query, maxLines: 1)
            : null,
      ),
    );
  }
}