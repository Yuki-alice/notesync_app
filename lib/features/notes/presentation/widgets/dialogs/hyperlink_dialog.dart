import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/providers/notes_provider.dart';

class HyperlinkDialog extends StatefulWidget {
  final String initialText;
  final String? initialUrl;

  const HyperlinkDialog({super.key, required this.initialText, this.initialUrl});

  @override
  State<HyperlinkDialog> createState() => _HyperlinkDialogState();
}

class _HyperlinkDialogState extends State<HyperlinkDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _textController;
  late TextEditingController _urlController;
  late TextEditingController _searchController;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _textController = TextEditingController(text: widget.initialText);
    _urlController = TextEditingController(text: widget.initialUrl?.startsWith('http') == true ? widget.initialUrl : '');
    _searchController = TextEditingController();

    if (widget.initialUrl?.startsWith('notesync://') == true) {
      _tabController.index = 1;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _urlController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      title: Row(
        children: [
          Icon(Icons.link_rounded, color: colorScheme.primary),
          const SizedBox(width: 12),
          const Text('编辑超链接', style: TextStyle(fontSize: 20)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: '显示文本',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            Container(
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(borderRadius: BorderRadius.circular(20), color: colorScheme.primary),
                labelColor: colorScheme.onPrimary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [Tab(text: '网页链接'), Tab(text: '内部笔记')],
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 200,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildWebTab(colorScheme),
                  _buildNoteTab(context, colorScheme),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () {
            String finalUrl = _tabController.index == 0
                ? _urlController.text.trim()
                : _searchQuery;
            Navigator.pop(context, {'text': _textController.text, 'url': finalUrl});
          },
          child: const Text('应用'),
        ),
      ],
    );
  }

  Widget _buildWebTab(ColorScheme colorScheme) {
    return TextField(
      controller: _urlController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: '输入网址 (如 https://...)',
        prefixIcon: const Icon(Icons.public_rounded),
        border: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.primary)),
      ),
    );
  }

  Widget _buildNoteTab(BuildContext context, ColorScheme colorScheme) {
    final notes = context.watch<NotesProvider>().notes;
    final filteredNotes = notes.where((n) => n.title.toLowerCase().contains(_searchController.text.toLowerCase())).toList();

    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (v) => setState(() {}),
          decoration: const InputDecoration(hintText: '搜索笔记标题...', prefixIcon: Icon(Icons.search_rounded)),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: filteredNotes.length,
            itemBuilder: (context, i) {
              final note = filteredNotes[i];
              final isSelected = _searchQuery == 'notesync://note/${note.id}';
              return ListTile(
                dense: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                leading: const Icon(Icons.description_outlined, size: 18),
                title: Text(note.title.isEmpty ? '无标题文档' : note.title),
                selected: isSelected,
                selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.4),
                onTap: () {
                  setState(() {
                    _searchQuery = 'notesync://note/${note.id}';
                    if (_textController.text.isEmpty) _textController.text = note.title.isEmpty ? '无标题文档' : note.title;
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }
}