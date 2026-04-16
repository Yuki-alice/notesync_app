import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// 文档大纲组件 - 实现双向奔赴功能
/// 
/// 功能：
/// 1. 从Quill文档中提取H1-H3标题，构建层级大纲
/// 2. 点击大纲项 -> 滚动编辑器到对应位置
/// 3. 编辑器滚动 -> 高亮当前可见的标题
class DocumentOutlineWidget extends StatefulWidget {
  final quill.QuillController quillController;
  final ScrollController scrollController;
  final FocusNode editorFocusNode;
  final VoidCallback? onHeadingTap;

  const DocumentOutlineWidget({
    super.key,
    required this.quillController,
    required this.scrollController,
    required this.editorFocusNode,
    this.onHeadingTap,
  });

  @override
  State<DocumentOutlineWidget> createState() => _DocumentOutlineWidgetState();
}

class _DocumentOutlineWidgetState extends State<DocumentOutlineWidget> {
  // 缓存的标题列表
  List<HeadingItem> _headings = [];
  
  // 当前高亮的标题offset
  int _activeHeadingOffset = -1;
  
  // 折叠的标题offsets
  final Set<int> _collapsedOffsets = {};
  
  // 互斥锁：防止点击大纲引发的滚动反过来触发高亮更新
  bool _isManualScrolling = false;
  Timer? _manualScrollTimer;

  // 滚动监听节流
  Timer? _scrollThrottleTimer;

  @override
  void initState() {
    super.initState();
    
    // 初始化标题列表
    _updateHeadings();
    
    // 监听文档变化
    widget.quillController.addListener(_onDocumentChanged);
    
    // 监听滚动 - 使用节流
    widget.scrollController.addListener(_onScrollThrottled);
  }

  @override
  void dispose() {
    widget.quillController.removeListener(_onDocumentChanged);
    widget.scrollController.removeListener(_onScrollThrottled);
    _manualScrollTimer?.cancel();
    _scrollThrottleTimer?.cancel();
    super.dispose();
  }

