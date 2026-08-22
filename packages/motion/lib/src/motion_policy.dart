import 'presentation_receipt.dart';

enum MotionDisposition { animated, reduced, still, deferred }

final class MotionEnvironment {
  const MotionEnvironment({
    this.preference = MotionPreference.full,
    this.surface = MotionSurface.study,
    this.systemReducedMotion = false,
    this.lowPower = false,
    this.advancedRendererAvailable = true,
  });

  final MotionPreference preference;
  final MotionSurface surface;
  final bool systemReducedMotion;
  final bool lowPower;
  final bool advancedRendererAvailable;
}

final class MotionDecision {
  const MotionDecision({
    required this.disposition,
    required this.durationScale,
    required this.maxParticles,
    required this.allowAmbient,
    required this.allowCharacter,
    required this.allowShader,
    required this.allowSound,
  });

  final MotionDisposition disposition;
  final double durationScale;
  final int maxParticles;
  final bool allowAmbient;
  final bool allowCharacter;
  final bool allowShader;
  final bool allowSound;

  bool get presentsImmediately => disposition != MotionDisposition.deferred;
}

abstract final class MotionPolicy {
  static MotionDecision resolve({
    required MotionEnvironment environment,
    required MotionTier tier,
    required bool celebratory,
  }) {
    if (celebratory && environment.surface != MotionSurface.study) {
      return const MotionDecision(
        disposition: MotionDisposition.deferred,
        durationScale: 0,
        maxParticles: 0,
        allowAmbient: false,
        allowCharacter: false,
        allowShader: false,
        allowSound: false,
      );
    }

    if (environment.preference == MotionPreference.off) {
      return MotionDecision(
        disposition: MotionDisposition.still,
        durationScale: 0,
        maxParticles: 0,
        allowAmbient: false,
        allowCharacter: false,
        allowShader: false,
        allowSound: environment.surface == MotionSurface.study,
      );
    }

    final mustReduce =
        environment.preference == MotionPreference.reduced ||
        environment.systemReducedMotion ||
        environment.lowPower ||
        (!environment.advancedRendererAvailable &&
            tier == MotionTier.showpiece);
    if (mustReduce) {
      return MotionDecision(
        disposition: MotionDisposition.reduced,
        durationScale: 0.35,
        maxParticles: 0,
        allowAmbient: false,
        allowCharacter: tier == MotionTier.functional,
        allowShader: false,
        allowSound: environment.surface == MotionSurface.study,
      );
    }

    return MotionDecision(
      disposition: MotionDisposition.animated,
      durationScale: 1,
      maxParticles: _particleBudget(tier),
      allowAmbient: tier == MotionTier.micro || tier == MotionTier.standard,
      allowCharacter: environment.surface == MotionSurface.study,
      allowShader:
          tier == MotionTier.showpiece && environment.advancedRendererAvailable,
      allowSound: environment.surface == MotionSurface.study,
    );
  }

  static PresentationStatus terminalStatusFor(MotionDecision decision) =>
      switch (decision.disposition) {
        MotionDisposition.animated => PresentationStatus.played,
        MotionDisposition.reduced => PresentationStatus.reduced,
        MotionDisposition.still => PresentationStatus.skipped,
        MotionDisposition.deferred => PresentationStatus.suppressed,
      };

  static int _particleBudget(MotionTier tier) => switch (tier) {
    MotionTier.micro => 32,
    MotionTier.standard => 80,
    MotionTier.milestone => 180,
    MotionTier.showpiece => 300,
    MotionTier.functional => 0,
  };
}
