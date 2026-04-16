// 文件路径: lib/features/notes/presentation/widgets/desktop_panels/left_navigation_panel.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart' as delta;
import 'package:provider/provider.dart';

import '../../../../../core/providers/notes_provider.dart';
import '../../../../../models/note.dart';
import '../../viewmodels/note_editor_viewmodel.dart';
import '../../views/note_editor_page.dart';
import '../editor_core/document_outline_widget.dart';

/// 搜索匹配项数据类
class _SearchMatch {
  final int offset;
  final int length;
  final bool isActive;

  const _SearchMatch({
    required this.offset,
    required this.length,
    this.isActive = false,
  });
}

class LeftNavigationPanel extends StatefulWidget {
  final ScrollController scrollController;
  final FocusNode editorFocusNode;
  final GlobalKey? editorKey;

  const LeftNavigationPanel({
    super.key,
    required this.scrollController,
    required this.editorFocusNode,
    this.editorKey,
  });

  @override
  State<LeftNavigationPanel> createState() => _LeftNavigationPanelState();
}

class _LeftNavigationPanelState extends State<LeftNavigationPanel> {
  static int _persistedLeftTab = 1;
  late int _selectedTab;

  // 搜索状态
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  final List<_SearchMatch> _searchMatches = [];
  int _currentMatchIndex = -1;

  @override
  void initState() {
    super.initState();
    _selectedTab = _persistedLeftTab;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _clearAllHighlights();
    super.dispose();
  }

  // =========================================================================
  // 🔍 底层逻辑 - 绝对坐标映射 & 幽灵高亮 (完美保留，坚决不改！)
  // =========================================================================
  String _buildPhysicalPlainText(quill.Document document) {
    final deltaDoc = document.toDelta();
    final StringBuffer sb = StringBuffer();

    for (final op in deltaDoc.toList()) {
      if (op.data is String) {
        sb.write(op.data as String);
      } else {
        sb.write(' ');
      }
    }

    return sb.toString();
  }

  void _calculateDocMatches(String query) {
    _clearAllHighlights();
    _searchMatches.clear();
    _currentMatchIndex = -1;

    if (query.isEmpty) {
      setState(() {});
      return;
    }

    final viewModel = context.read<NoteEditorViewModel>();
    final physicalText = _buildPhysicalPlainText(viewModel.quillController.document);
    final plainText = physicalText.toLowerCase();
    final q = query.toLowerCase();
    final queryLen = query.length;

    int index = plainText.indexOf(q);
    while (index != -1) {
      _searchMatches.add(_SearchMatch(
        offset: index,
        length: queryLen,
        isActive: false,
      ));
      index = plainText.indexOf(q, index + queryLen);
    }

    if (_searchMatches.isNotEmpty) {
      _currentMatchIndex = 0;
      _applyAllHighlights();
      _jumpToMatch(0);
    }

    setState(() {});
  }

  void _applyAllHighlights() {
    final viewModel = context.read<NoteEditorViewModel>();
    final controller = viewModel.quillController;

    for (int i = 0; i < _searchMatches.length; i++) {
      final match = _searchMatches[i];
      final isActive = i == _currentMatchIndex;

      controller.formatText(
        match.offset,
        match.length,
        quill.Attribute.background,
      );

      controller.document.compose(
        delta.Delta()
          ..retain(match.offset)
          ..retain(match.length, {
            'background': isActive ? '#FFEB3B' : '#FFF59D',
          }),
        quill.ChangeSource.local,
      );
    }
  }

  void _clearAllHighlights() {
    if (_searchMatches.isEmpty) return;
    final viewModel = context.read<NoteEditorViewModel>();
    final controller = viewModel.quillController;

    for (final match in _searchMatches) {
      controller.formatText(
        match.offset,
        match.length,
        quill.Attribute.clone(quill.Attribute.background, null),
      );
    }
  }

