import 'package:flutter/material.dart';

/// Raw semantic colours for both themes (style §1). True-dark: near-black
/// hue-tinted background, lifted surfaces, soft off-white text, pastel accents.
/// Never pure #000000 / #FFFFFF for text or app background.
class Palette {
  const Palette._();

  // ---- Brand ----
  static const Color brand = Color(0xFF8E9BFF); // periwinkle "neural" violet

  // ---- Dark (default) ----
  static const dark = _Scheme(
    bg: Color(0xFF050816),
    surface: Color(0xFF0C1026),
    surfaceAlt: Color(0xFF141A33),
    surfaceHigh: Color(0xFF1C2444),
    border: Color(0x14FFFFFF), // rgba(255,255,255,0.08)
    text: Color(0xFFEDEFFA),
    textMuted: Color(0xFF98A0C4),
    textFaint: Color(0xFF5C6488),
    primary: Color(0xFF8E9BFF),
    onPrimary: Color(0xFF080B1C),
    success: Color(0xFF5FD9A4),
    warning: Color(0xFFFFC773),
    danger: Color(0xFFFF7A8A),
    info: Color(0xFF6FD3E8),
  );

  // ---- Light ----
  static const light = _Scheme(
    bg: Color(0xFFF5F6FC),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEFF1FA),
    surfaceHigh: Color(0xFFE6EAF6),
    border: Color(0xFFE1E5F2),
    text: Color(0xFF1A1D2E),
    textMuted: Color(0xFF5A6178),
    textFaint: Color(0xFF98A0B8),
    primary: Color(0xFF5B6CF0),
    onPrimary: Color(0xFFFFFFFF),
    success: Color(0xFF1F9E72),
    warning: Color(0xFFD98A1E),
    danger: Color(0xFFE0556A),
    info: Color(0xFF2592B0),
  );
}

class _Scheme {
  const _Scheme({
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
}
