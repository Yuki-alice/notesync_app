import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_fonts.dart';

// 🌟 返璞归真的构建器：不再瞎算高度，靠底层自然对齐
class _CustomCheckboxBuilder extends quill.QuillCheckboxBuilder {
  @override
  Widget build({
    required BuildContext context,
    required bool isChecked,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    return Container(
      // 细微的像素级下推，让方框的视觉中心与中文绝对水平
      margin: const EdgeInsets.only(top: 2.0),
      child: Checkbox(
        value: isChecked,
        onChanged: (bool? value) {
          if (value != null) onChanged(value);
        },
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // 剥离多余响应区
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4), // 极限压缩自带边距
        activeColor: theme.colorScheme.primary,
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1.5),
      ),
    );
  }
}

/// 🌟 NoteSync 商业级 Quill 编辑器样式配置
class QuillStylesConfig {
  /// 获取桌面端样式配置
  static quill.DefaultStyles getDesktopStyles(BuildContext context) {
    final theme = Theme.of(context);

    return quill.DefaultStyles(
      paragraph: quill.DefaultTextBlockStyle(
        AppFonts.desktopBody(context),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(8, 8),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      h1: quill.DefaultTextBlockStyle(
        AppFonts.desktopH1(context),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(32, 16),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      h2: quill.DefaultTextBlockStyle(
        AppFonts.desktopH2(context),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(24, 12),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      h3: quill.DefaultTextBlockStyle(
        AppFonts.desktopH3(context),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(20, 10),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      quote: quill.DefaultTextBlockStyle(
        AppFonts.desktopQuote(context),
        const quill.HorizontalSpacing(20, 0),
        const quill.VerticalSpacing(16, 16),
        const quill.VerticalSpacing(0, 0),
        BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
          border: Border(
            left: BorderSide(color: theme.colorScheme.primary, width: 4),
          ),
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
        ),
      ),
      code: quill.DefaultTextBlockStyle(
        AppFonts.desktopCode(context),
        const quill.HorizontalSpacing(16, 16),
        const quill.VerticalSpacing(12, 12),
        const quill.VerticalSpacing(0, 0),
        BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      // 🌟 桌面端列表样式：降维打击修复法
      lists: quill.DefaultListBlockStyle(
        // 核心魔法：强行把行高压低到 1.25，把上浮的文字“拽”回基准线上！
        AppFonts.desktopList(context).copyWith(height: 1.25),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(8, 8),
        const quill.VerticalSpacing(8, 8), // 稍微增大项间距，弥补行高压低后的紧凑感
        null,
        _CustomCheckboxBuilder(),
      ),
    );
  }

  /// 获取手机端样式配置
  static quill.DefaultStyles getMobileStyles(BuildContext context) {
    final theme = Theme.of(context);

    return quill.DefaultStyles(
      paragraph: quill.DefaultTextBlockStyle(
        AppFonts.mobileBody(context),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(6, 6),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      h1: quill.DefaultTextBlockStyle(
        AppFonts.mobileH1(context),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(24, 12),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      h2: quill.DefaultTextBlockStyle(
        AppFonts.mobileH2(context),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(20, 10),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      h3: quill.DefaultTextBlockStyle(
        AppFonts.mobileH3(context),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(16, 8),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      quote: quill.DefaultTextBlockStyle(
        AppFonts.mobileQuote(context),
        const quill.HorizontalSpacing(16, 0),
        const quill.VerticalSpacing(12, 12),
        const quill.VerticalSpacing(0, 0),
        BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
          border: Border(
            left: BorderSide(color: theme.colorScheme.primary, width: 3),
          ),
          borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
        ),
      ),
      code: quill.DefaultTextBlockStyle(
        AppFonts.mobileCode(context),
        const quill.HorizontalSpacing(12, 12),
        const quill.VerticalSpacing(10, 10),
        const quill.VerticalSpacing(0, 0),
        BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      // 🌟 手机端列表样式
      lists: quill.DefaultListBlockStyle(
        AppFonts.mobileList(context).copyWith(height: 1.25),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(6, 6),
        const quill.VerticalSpacing(6, 6),
        null,
        _CustomCheckboxBuilder(),
      ),
    );
  }

  /// 兼容旧版 API
  static quill.DefaultStyles getStyles(ThemeData theme) {
    final listTextStyle = GoogleFonts.notoSansSc(
      fontSize: 16,
      height: 1.25, // 这里也要改
      letterSpacing: 0.2,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
    );

    return quill.DefaultStyles(
      paragraph: quill.DefaultTextBlockStyle(
        listTextStyle.copyWith(height: 1.8),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(6, 6),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      lists: quill.DefaultListBlockStyle(
        listTextStyle,
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(8, 8),
        const quill.VerticalSpacing(8, 8),
        null,
        _CustomCheckboxBuilder(),
      ),
    );
  }
}