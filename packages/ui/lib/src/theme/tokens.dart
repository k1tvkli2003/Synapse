import 'package:flutter/material.dart';
import 'package:synapse_core/synapse_core.dart';

import 'palette.dart';
import 'spacing.dart';

/// The single source of truth for Synapse's brand semantics, attached to
/// [ThemeData] as a [ThemeExtension] (prompt 03 §1). Widgets read
/// `context.tokens` instead of hard-coding colours or magic numbers.
@immutable
class SynapseTokens extends ThemeExtension<SynapseTokens> {
  const SynapseTokens({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceHigh,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.primary,
    required this.onPrimary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.brightness,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceHigh;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color textFaint;
  final Color primary;
  final Color onPrimary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  // Token sub-scales (identical across themes; no lerp needed).
  AppSpacing get space => appSpacing;
  AppRadii get radii => appRadii;
  AppMotion get motion => appMotion;

  /// The signature accent for a module (prompt 03 §1). The hue lives in
  /// [ModuleKey]; the UI nudges it for contrast on light backgrounds.
  Color accentOf(ModuleKey m) {
    final base = Color(m.accentHex);
    if (isDark) return base;
    return Color.alphaBlend(Colors.black.withValues(alpha: 0.18), base);
  }

  /// A soft tinted container for an accent (chips, icon backdrops).
  Color accentContainer(Color accent) =>
      accent.withValues(alpha: isDark ? 0.16 : 0.14);

  /// Tinted shadow for actionable/primary surfaces (style §5).
  List<BoxShadow> glow(Color color, {double opacity = 0.28, double blur = 22}) =>
      [BoxShadow(color: color.withValues(alpha: opacity), blurRadius: blur, offset: const Offset(0, 6))];

  /// Standard card elevation. Dark mode prefers a 1px border over a shadow.
  List<BoxShadow> get cardShadow => isDark
      ? const []
      : [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 2))];

  factory SynapseTokens.dark() => SynapseTokens(
        bg: Palette.dark.bg,
        surface: Palette.dark.surface,
        surfaceAlt: Palette.dark.surfaceAlt,
        surfaceHigh: Palette.dark.surfaceHigh,
        border: Palette.dark.border,
        text: Palette.dark.text,
        textMuted: Palette.dark.textMuted,
        textFaint: Palette.dark.textFaint,
        primary: Palette.dark.primary,
        onPrimary: Palette.dark.onPrimary,
        success: Palette.dark.success,
        warning: Palette.dark.warning,
        danger: Palette.dark.danger,
        info: Palette.dark.info,
        brightness: Brightness.dark,
      );

  factory SynapseTokens.light() => SynapseTokens(
        bg: Palette.light.bg,
        surface: Palette.light.surface,
        surfaceAlt: Palette.light.surfaceAlt,
        surfaceHigh: Palette.light.surfaceHigh,
        border: Palette.light.border,
        text: Palette.light.text,
        textMuted: Palette.light.textMuted,
        textFaint: Palette.light.textFaint,
        primary: Palette.light.primary,
        onPrimary: Palette.light.onPrimary,
        success: Palette.light.success,
        warning: Palette.light.warning,
        danger: Palette.light.danger,
        info: Palette.light.info,
        brightness: Brightness.light,
      );

  @override
  SynapseTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceHigh,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? textFaint,
    Color? primary,
    Color? onPrimary,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Brightness? brightness,
  }) {
    return SynapseTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      border: border ?? this.border,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      brightness: brightness ?? this.brightness,
    );
  }

  @override
  SynapseTokens lerp(ThemeExtension<SynapseTokens>? other, double t) {
    if (other is! SynapseTokens) return this;
    return SynapseTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      brightness: t < 0.5 ? brightness : other.brightness,
    );
  }
}

/// Ergonomic access: `context.tokens`.
extension SynapseTokensX on BuildContext {
  SynapseTokens get tokens =>
      Theme.of(this).extension<SynapseTokens>() ?? SynapseTokens.dark();
}