  void _updateActiveHighlight() {
    if (_searchMatches.isEmpty) return;
    final viewModel = context.read<NoteEditorViewModel>();
    final controller = viewModel.quillController;

    for (int i = 0; i < _searchMatches.length; i++) {
      final match = _searchMatches[i];
      final isActive = i == _currentMatchIndex;

      controller.document.compose(
        delta.Delta()
          ..retain(match.offset)
          ..retain(match.length, {
            'background': isActive ? '#FFEB3B' : '#FFF59D',
          }),
        quill.ChangeSource.local,
      );
    }
  }

  Future<void> _jumpToMatch(int index) async {
    if (_searchMatches.isEmpty || index < 0 || index >= _searchMatches.length) return;

    final match = _searchMatches[index];
    final viewModel = context.read<NoteEditorViewModel>();

    setState(() => _currentMatchIndex = index);
    _updateActiveHighlight();

    viewModel.quillController.updateSelection(
      TextSelection.collapsed(offset: match.offset + match.length),
      quill.ChangeSource.local,
    );

    await _scrollToOffsetWithPhysics(match.offset);
  }

  Future<void> _scrollToOffsetWithPhysics(int offset) async {
    if (!widget.scrollController.hasClients) return;
    final viewModel = context.read<NoteEditorViewModel>();

    if (widget.editorKey?.currentContext != null) {
      final renderObject = widget.editorKey!.currentContext!.findRenderObject();
      if (renderObject is RenderBox) {
        final y = _getOffsetYPosition(renderObject, offset, viewModel);
        if (y != null) {
          await _animateScrollToY(y);
          return;
        }
      }
    }
    await _scrollWithWeightedRatio(offset);
  }

  double? _getOffsetYPosition(RenderBox editorBox, int offset, NoteEditorViewModel viewModel) {
    try {
      final docHeight = editorBox.size.height;
      final docLength = viewModel.quillController.document.length;

      if (docLength <= 0 || docHeight <= 0) return null;

      final weightedRatio = _calculateWeightedRatio(viewModel, offset);
      final estimatedY = weightedRatio * docHeight;

      return estimatedY;
    } catch (e) {
      return null;
    }
  }

  double _calculateWeightedRatio(NoteEditorViewModel viewModel, int targetOffset) {
    final document = viewModel.quillController.document;
    final deltaDoc = document.toDelta();

    int totalWeight = 0;
    int targetWeight = 0;
    int currentOffset = 0;

    for (final op in deltaDoc.toList()) {
      int weight;
      if (op.data is String) {
        final text = op.data as String;
        weight = text.length;
      } else {
        weight = 300;
      }

      totalWeight += weight;
      if (currentOffset < targetOffset) {
        targetWeight += weight;
      }
      currentOffset += (op.data is String) ? (op.data as String).length : 1;
    }

    if (totalWeight <= 0) return 0.0;
    return (targetWeight / totalWeight).clamp(0.0, 1.0);
  }

