import 'package:flutter/material.dart';

import 'palette.dart';
import 'tokens.dart';

/// Builds the Material 3 [ThemeData] for Synapse and attaches [SynapseTokens].
/// Dark is the default (prompt 02 §5). Typography follows the style scale (§2)
/// on the platform default font so the app is fully offline — no runtime font
/// fetching (golden rule #5).
class SynapseTheme {
  const SynapseTheme._();

  static ThemeData dark() => _build(SynapseTokens.dark());
  static ThemeData light() => _build(SynapseTokens.light());

  static ThemeData _build(SynapseTokens t) {
    final isDark = t.isDark;
    final scheme = ColorScheme.fromSeed(
      seedColor: Palette.brand,
      brightness: t.brightness,
    ).copyWith(
      primary: t.primary,
      onPrimary: t.onPrimary,
      surface: t.surface,
      onSurface: t.text,
      error: t.danger,
      outline: t.border,
    );

    final text = _textTheme(t);

    return ThemeData(
      useMaterial3: true,
      brightness: t.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.bg,
      canvasColor: t.bg,
      splashFactory: InkSparkle.splashFactory,
      textTheme: text,
      extensions: [t],
      dividerTheme: DividerThemeData(color: t.border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: t.text, size: 22),
      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: t.text),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: t.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.border),
        ),
        textStyle: text.labelMedium?.copyWith(color: t.text),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(t.textFaint.withValues(alpha: 0.4)),
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(6),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.surfaceHigh,
        contentTextStyle: text.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      shadowColor: isDark ? Palette.brand.withValues(alpha: 0.2) : Colors.black26,
    );
  }

  static TextTheme _textTheme(SynapseTokens t) {
    TextStyle s(double size, FontWeight w, double height, double ls, {Color? c}) =>
        TextStyle(
          fontSize: size,
          fontWeight: w,
          height: height,
          letterSpacing: ls,
          color: c ?? t.text,
        );

    return TextTheme(
      displayLarge: s(38, FontWeight.w800, 1.10, -0.5),
      displayMedium: s(32, FontWeight.w800, 1.12, -0.5),
      displaySmall: s(28, FontWeight.w700, 1.16, -0.4),
      headlineLarge: s(26, FontWeight.w700, 1.20, -0.3),
      headlineMedium: s(22, FontWeight.w700, 1.22, -0.3),
      headlineSmall: s(20, FontWeight.w700, 1.25, -0.2),
      titleLarge: s(18, FontWeight.w700, 1.30, 0),
      titleMedium: s(16, FontWeight.w600, 1.30, 0),
      titleSmall: s(14, FontWeight.w600, 1.35, 0.1),
      bodyLarge: s(16, FontWeight.w400, 1.50, 0),
      bodyMedium: s(14, FontWeight.w400, 1.50, 0),
      bodySmall: s(13, FontWeight.w400, 1.45, 0.1, c: t.textMuted),
      labelLarge: s(14, FontWeight.w600, 1.35, 0.2),
      labelMedium: s(12.5, FontWeight.w500, 1.40, 0.2),
      labelSmall: s(11.5, FontWeight.w500, 1.40, 0.3, c: t.textMuted),
    );
  }
}
