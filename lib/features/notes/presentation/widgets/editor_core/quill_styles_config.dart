import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_fonts.dart';

/// 🌟 NoteSync 商业级 Quill 编辑器样式配置
/// 
/// 特性：
/// - 双端适配：桌面端更大更舒适，手机端更紧凑
/// - 中文字体优化：使用思源黑体/宋体
/// - 专业排版：精心调校的字号、行高、间距
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
      lists: quill.DefaultListBlockStyle(
        AppFonts.desktopList(context),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(8, 8),
        const quill.VerticalSpacing(6, 6),
        null,
        null,
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
      lists: quill.DefaultListBlockStyle(
        AppFonts.mobileList(context),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(6, 6),
        const quill.VerticalSpacing(4, 4),
        null,
        null,
      ),
    );
  }

  /// 兼容旧版 API（默认使用桌面端样式）
  @Deprecated('请使用 getDesktopStyles 或 getMobileStyles')
  static quill.DefaultStyles getStyles(ThemeData theme) {
    // 使用缓存的字体基础样式，避免重复网络请求
    final defaultTextStyle = AppFonts.primaryFont.isEmpty 
        ? TextStyle(
            fontSize: 16,
            height: 1.8,
            letterSpacing: 0.3,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
          )
        : GoogleFonts.notoSansSc(
            fontSize: 16,
            height: 1.8,
            letterSpacing: 0.3,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
          );
    
    final listTextStyle = AppFonts.primaryFont.isEmpty
        ? TextStyle(
            fontSize: 16,
            height: 1.6,
            letterSpacing: 0.2,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
          )
        : GoogleFonts.notoSansSc(
            fontSize: 16,
            height: 1.6,
            letterSpacing: 0.2,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
          );

    // 缓存基础字体样式，避免重复创建
    final notoSansBase = AppFonts.primaryFont.isEmpty 
        ? null 
        : GoogleFonts.notoSansSc();
    final notoSerifBase = AppFonts.readingFont.isEmpty 
        ? null 
        : GoogleFonts.notoSerifSc();
    final firaCodeBase = AppFonts.codeFont.isEmpty 
        ? null 
        : GoogleFonts.firaCode();

    return quill.DefaultStyles(
      paragraph: quill.DefaultTextBlockStyle(
        defaultTextStyle,
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(6, 6),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      h1: quill.DefaultTextBlockStyle(
        notoSansBase?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          height: 1.25,
          letterSpacing: 0.5,
          color: theme.colorScheme.onSurface,
        ) ?? TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          height: 1.25,
          letterSpacing: 0.5,
          color: theme.colorScheme.onSurface,
        ),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(28, 12),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      h2: quill.DefaultTextBlockStyle(
        notoSansBase?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.3,
          letterSpacing: 0.3,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.95),
        ) ?? TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.3,
          letterSpacing: 0.3,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.95),
        ),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(20, 10),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      h3: quill.DefaultTextBlockStyle(
        notoSansBase?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.35,
          letterSpacing: 0.2,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
        ) ?? TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.35,
          letterSpacing: 0.2,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
        ),
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(16, 8),
        const quill.VerticalSpacing(0, 0),
        null,
      ),
      quote: quill.DefaultTextBlockStyle(
        notoSerifBase?.copyWith(
          fontSize: 15,
          height: 1.7,
          letterSpacing: 0.2,
          fontStyle: FontStyle.italic,
          color: theme.colorScheme.onSurfaceVariant,
        ) ?? TextStyle(
          fontSize: 15,
          height: 1.7,
          letterSpacing: 0.2,
          fontStyle: FontStyle.italic,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const quill.HorizontalSpacing(16, 0),
        const quill.VerticalSpacing(12, 12),
        const quill.VerticalSpacing(0, 0),
        BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          border: Border(
            left: BorderSide(color: theme.colorScheme.primary, width: 4),
          ),
        ),
      ),
      code: quill.DefaultTextBlockStyle(
        firaCodeBase?.copyWith(
          fontSize: 14,
          height: 1.5,
          color: theme.colorScheme.onSurfaceVariant,
        ) ?? TextStyle(
          fontSize: 14,
          height: 1.5,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const quill.HorizontalSpacing(16, 16),
        const quill.VerticalSpacing(12, 12),
        const quill.VerticalSpacing(0, 0),
        BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      lists: quill.DefaultListBlockStyle(
        listTextStyle,
        const quill.HorizontalSpacing(0, 0),
        const quill.VerticalSpacing(8, 8),
        const quill.VerticalSpacing(6, 6),
        null,
        null,
      ),
    );
  }
}