  Future<void> _animateScrollToY(double y) async {
    if (!widget.scrollController.hasClients) return;
    final maxScroll = widget.scrollController.position.maxScrollExtent;
    final viewportHeight = widget.scrollController.position.viewportDimension;
    final targetScroll = (y - viewportHeight * 0.3).clamp(0.0, maxScroll);

    await widget.scrollController.animateTo(
      targetScroll,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _scrollWithWeightedRatio(int offset) async {
    final viewModel = context.read<NoteEditorViewModel>();
    if (widget.scrollController.hasClients) {
      final maxScroll = widget.scrollController.position.maxScrollExtent;
      final weightedRatio = _calculateWeightedRatio(viewModel, offset);
      final targetScroll = (weightedRatio * maxScroll).clamp(0.0, maxScroll);

      await widget.scrollController.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  // =========================================================================
  // 🎨 回归专业审美：去色块化、重拾折叠与图标
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<NoteEditorViewModel>();

    // 🌟 核心：剔除所有的背景包裹，直接透明，融为一体
    return Container(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          // 搜索区域
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSearchBar(theme),
          ),
          const SizedBox(height: 12),
          // 清晰的带图标 Tab
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildTabs(theme),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
          // 核心列表区域
          Expanded(
            child: _buildTabContent(theme, viewModel),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(ThemeData theme, NoteEditorViewModel viewModel) {
    switch (_selectedTab) {
      case 0:
        return DocumentOutlineWidget(
          quillController: viewModel.quillController,
          scrollController: widget.scrollController,
          editorFocusNode: widget.editorFocusNode,
        );
      case 1:
        return _buildDirectoryTree(theme, viewModel);
      default:
        return const SizedBox.shrink();
    }
  }

  // =========================================================================
  // 🔍 专业版搜索框
  // =========================================================================
  Widget _buildSearchBar(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final isDocSearch = _selectedTab == 0;
    final hasMatches = _searchMatches.isNotEmpty;
    final isFocused = _searchFocusNode.hasFocus;

    return Container(
      height: 36, // 压低高度，专业内敛
      decoration: BoxDecoration(
        color: isFocused
            ? colorScheme.surface
            : colorScheme.onSurface.withValues(alpha: 0.04), // 极淡的底色，不喧宾夺主
        borderRadius: BorderRadius.circular(6), // 回归沉稳的小圆角
        border: Border.all(
          color: isFocused ? colorScheme.primary.withValues(alpha: 0.5) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Icon(
            Icons.search_rounded,
            size: 16,
            color: isFocused ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: isDocSearch ? '搜索文档...' : '搜索全局笔记...',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
                if (isDocSearch) _calculateDocMatches(val);
              },
              onSubmitted: (val) {
                if (isDocSearch && hasMatches) {
                  final nextIndex = (_currentMatchIndex + 1) % _searchMatches.length;
                  _jumpToMatch(nextIndex);
                  _searchFocusNode.requestFocus();
                }
              },
            ),
          ),

          if (_searchQuery.isNotEmpty && isDocSearch) ...[
            Text(
              hasMatches ? '${_currentMatchIndex + 1}/${_searchMatches.length}' : '0',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: hasMatches ? colorScheme.primary : colorScheme.outline,
              ),
            ),
            const SizedBox(width: 4),
            _buildIconButton(
              Icons.keyboard_arrow_up_rounded,
              colorScheme,
                  () {
                if (hasMatches) {
                  final prevIndex = _currentMatchIndex <= 0
                      ? _searchMatches.length - 1
                      : _currentMatchIndex - 1;
                  _jumpToMatch(prevIndex);
                  _searchFocusNode.requestFocus();
                }
              },
            ),
            _buildIconButton(
              Icons.keyboard_arrow_down_rounded,
              colorScheme,
                  () {
                if (hasMatches) {
                  final nextIndex = (_currentMatchIndex + 1) % _searchMatches.length;
                  _jumpToMatch(nextIndex);
                  _searchFocusNode.requestFocus();
                }
              },
            ),
          ],

          if (_searchQuery.isNotEmpty) ...[
            Container(width: 1, height: 14, color: colorScheme.outlineVariant.withValues(alpha: 0.5), margin: const EdgeInsets.symmetric(horizontal: 4)),
            _buildIconButton(
              Icons.close_rounded,
              colorScheme,
                  () {
                _searchController.clear();
                setState(() => _searchQuery = '');
                _clearAllHighlights();
                _searchMatches.clear();
                _currentMatchIndex = -1;

                final viewModel = context.read<NoteEditorViewModel>();
                viewModel.quillController.updateSelection(
                  const TextSelection.collapsed(offset: 0),
                  quill.ChangeSource.local,
                );
                _searchFocusNode.requestFocus();
              },
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, ColorScheme colorScheme, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        hoverColor: colorScheme.onSurface.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  // =========================================================================
  // 🗂️ 带图标的清晰 Tab 导航
  // =========================================================================
  Widget _buildTabs(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        _buildTab('大纲', Icons.format_list_bulleted_rounded, 0, colorScheme),
        const SizedBox(width: 16),
        _buildTab('目录', Icons.folder_copy_rounded, 1, colorScheme),
      ],
    );
  }

  Widget _buildTab(String label, IconData icon, int index, ColorScheme colorScheme) {
    final isActive = _selectedTab == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
          _persistedLeftTab = index;
          _searchController.clear();
          _searchQuery = '';
          _clearAllHighlights();
          _searchMatches.clear();
          _currentMatchIndex = -1;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 📁 目录树：复活折叠箭头与直观层级
  // =========================================================================
  Widget _buildDirectoryTree(ThemeData theme, NoteEditorViewModel viewModel) {
    final provider = context.watch<NotesProvider>();
    final categories = provider.categories;

    Iterable<Note> allNotes = provider.notes;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      allNotes = allNotes.where((n) => n.title.toLowerCase().contains(q));
    }

    final uncategorizedNotes = allNotes.where((n) => n.categoryId == null || n.categoryId!.isEmpty).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      physics: const BouncingScrollPhysics(),
      children: [
        if (uncategorizedNotes.isNotEmpty)
          _DirectoryGroupWidget(
            theme: theme,
            title: '未分类',
            icon: Icons.inbox_rounded,
            notes: uncategorizedNotes,
            currentNoteId: viewModel.currentNote?.id,
            onNoteTap: (note) => _switchToNote(context, viewModel, note),
            initiallyExpanded: true,
          ),

        ...categories.map((cat) {
          final categoryNotes = allNotes.where((n) => n.categoryId == cat.id).toList();
          if (_searchQuery.isNotEmpty && categoryNotes.isEmpty) return const SizedBox.shrink();

          return _DirectoryGroupWidget(
            theme: theme,
            title: cat.name,
            icon: Icons.folder_outlined,
            notes: categoryNotes,
            currentNoteId: viewModel.currentNote?.id,
            onNoteTap: (note) => _switchToNote(context, viewModel, note),
            initiallyExpanded: true,
          );
        }).toList(),
      ],
    );
  }

  void _switchToNote(BuildContext context, NoteEditorViewModel viewModel, Note targetNote) async {
    if (viewModel.currentNote?.id == targetNote.id) return;
    await viewModel.saveNote();
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => NoteEditorPage(note: targetNote),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}

// =========================================================================
// 🌟 带折叠箭头和图标的分类组组件
// =========================================================================
class _DirectoryGroupWidget extends StatefulWidget {
  final ThemeData theme;
  final String title;
  final IconData icon;
  final List<Note> notes;
  final String? currentNoteId;
  final Function(Note) onNoteTap;
  final bool initiallyExpanded;

  const _DirectoryGroupWidget({
    required this.theme,
    required this.title,
    required this.icon,
    required this.notes,
    required this.currentNoteId,
    required this.onNoteTap,
    this.initiallyExpanded = true,
  });

  @override
  State<_DirectoryGroupWidget> createState() => _DirectoryGroupWidgetState();
}

class _DirectoryGroupWidgetState extends State<_DirectoryGroupWidget> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🌟 修复点：复活分类头部，带折叠箭头、Icon和悬浮背景
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(6),
            hoverColor: colorScheme.onSurface.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  // 明确的折叠/展开指示器
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                    size: 16,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  // 分类图标
                  Icon(
                      _isExpanded && widget.icon == Icons.folder_outlined ? Icons.folder_open_rounded : widget.icon,
                      size: 16,
                      color: colorScheme.onSurfaceVariant
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '${widget.notes.length}',
                    style: TextStyle(fontSize: 12, color: colorScheme.outline),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),

        // 子笔记列表，带有左侧缩进线
        if (_isExpanded && widget.notes.isNotEmpty)
          Padding(
            // 这个边距刚好把竖线对准上方图标的中心
            padding: const EdgeInsets.only(left: 12, top: 2, bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                    left: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                      width: 1.5,
                    )
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.notes.map((note) {
                  final isActive = note.id == widget.currentNoteId;
                  return _buildNoteItem(note, isActive, colorScheme);
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNoteItem(Note note, bool isActive, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 2, top: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onNoteTap(note),
          borderRadius: BorderRadius.circular(6),
          hoverColor: colorScheme.onSurface.withValues(alpha: 0.04),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              // 选中态变得克制专业，不再大面积涂抹颜色
              color: isActive ? colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                // 明确的文档图标
                Icon(
                  Icons.article_outlined,
                  size: 15,
                  color: isActive ? colorScheme.primary : colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note.title.isEmpty ? '无标题文档' : note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive ? colorScheme.primary : colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}