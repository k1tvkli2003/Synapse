import 'package:flutter/material.dart';

/// Canonical runtime assets for the Synapse identity.
///
/// Launcher assets remain platform-owned. These paths are the static,
/// reduced-motion-safe fallbacks used by the Flutter UI and future Rive rig.
abstract final class SynapseIdentityAssets {
  static const _root = 'assets/identity/luma_facefront';

  static const appIcon1024 = '$_root/app_icon_1024.png';
  static const appIcon512 = '$_root/app_icon_512.png';
  static const appIcon256 = '$_root/app_icon_256.png';
  static const appIcon96 = '$_root/app_icon_96.png';
  static const appIcon48 = '$_root/app_icon_48.png';
  static const appIcon24 = '$_root/app_icon_24.png';
  static const appIcon16 = '$_root/app_icon_16.png';
  static const appIconAdaptive = '$_root/app_icon_adaptive_foreground_1024.png';
  static const appIconMonochrome = '$_root/app_icon_monochrome_1024.png';

  static String mascot(SynapseCompanionPose pose, int pixels) {
    final stem = switch (pose) {
      SynapseCompanionPose.heroPointing => 'hero_pointing',
      SynapseCompanionPose.encouraging => 'encouraging',
      SynapseCompanionPose.thinking => 'thinking',
      SynapseCompanionPose.evidenceGuide => 'evidence_guide',
      SynapseCompanionPose.questHost => 'quest_host',
      SynapseCompanionPose.recovery => 'recovery',
    };
    return '$_root/mascot_${stem}_$pixels.png';
  }
}

abstract final class SynapseWordmarkAssets {
  static const _root = 'assets/identity/wordmark';

  static const frostHero = '$_root/wordmark_frost_240.png';
  static const frost = '$_root/wordmark_frost_96.png';
  static const oneColorFrost = '$_root/wordmark_one_color_frost_96.png';
  static const oneColorFrostCompact = '$_root/wordmark_one_color_frost_48.png';
  static const oneColorFrostOptical = '$_root/wordmark_one_color_frost_24.png';
  static const oneColorInk = '$_root/wordmark_one_color_ink_96.png';
  static const oneColorInkCompact = '$_root/wordmark_one_color_ink_48.png';
  static const oneColorInkOptical = '$_root/wordmark_one_color_ink_24.png';
}

enum SynapseCompanionPose {
  heroPointing,
  encouraging,
  thinking,
  evidenceGuide,
  questHost,
  recovery,
}

/// Static, reduced-motion-safe fallback for the restored LUMA companion.
///
/// Pass [semanticLabel] only when the mascot communicates state or guidance.
/// Decorative appearances stay out of the semantics tree by default.
class SynapseCompanion extends StatelessWidget {
  const SynapseCompanion({
    super.key,
    this.pose = SynapseCompanionPose.heroPointing,
    this.size = 96,
    this.semanticLabel,
  });

  final SynapseCompanionPose pose;
  final double size;
  final String? semanticLabel;

  String get _asset {
    final pixels = size <= 320 ? 256 : (size <= 640 ? 512 : 1024);
    return SynapseIdentityAssets.mascot(pose, pixels);
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      _asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      excludeFromSemantics: true,
    );
    final label = semanticLabel;
    if (label == null || label.trim().isEmpty) {
      return ExcludeSemantics(child: image);
    }
    return Semantics(label: label, image: true, child: image);
  }
}

/// Runtime specimen for the restored ICR2-01 LUMA Facefront app icon.
class SynapseAppIcon extends StatelessWidget {
  const SynapseAppIcon({super.key, this.size = 96, this.semanticLabel});

  final double size;
  final String? semanticLabel;

  String get _asset {
    if (size <= 20) return SynapseIdentityAssets.appIcon16;
    if (size <= 30) return SynapseIdentityAssets.appIcon24;
    if (size <= 64) return SynapseIdentityAssets.appIcon48;
    if (size <= 128) return SynapseIdentityAssets.appIcon96;
    if (size <= 384) return SynapseIdentityAssets.appIcon256;
    if (size <= 768) return SynapseIdentityAssets.appIcon512;
    return SynapseIdentityAssets.appIcon1024;
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      _asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      excludeFromSemantics: true,
    );
    final label = semanticLabel;
    if (label == null || label.trim().isEmpty) {
      return ExcludeSemantics(child: image);
    }
    return Semantics(label: label, image: true, child: image);
  }
}

@Deprecated('Use SynapseCompanion or SynapseAppIcon.')
enum LumaFoldkinVariant { material, flat, monochrome }

/// Compatibility wrapper for the historic LUMA API.
///
/// The visual direction is active again, but the generic Synapse widgets
/// remain the app-facing contract so existing surfaces keep working unchanged.
@Deprecated('Use SynapseCompanion or SynapseAppIcon.')
class LumaFoldkin extends StatelessWidget {
  const LumaFoldkin({
    super.key,
    this.variant = LumaFoldkinVariant.material,
    this.size = 96,
    this.semanticLabel,
  });

  final LumaFoldkinVariant variant;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (variant == LumaFoldkinVariant.monochrome) {
      return SynapseAppIcon(size: size, semanticLabel: semanticLabel);
    }
    return SynapseCompanion(size: size, semanticLabel: semanticLabel);
  }
}

enum SynapseWordmarkVariant { material, frost, ink }

/// The selected Warm Living Fold wordmark with optical-size switching.
///
/// Unlike decorative mascot art, the wordmark always contributes the product
/// name to semantics because it replaces visible live text in brand positions.
class SynapseWordmark extends StatelessWidget {
  const SynapseWordmark({
    super.key,
    this.variant = SynapseWordmarkVariant.material,
    this.height = 48,
    this.semanticLabel = 'Synapse',
  });

  final SynapseWordmarkVariant variant;
  final double height;
  final String semanticLabel;

  String get _asset {
    if (variant == SynapseWordmarkVariant.material) {
      if (height > 96) return SynapseWordmarkAssets.frostHero;
      if (height > 48) return SynapseWordmarkAssets.frost;
      if (height <= 28) return SynapseWordmarkAssets.oneColorFrostOptical;
      return SynapseWordmarkAssets.oneColorFrostCompact;
    }
    if (variant == SynapseWordmarkVariant.ink) {
      if (height <= 28) return SynapseWordmarkAssets.oneColorInkOptical;
      if (height <= 56) return SynapseWordmarkAssets.oneColorInkCompact;
      return SynapseWordmarkAssets.oneColorInk;
    }
    if (height <= 28) return SynapseWordmarkAssets.oneColorFrostOptical;
    if (height <= 56) return SynapseWordmarkAssets.oneColorFrostCompact;
    return SynapseWordmarkAssets.oneColorFrost;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      child: Image.asset(
        _asset,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      ),
    );
  }
}
