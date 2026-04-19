import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // 🌟 新增：引入 Markdown 渲染引擎
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
    this.isDesktop=false,
  });

  @override
  State<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<AiAssistantSheet> {
  bool _isGenerating = true;
  String _resultText = '';
  String? _errorMsg;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _startStreaming();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _startStreaming() {
    setState(() {
      _isGenerating = true;
      _resultText = '';
      _errorMsg = null;
    });

    GlmAiService.generateContentStream(widget.text, widget.actionType,fullContext: widget.fullContext).listen(
          (chunk) {
        if (mounted) {
          setState(() => _resultText += chunk);
          _scrollToBottom();
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _errorMsg = e.toString();
            _isGenerating = false;
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isGenerating = false;
          });
          HapticFeedback.mediumImpact();
        }
      },
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 50,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayText = _isGenerating ? '$_resultText ▍' : _resultText;

    return Container(
      // 🌟 2. 桌面端锁死宽度 600，手机端撑满
      width: widget.isDesktop ? 600 : double.infinity,
      constraints: BoxConstraints(
          maxHeight: widget.isDesktop ? 700 : MediaQuery.of(context).size.height * 0.8
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24,
        top: widget.isDesktop ? 24 : 16, // 桌面端顶部留白多一点
        bottom: widget.isDesktop ? 24 : MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        // 🌟 3. 桌面端四周全圆角，手机端只有顶部圆角
        borderRadius: widget.isDesktop
            ? BorderRadius.circular(24)
            : const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 🌟 4. 桌面端隐藏这个手机专属的顶部拖拽条
          if (!widget.isDesktop)
            Center(
              child: Container(
                width: 40, height: 4,
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
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (_isGenerating) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                )
              ],
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 16),

          // 🌟 核心升级：Markdown 渲染区
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
              ),
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                child: _errorMsg != null
                    ? Text(_errorMsg!, style: TextStyle(color: theme.colorScheme.error))
                    : MarkdownBody(
                  data: displayText,
                  selectable: true, // 允许用户手动选中复制
                  styleSheet: MarkdownStyleSheet(
                    blockSpacing: 16.0,
                    p: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                    h1: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    h2: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    h3: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    listBullet: TextStyle(color: theme.colorScheme.primary, fontSize: 18),
                    code: TextStyle(
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      color: theme.colorScheme.onSurface,
                      fontFamily: 'monospace',
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    blockquoteDecoration: BoxDecoration(
                      border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 4)),
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                    ),
                    blockquotePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
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
                      : () => Navigator.pop(context, {'action': 'append', 'text': _resultText}),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('追加到光标处', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _isGenerating || _errorMsg != null
                      ? null
                      : () => Navigator.pop(context, {'action': 'replace', 'text': _resultText}),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('替换选中内容', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}