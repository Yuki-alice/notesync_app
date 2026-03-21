import 'package:flutter_quill/flutter_quill.dart' as quill;

class MarkdownExportService {
  static String generate(String title, quill.QuillController controller) {
    final delta = controller.document.toDelta();
    final buffer = StringBuffer();

    if (title.isNotEmpty) {
      buffer.writeln('# $title\n');
    }

    String currentLine = '';

    for (final op in delta.toList()) {
      if (op.data is String) {
        final text = op.data as String;
        final attrs = op.attributes ?? {};

        if (text == '\n') {
          _appendLineToMarkdown(buffer, currentLine, attrs);
          currentLine = '';
        } else if (text.contains('\n')) {
          final parts = text.split('\n');
          for (int i = 0; i < parts.length - 1; i++) {
            currentLine += _formatInlineMarkdown(parts[i], attrs);
            _appendLineToMarkdown(buffer, currentLine, attrs);
            currentLine = '';
          }
          currentLine += _formatInlineMarkdown(parts.last, attrs);
        } else {
          currentLine += _formatInlineMarkdown(text, attrs);
        }
      } else if (op.data is Map) {
        final dataMap = op.data as Map;
        if (dataMap.containsKey('image')) {
          final imagePath = dataMap['image'];
          currentLine += '\n![图片]($imagePath)\n';
        }
      }
    }

    if (currentLine.isNotEmpty) {
      _appendLineToMarkdown(buffer, currentLine, {});
    }

    return buffer.toString().trim();
  }

  static String _formatInlineMarkdown(String text, Map<String, dynamic> attrs) {
    if (text.isEmpty) return text;
    String result = text;
    if (attrs['bold'] == true) result = '**$result**';
    if (attrs['italic'] == true) result = '*$result*';
    if (attrs['strike'] == true) result = '~~$result~~';
    if (attrs['code'] == true) result = '`$result`';
    return result;
  }

  static void _appendLineToMarkdown(StringBuffer buffer, String lineText, Map<String, dynamic> blockAttrs) {
    if (blockAttrs['header'] != null) {
      final level = blockAttrs['header'] as int;
      buffer.writeln('${"#" * level} $lineText\n');
    } else if (blockAttrs['blockquote'] == true) {
      buffer.writeln('> $lineText\n');
    } else if (blockAttrs['list'] == 'bullet') {
      buffer.writeln('- $lineText');
    } else if (blockAttrs['list'] == 'ordered') {
      buffer.writeln('1. $lineText');
    } else if (blockAttrs['list'] == 'checked') {
      buffer.writeln('- [x] $lineText');
    } else if (blockAttrs['list'] == 'unchecked') {
      buffer.writeln('- [ ] $lineText');
    } else {
      buffer.writeln(lineText);
    }
  }
}