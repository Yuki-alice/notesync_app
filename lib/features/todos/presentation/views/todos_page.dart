import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/todos_provider.dart';
import '../../../../widgets/common/dialogs/create_todo_dialog.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class TodosPage extends StatefulWidget {
  const TodosPage({super.key});

  @override
  State<TodosPage> createState() => _TodosPageState();
}

class _TodosPageState extends State<TodosPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TodosProvider>(context, listen: false).init();
    });
  }

  void _openTodoDialog() async {
    final title = await showCreateTodoDialog(context);
    if (title != null) {
      await Provider.of<TodosProvider>(context, listen: false).addTodo(title: title);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的待办'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openTodoDialog,
        child: const Icon(Icons.add),
      ),
      body: Consumer<TodosProvider>(
        builder: (ctx, provider, _) {
          final todos = provider.todos;
          if (todos.isEmpty) {
            return const Center(child: Text('暂无待办，点击右下角添加'));
          }
          return ListView.builder(
            itemCount: todos.length,
            itemBuilder: (ctx, index) {
              final todo = todos[index];
              return Slidable(
                key: Key(todo.id),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (_) async {
                        await provider.deleteTodo(todo.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('待办已删除')),
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
                  leading: Checkbox(
                    value: todo.isCompleted,
                    onChanged: (_) async {
                      await provider.toggleTodoStatus(todo.id);
                    },
                  ),
                  title: Text(
                    todo.title,
                    style: TextStyle(
                      decoration: todo.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: todo.isCompleted ? Colors.grey : null,
                    ),
                  ),
                  onTap: () async {
                    await provider.toggleTodoStatus(todo.id);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}