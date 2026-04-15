import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:google_fonts/google_fonts.dart';

class QuillStylesConfig {
  static quill.DefaultStyles getStyles(ThemeData theme) {
    final defaultTextStyle = TextStyle(fontSize: 16, height: 1.8, color: theme.colorScheme.onSurface.withValues(alpha: 0.9), letterSpacing: 0.4);
    final listTextStyle = TextStyle(fontSize: 16, height: 1.25, color: theme.colorScheme.onSurface.withValues(alpha: 0.9), letterSpacing: 0.4);

    return quill.DefaultStyles(
      paragraph: quill.DefaultTextBlockStyle(defaultTextStyle, const quill.HorizontalSpacing(0, 0), const quill.VerticalSpacing(6, 6), const quill.VerticalSpacing(0, 0), null),
      h1: quill.DefaultTextBlockStyle(TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.3, color: theme.colorScheme.onSurface, letterSpacing: 0.5), const quill.HorizontalSpacing(0, 0), const quill.VerticalSpacing(28, 12), const quill.VerticalSpacing(0, 0), null),
      h2: quill.DefaultTextBlockStyle(TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.3, color: theme.colorScheme.onSurface.withValues(alpha: 0.9)), const quill.HorizontalSpacing(0, 0), const quill.VerticalSpacing(20, 10), const quill.VerticalSpacing(0, 0), null),
      h3: quill.DefaultTextBlockStyle(TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3, color: theme.colorScheme.onSurface.withValues(alpha: 0.85)), const quill.HorizontalSpacing(0, 0), const quill.VerticalSpacing(16, 8), const quill.VerticalSpacing(0, 0), null),
      quote: quill.DefaultTextBlockStyle(TextStyle(fontSize: 15, height: 1.6, color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic), const quill.HorizontalSpacing(16, 0), const quill.VerticalSpacing(12, 12), const quill.VerticalSpacing(0, 0), BoxDecoration(color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3), border: Border(left: BorderSide(color: theme.colorScheme.primary, width: 4)))),
      code: quill.DefaultTextBlockStyle(GoogleFonts.firaCode(fontSize: 14, height: 1.5, color: theme.colorScheme.onSurfaceVariant), const quill.HorizontalSpacing(16, 16), const quill.VerticalSpacing(12, 12), const quill.VerticalSpacing(0, 0), BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)))),
      lists: quill.DefaultListBlockStyle(listTextStyle, const quill.HorizontalSpacing(0, 0), const quill.VerticalSpacing(8, 8), const quill.VerticalSpacing(6, 6), null, null),
    );
  }
}