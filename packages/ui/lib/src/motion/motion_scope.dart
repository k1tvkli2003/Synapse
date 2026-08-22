import 'package:flutter/widgets.dart';
import 'package:synapse_motion/synapse_motion.dart';

class SynapseMotionScope extends StatelessWidget {
  const SynapseMotionScope({
    super.key,
    required this.child,
    this.preference = MotionPreference.full,
    this.surface = MotionSurface.study,
    this.lowPower = false,
    this.advancedRendererAvailable = true,
  });

  final Widget child;
  final MotionPreference preference;
  final MotionSurface surface;
  final bool lowPower;
  final bool advancedRendererAvailable;

  static MotionEnvironment of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_MotionEnvironmentScope>()
          ?.environment ??
      MotionEnvironment(
        systemReducedMotion:
            MediaQuery.maybeOf(context)?.disableAnimations ?? false,
      );

  @override
  Widget build(BuildContext context) {
    final systemReduced =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return _MotionEnvironmentScope(
      environment: MotionEnvironment(
        preference: preference,
        surface: surface,
        systemReducedMotion: systemReduced,
        lowPower: lowPower,
        advancedRendererAvailable: advancedRendererAvailable,
      ),
      child: child,
    );
  }
}

class _MotionEnvironmentScope extends InheritedWidget {
  const _MotionEnvironmentScope({
    required this.environment,
    required super.child,
  });

  final MotionEnvironment environment;

  @override
  bool updateShouldNotify(_MotionEnvironmentScope oldWidget) =>
      oldWidget.environment.preference != environment.preference ||
      oldWidget.environment.surface != environment.surface ||
      oldWidget.environment.systemReducedMotion !=
          environment.systemReducedMotion ||
      oldWidget.environment.lowPower != environment.lowPower ||
      oldWidget.environment.advancedRendererAvailable !=
          environment.advancedRendererAvailable;
}

extension SynapseMotionContext on BuildContext {
  MotionEnvironment get motionEnvironment => SynapseMotionScope.of(this);

  MotionDecision motionDecision(MotionTier tier, {bool celebratory = false}) =>
      MotionPolicy.resolve(
        environment: motionEnvironment,
        tier: tier,
        celebratory: celebratory,
      );
}
