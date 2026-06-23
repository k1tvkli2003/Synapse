import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Semantic feedback events mapped consistently to haptics + sound app-wide
/// (prompt 53 §2/§3). Driven by the same moments everywhere so wins, errors and
/// selections feel identical across modules.
enum Sensation { success, error, selection, impact, levelUp, sendMessage }

/// Platform haptics, mapped from semantic events (prompt 53 §3). No-ops
/// gracefully on web/desktop where haptics aren't available.
class HapticsService {
  HapticsService._();
  static final HapticsService instance = HapticsService._();

  bool enabled = true;

  bool get _supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

  void fire(Sensation f) {
    if (!enabled || !_supported) return;
    switch (f) {
      case Sensation.success:
      case Sensation.levelUp:
        HapticFeedback.mediumImpact();
      case Sensation.error:
        HapticFeedback.heavyImpact();
      case Sensation.selection:
        HapticFeedback.selectionClick();
      case Sensation.impact:
        HapticFeedback.lightImpact();
      case Sensation.sendMessage:
        HapticFeedback.lightImpact();
    }
  }
}

/// A small, cohesive sound palette (prompt 53 §2). Uses built-in system sounds
/// so the app stays asset-free and fully offline; off by default on desktop and
/// respectful of a global mute so it never fights Sounds/OR Lab/Rounds playback.
class SfxService {
  SfxService._();
  static final SfxService instance = SfxService._();

  /// Off by default on desktop (prompt 53 §2).
  bool enabled = !_isDesktop;

  static bool get _isDesktop =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux);

  void play(Sensation f) {
    if (!enabled) return;
    switch (f) {
      case Sensation.selection:
      case Sensation.sendMessage:
        SystemSound.play(SystemSoundType.click);
      case Sensation.success:
      case Sensation.levelUp:
      case Sensation.impact:
        SystemSound.play(SystemSoundType.click);
      case Sensation.error:
        SystemSound.play(SystemSoundType.alert);
    }
  }
}

/// Fire haptics + sound together for a semantic moment — the one call sites use.
void emitFeedback(Sensation f) {
  HapticsService.instance.fire(f);
  SfxService.instance.play(f);
}
