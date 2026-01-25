import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/notes_provider.dart';
import '../../../../core/providers/todos_provider.dart';
import '../../../../models/note.dart';
import '../../../../models/todo.dart';


class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 搜索输入监听：实时更新搜索关键词
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: '搜索笔记/待办...',
            border: InputBorder.none,
            icon: Icon(Icons.search, color: Colors.white),
          ),
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        bottom: TabBar(controller: _tabController, tabs: const [
          Tab(text: '笔记', icon: Icon(Icons.note)),
          Tab(text: '待办', icon: Icon(Icons.check_box_outline_blank)),
        ]),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ✅ 核心修复1：用 FutureBuilder 解析 异步笔记数据
          FutureBuilder<List<Note>>(
            // 传入异步方法，自动执行+解析结果
            future: Provider.of<NotesProvider>(context, listen: false).searchNotes(_searchQuery),
            // 初始数据：空列表，避免加载时报错
            initialData: const [],
            builder: (ctx, snapshot) {
              // 处理异步状态：加载中/加载失败/加载成功
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return const Center(child: Text('笔记搜索失败，请重试'));
              }

              final filteredNotes = snapshot.data!;
              return _buildNotesList(filteredNotes);
            },
          ),
          // ✅ 核心修复2：用 FutureBuilder 解析 异步待办数据
          FutureBuilder<List<Todo>>(
            future: Provider.of<TodosProvider>(context, listen: false).searchTodos(_searchQuery),
            initialData: const [],
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return const Center(child: Text('待办搜索失败，请重试'));
              }

              final filteredTodos = snapshot.data!;
              return _buildTodosList(filteredTodos);
            },
          ),
        ],
      ),
    );
  }

  // 笔记列表构建（纯同步，无报错）
  Widget _buildNotesList(List<Note> notes) {
    if (notes.isEmpty) {
      return const Center(child: Text('未找到匹配的笔记', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: notes.length,
      itemBuilder: (ctx, index) {
        final note = notes[index];
        return ListTile(
          title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(note.content ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
          leading: const Icon(Icons.note_outlined),
          onTap: () => _showNoteDetail(ctx, note),
        );
      },
    );
  }

  // 待办列表构建（纯同步，无报错 + 状态同步修复）
  Widget _buildTodosList(List<Todo> todos) {
    if (todos.isEmpty) {
      return const Center(child: Text('未找到匹配的待办', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: todos.length,
      itemBuilder: (ctx, index) {
        final todo = todos[index];
        return ListTile(
          leading: Checkbox(
            value: todo.isCompleted,
            onChanged: (_) async {
              // ✅ 异步操作+状态刷新，保证UI同步
              await Provider.of<TodosProvider>(context, listen: false)
                  .toggleTodoStatus(todo.id);
              // 重新触发搜索，刷新列表
              setState(() {});
            },
          ),
          title: Text(
            todo.title,
            style: TextStyle(
              decoration: todo.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
              color: todo.isCompleted ? Colors.grey : null,
            ),
          ),
        );
      },
    );
  }

  // 笔记详情弹窗
  void _showNoteDetail(BuildContext ctx, Note note) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(note.title),
        content: SingleChildScrollView(child: Text(note.content ?? '无内容')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
      ),
    );
  }
}