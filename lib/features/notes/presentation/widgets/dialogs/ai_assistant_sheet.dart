import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../../core/services/glm_ai_service.dart';

class AiAssistantSheet extends StatefulWidget {
  final String text;
  final String actionType;
  final String actionName;
  final String fullContext;
  final bool isDesktop;

  const AiAssistantSheet({
    super.key,
    required this.text,
    required this.actionType,
    required this.actionName,
    required this.fullContext,
    this.isDesktop = false,
  });

  @override
  State<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<AiAssistantSheet> {
  bool _isGenerating = true;
  String _resultText = '';
  String? _errorMsg;
  final ScrollController _scrollController = ScrollController();

  // 🌟 性能优化：使用 Timer 节流 setState
  Timer? _throttleTimer;
  String _pendingText = '';
  bool _hasPendingUpdate = false;

  @override
  void initState() {
    super.initState();
    _startStreaming();
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startStreaming() {
    setState(() {
      _isGenerating = true;
      _resultText = '';
      _errorMsg = null;
    });

    GlmAiService.generateContentStream(
      widget.text,
      widget.actionType,
      fullContext: widget.fullContext,
    ).listen(
          (chunk) {
        _pendingText += chunk;
        _hasPendingUpdate = true;

        // 🌟 节流：每 100ms 更新一次 UI，避免频繁重建
        if (_throttleTimer == null || !_throttleTimer!.isActive) {
          _throttleTimer = Timer(const Duration(milliseconds: 100), () {
            if (mounted && _hasPendingUpdate) {
              setState(() {
                _resultText = _pendingText;
                _hasPendingUpdate = false;
              });
              _scrollToBottom();
            }
          });
        }
      },
      onError: (e) {
        _throttleTimer?.cancel();
        if (mounted) {
          setState(() {
            _errorMsg = e.toString();
            _isGenerating = false;
          });
        }
      },
      onDone: () {
        _throttleTimer?.cancel();
        if (mounted) {
          // 确保最后的内容被渲染
          if (_hasPendingUpdate) {
            setState(() {
              _resultText = _pendingText;
              _hasPendingUpdate = false;
              _isGenerating = false;
            });
          } else {
            setState(() => _isGenerating = false);
          }
          HapticFeedback.mediumImpact();
        }
      },
    );
  }

  void _scrollToBottom() {
    // 🌟 延迟滚动，避免与构建冲突
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (maxScroll > 0) {
          _scrollController.animateTo(
            maxScroll + 50,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayText = _isGenerating ? '$_resultText▍' : _resultText;

    return Container(
      width: widget.isDesktop ? 600 : double.infinity,
      constraints: BoxConstraints(
        maxHeight: widget.isDesktop
            ? 700
            : MediaQuery.of(context).size.height * 0.8,
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: widget.isDesktop ? 24 : 16,
        bottom: widget.isDesktop ? 24 : MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: widget.isDesktop
            ? BorderRadius.circular(24)
            : const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 拖拽条（手机端）
          if (!widget.isDesktop)
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // 标题栏
          Row(
            children: [
              Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'AI ${widget.actionName}',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (_isGenerating) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 🌟 Markdown 渲染区
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                ),
              ),
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                child: _errorMsg != null
                    ? Text(
                  _errorMsg!,
                  style: TextStyle(color: theme.colorScheme.error),
                )
                    : MarkdownBody(
                  data: displayText,
                  selectable: true,
                  styleSheet: _buildMarkdownStyleSheet(theme),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 动作按钮
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _isGenerating || _errorMsg != null
                      ? null
                      : () => Navigator.pop(
                    context,
                    {'action': 'append', 'text': _resultText},
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    '追加到光标处',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _isGenerating || _errorMsg != null
                      ? null
                      : () => Navigator.pop(
                    context,
                    {'action': 'replace', 'text': _resultText},
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    '替换选中内容',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 🌟 构建 Markdown 样式表，修复列表对齐问题
  MarkdownStyleSheet _buildMarkdownStyleSheet(ThemeData theme) {
    return MarkdownStyleSheet(
      // 基础段落样式
      p: theme.textTheme.bodyLarge?.copyWith(
        height: 1.7,
        fontSize: 16,
      ),

      // 标题样式
      h1: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
        height: 1.3,
      ),
      h2: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        height: 1.35,
      ),
      h3: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      h4: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),

      // 🌟 修复列表对齐：统一使用左对齐和适当的缩进
      listBullet: TextStyle(
        color: theme.colorScheme.primary,
        fontSize: 16,
        height: 1.7,
      ),
      listBulletPadding: const EdgeInsets.only(left: 8, right: 8),

      // 列表项样式
      listIndent: 24, // 🌟 关键：统一缩进距离

      // 代码样式
      code: TextStyle(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        color: theme.colorScheme.onSurface,
        fontFamily: 'monospace',
        fontSize: 14,
        height: 1.5,
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      codeblockPadding: const EdgeInsets.all(12),

      // 引用样式
      blockquote: TextStyle(
        fontSize: 16,
        height: 1.7,
        fontStyle: FontStyle.italic,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary,
            width: 4,
          ),
        ),
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),

      // 段落间距
      blockSpacing: 12,

      // 强调样式
      em: TextStyle(
        fontStyle: FontStyle.italic,
        height: 1.7,
      ),
      strong: TextStyle(
        fontWeight: FontWeight.bold,
        height: 1.7,
      ),

      // 分隔线
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
    );
  }
}