  /// 文档变化时更新标题列表
  void _onDocumentChanged() {
    if (!mounted) return;
    
    // 使用SchedulerBinding避免在构建过程中setState
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateHeadings();
      }
    });
  }

  /// 节流的滚动监听
  void _onScrollThrottled() {
    if (!mounted || _isManualScrolling) return;
    
    _scrollThrottleTimer?.cancel();
    _scrollThrottleTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted && !_isManualScrolling) {
        _calculateActiveHeadingFromScroll();
      }
    });
  }

  /// 从文档中提取标题
  void _updateHeadings() {
    final headings = <HeadingItem>[];
    
    for (final node in widget.quillController.document.root.children) {
      if (node is quill.Line) {
        final headerAttr = node.style.attributes['header'];
        if (headerAttr != null) {
          final text = node.toPlainText().trim();
          if (text.isNotEmpty) {
            headings.add(HeadingItem(
              level: headerAttr.value as int,
              text: text,
              offset: node.documentOffset,
            ));
          }
        }
      }
    }

    if (_headings.length != headings.length || 
        !_listEquals(_headings, headings)) {
      setState(() {
        _headings = headings;
      });
    }
  }

  /// 比较两个标题列表是否相等
  bool _listEquals(List<HeadingItem> a, List<HeadingItem> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].offset != b[i].offset || 
          a[i].text != b[i].text || 
          a[i].level != b[i].level) {
        return false;
      }
    }
    return true;
  }

  /// 根据滚动位置计算当前高亮的标题
  /// 
  /// 算法说明：
  /// 1. 获取当前视口顶部位置 + 偏移量（考虑顶部留白）
  /// 2. 根据滚动比例估算当前阅读位置
  /// 3. 找到最接近当前阅读位置的标题
  void _calculateActiveHeadingFromScroll() {
    if (_headings.isEmpty || !widget.scrollController.hasClients) return;

    final currentScroll = widget.scrollController.offset;
    final maxScroll = widget.scrollController.position.maxScrollExtent;
    
    if (maxScroll <= 0) {
      // 文档很短，不需要滚动
      if (_headings.isNotEmpty && _activeHeadingOffset != _headings.first.offset) {
        setState(() => _activeHeadingOffset = _headings.first.offset);
      }
      return;
    }

    // 计算阅读进度比例 (0.0 - 1.0)
    final scrollRatio = currentScroll / maxScroll;
    
    // 根据阅读进度找到对应的标题索引
    final headingIndex = (scrollRatio * _headings.length).floor();
    final clampedIndex = math.max(0, math.min(headingIndex, _headings.length - 1));
    
    final nearestOffset = _headings[clampedIndex].offset;

    if (_activeHeadingOffset != nearestOffset) {
      setState(() => _activeHeadingOffset = nearestOffset);
    }
  }

  /// 点击标题滚动到对应位置
  /// 
  /// 修复后的算法：
  /// 1. 根据标题在标题列表中的位置比例计算目标滚动位置
  /// 2. 考虑顶部留白和视口高度进行微调
  Future<void> _scrollToHeading(int offset) async {
    if (!widget.scrollController.hasClients) return;

    // 上锁
    setState(() {
      _isManualScrolling = true;
      _activeHeadingOffset = offset;
    });

    // 取消之前的解锁定时器
    _manualScrollTimer?.cancel();

    // 设置光标位置
    widget.quillController.updateSelection(
      TextSelection.collapsed(offset: offset),
      quill.ChangeSource.local,
    );
    widget.editorFocusNode.requestFocus();

    // 找到标题在列表中的索引
    final headingIndex = _headings.indexWhere((h) => h.offset == offset);
    if (headingIndex < 0) return;

    final maxScroll = widget.scrollController.position.maxScrollExtent;
    
    if (maxScroll <= 0) {
      // 文档很短，不需要滚动
      _unlockManualScroll();
      return;
    }

    // 计算目标滚动位置
    // 根据标题在列表中的位置比例计算
    final targetRatio = headingIndex / (_headings.length - 1);
    
    // 应用滚动，让标题位于视口上方约1/4处
    double targetScroll = targetRatio * maxScroll;
    
    // 边界检查
    targetScroll = targetScroll.clamp(0.0, maxScroll);

    await widget.scrollController.animateTo(
      targetScroll,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );

    _unlockManualScroll();
    widget.onHeadingTap?.call();
  }

  /// 解锁手动滚动状态
  void _unlockManualScroll() {
    // 延迟解锁，避免滚动动画期间的抖动
    _manualScrollTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _isManualScrolling = false);
      }
    });
  }

  /// 获取可见的标题列表（处理折叠）
  List<HeadingItem> _getVisibleHeadings() {
    final visible = <HeadingItem>[];
    int? collapsedLevel;

    for (final heading in _headings) {
      // 如果被折叠，跳过子级
      if (collapsedLevel != null && heading.level > collapsedLevel) {
        continue;
      }
      collapsedLevel = null;

      visible.add(heading);

      // 检查是否被折叠
      if (_collapsedOffsets.contains(heading.offset)) {
        collapsedLevel = heading.level;
      }
    }

    return visible;
  }

  /// 检查标题是否有子级
  bool _hasChildren(HeadingItem heading, int index) {
    if (index + 1 >= _headings.length) return false;
    
    for (int i = index + 1; i < _headings.length; i++) {
      if (_headings[i].level > heading.level) {
        return true;
      } else if (_headings[i].level <= heading.level) {
        break;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_headings.isEmpty) {
      return Center(
        child: Text(
          '无标题层级\n使用 # 或 ## 创建标题',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.colorScheme.outline,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      );
    }

    final visibleHeadings = _getVisibleHeadings();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: visibleHeadings.length,
      itemBuilder: (context, index) {
        final heading = visibleHeadings[index];
        final isActive = heading.offset == _activeHeadingOffset;
        final isCollapsed = _collapsedOffsets.contains(heading.offset);
        
        // 找到原始索引以检查子级
        final originalIndex = _headings.indexWhere((h) => h.offset == heading.offset);
        final hasChildren = _hasChildren(heading, originalIndex);

        return _buildHeadingItem(
          theme: theme,
          heading: heading,
          isActive: isActive,
          isCollapsed: isCollapsed,
          hasChildren: hasChildren,
        );
      },
    );
  }

  Widget _buildHeadingItem({
    required ThemeData theme,
    required HeadingItem heading,
    required bool isActive,
    required bool isCollapsed,
    required bool hasChildren,
  }) {
    // 根据层级计算缩进和样式
    final indent = 28.0 + (heading.level - 1) * 16.0;
    final fontSize = heading.level == 1 ? 14.0 : 13.0;
    final fontWeight = isActive 
        ? FontWeight.bold 
        : (heading.level == 1 ? FontWeight.w600 : FontWeight.w400);

    return InkWell(
      onTap: () => _scrollToHeading(heading.offset),
      child: Container(
        decoration: BoxDecoration(
          color: isActive 
              ? theme.colorScheme.primary.withValues(alpha: 0.08) 
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isActive ? theme.colorScheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Stack(
          children: [
            // 标题文本
            Padding(
              padding: EdgeInsets.only(
                left: indent,
                right: 12,
                top: 8,
                bottom: 8,
              ),
              child: Text(
                heading.text,
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.4,
                  color: isActive 
                      ? theme.colorScheme.primary 
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: fontWeight,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 折叠按钮
            if (hasChildren)
              Positioned(
                left: 6.0 + (heading.level - 1) * 16.0,
                top: 6,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isCollapsed) {
                        _collapsedOffsets.remove(heading.offset);
                      } else {
                        _collapsedOffsets.add(heading.offset);
                      }
                    });
                  },
                  child: Icon(
                    isCollapsed 
                        ? Icons.keyboard_arrow_right_rounded 
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 标题项数据类
class HeadingItem {
  final int level;      // H1=1, H2=2, H3=3
  final String text;    // 标题文本
  final int offset;     // 文档中的字符偏移量

  const HeadingItem({
    required this.level,
    required this.text,
    required this.offset,
  });

  @override
  String toString() => 'H$level: $text (@$offset)';
}
