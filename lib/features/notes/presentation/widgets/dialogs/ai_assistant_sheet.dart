import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/services/glm_ai_service.dart';

class AiAssistantSheet extends StatefulWidget {
  final String text;
  final String actionType;
  final String actionName;

  const AiAssistantSheet({
    super.key,
    required this.text,
    required this.actionType,
    required this.actionName,
  });

  @override
  State<AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<AiAssistantSheet> {
  bool _isLoading = true;
  String _resultText = '';
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _fetchAiResponse();
  }

  Future<void> _fetchAiResponse() async {
    try {
      final result = await GlmAiService.generateContent(widget.text, widget.actionType);
      if (mounted) {
        setState(() {
          _resultText = result;
          _isLoading = false;
        });
        HapticFeedback.mediumImpact(); // 生成完毕震动提示
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部拖拽条
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
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 16),

          // 内容区
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: _isLoading
                    ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: theme.colorScheme.primary),
                        const SizedBox(height: 16),
                        Text('大模型正在思考...', style: TextStyle(color: theme.colorScheme.outline)),
                      ],
                    ),
                  ),
                )
                    : _errorMsg != null
                    ? Text(_errorMsg!, style: TextStyle(color: theme.colorScheme.error))
                    : SelectableText(
                  _resultText,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 动作按钮
          if (!_isLoading && _errorMsg == null)
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.pop(context, {'action': 'append', 'text': _resultText}),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('追加到光标处', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, {'action': 'replace', 'text': _resultText}),
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