import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData getTheme({
    required BuildContext context,
    required Color seedColor,
    required bool isDark,
  }) {
    final textTheme = GoogleFonts.notoSansScTextTheme(Theme.of(context).textTheme);
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final bgColor = isDark ? const Color(0xFF1A1C1E) : const Color(0xFFFDFDFD);
    final inputFillColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05);

    return ThemeData(
      textTheme: textTheme,
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
        surfaceTint: seedColor.withValues(alpha: isDark ? 0.1 : 0.05),
      ),
      scaffoldBackgroundColor: bgColor,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}