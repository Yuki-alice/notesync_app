import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// 🟢 架构师解耦：专门负责拦截用户输入，实现“所见即所得”快捷转换的服务
class MarkdownShortcutService {
  /// 返回 true 表示拦截并处理了快捷键，false 表示未触发
  static bool format(quill.QuillController controller) {
    final selection = controller.selection;
    if (!selection.isCollapsed) return false;

    final index = selection.baseOffset;
    if (index <= 0) return false;

    final lastChar = controller.document.getPlainText(index - 1, 1);
    if (lastChar != ' ') return false;

    final text = controller.document.toPlainText();
    int lineStart = 0;
    for (int i = index - 2; i >= 0; i--) {
      if (text[i] == '\n') {
        lineStart = i + 1;
        break;
      }
    }

    final textBeforeCursor = text.substring(lineStart, index);

    quill.Attribute? attributeToApply;
    int lengthToDelete = 0;

    // TODO: 后续我们可以在这里极速增加 ``` 代码块、> 引用块等高级功能！
    if (textBeforeCursor == '# ') {
      attributeToApply = quill.Attribute.h1;
      lengthToDelete = 2;
    } else if (textBeforeCursor == '## ') {
      attributeToApply = quill.Attribute.h2;
      lengthToDelete = 3;
    } else if (textBeforeCursor == '### ') {
      attributeToApply = quill.Attribute.h3;
      lengthToDelete = 4;
    } else if (textBeforeCursor == '- ' || textBeforeCursor == '* ' || textBeforeCursor == '+ ') {
      attributeToApply = quill.Attribute.ul;
      lengthToDelete = 2;
    } else if (RegExp(r'^\d+\.\s$').hasMatch(textBeforeCursor)) {
      attributeToApply = quill.Attribute.ol;
      lengthToDelete = textBeforeCursor.length;
    } else if (textBeforeCursor == '[] ' || textBeforeCursor == '[ ] ') {
      attributeToApply = quill.Attribute.unchecked;
      lengthToDelete = textBeforeCursor.length;
    } else if (textBeforeCursor == '[x] ' || textBeforeCursor == '[X] ') {
      attributeToApply = quill.Attribute.checked;
      lengthToDelete = textBeforeCursor.length;
    } else if (textBeforeCursor == '< ') {
      attributeToApply = quill.Attribute.blockQuote;
      lengthToDelete = 2;
    }

    if (attributeToApply != null) {
      Future.microtask(() {
        controller.document.delete(lineStart, lengthToDelete);
        controller.formatText(lineStart, 0, attributeToApply!);
        controller.updateSelection(
          TextSelection.collapsed(offset: index - lengthToDelete),
          quill.ChangeSource.local,
        );
      });
      return true;
    }
    return false;
  }
}