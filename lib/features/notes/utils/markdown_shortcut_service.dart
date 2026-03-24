import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// 🟢 架构师解耦：专门负责拦截用户输入，实现“所见即所得”快捷转换的服务
class MarkdownShortcutService {
  /// 返回 true 表示拦截并处理了快捷键，false 表示未触发
  static bool format(quill.QuillController controller) {
    final selection = controller.selection;
    if (!selection.isCollapsed) return false;

    final index = selection.baseOffset;
    if (index <= 0) return false;

    // 检查刚敲击的最后一个字符是不是空格
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

    // 获取当前行光标前面的文本
    final textBeforeCursor = text.substring(lineStart, index);

    quill.Attribute? attributeToApply;
    int lengthToDelete = 0;

    // 🌟 丰富的 Markdown 语法支持
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
    } else if (textBeforeCursor == '> ' || textBeforeCursor == '》 ') { // 支持引用
      attributeToApply = quill.Attribute.blockQuote;
      lengthToDelete = 2;
    } else if (textBeforeCursor == '``` ') { // 支持代码块
      attributeToApply = quill.Attribute.codeBlock;
      lengthToDelete = 4;
    }

    if (attributeToApply != null) {
      Future.microtask(() {
        // 🟢 核心修复：原子化操作！
        // 用 replaceText 同时完成“删除触发字符”和“移动光标”，绝不给 UI 报错的空隙！
        final newSelection = TextSelection.collapsed(offset: index - lengthToDelete);

        controller.replaceText(
          lineStart,
          lengthToDelete,
          '',
          newSelection,
        );

        controller.formatText(lineStart, 0, attributeToApply!);
      });
      return true;
    }
    return false;
  }
}