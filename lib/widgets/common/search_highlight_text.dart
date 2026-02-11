import 'package:flutter/material.dart';

class SearchHighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const SearchHighlightText(
      this.text, {
        super.key,
        required this.query,
        this.style,
        this.maxLines,
        this.overflow,
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 如果没有搜索词，直接返回普通文本
    if (query.isEmpty) {
      return Text(text, style: style, maxLines: maxLines, overflow: overflow);
    }

    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();
    final List<TextSpan> spans = [];
    int start = 0;

    while (true) {
      final int index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        // 剩余部分
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }

      // 匹配前的部分
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }

      // 匹配的部分 (高亮)
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: (style ?? const TextStyle()).copyWith(
          backgroundColor: theme.colorScheme.primaryContainer, // 高亮背景色
          color: theme.colorScheme.onPrimaryContainer,         // 高亮前景色
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + query.length;
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.ellipsis,
    );
  }
}