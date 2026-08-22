import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synapse_motion/synapse_motion.dart';
import 'package:synapse_ui/synapse_ui.dart';

void main() {
  testWidgets('system reduced motion overrides a full scope', (tester) async {
    MotionDecision? decision;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SynapseMotionScope(
            child: Builder(
              builder: (context) {
                decision = context.motionDecision(
                  MotionTier.showpiece,
                  celebratory: true,
                );
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    expect(decision?.disposition, MotionDisposition.reduced);
    expect(decision?.maxParticles, 0);
  });

  testWidgets(
    'quiet clinical omits celebratory reveal but not its receipt state',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SynapseMotionScope(
            surface: MotionSurface.clinical,
            child: MotionReveal(
              celebratory: true,
              child: Text('reward theater'),
            ),
          ),
        ),
      );

      expect(find.text('reward theater'), findsNothing);
    },
  );

  testWidgets('off mode renders final child immediately', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SynapseMotionScope(
          preference: MotionPreference.off,
          child: MotionReveal(child: Text('final semantic state')),
        ),
      ),
    );

    expect(find.text('final semantic state'), findsOneWidget);
    final opacity = tester.widget<Opacity>(
      find.ancestor(
        of: find.text('final semantic state'),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, 1);
  });

  testWidgets('full signal burst paints and off mode stays static', (
    tester,
  ) async {
    Widget specimen(MotionPreference preference) => MaterialApp(
      home: SynapseMotionScope(
        preference: preference,
        child: const SizedBox(
          width: 300,
          height: 300,
          child: SignalBurstOverlay(receiptId: 'receipt-fixture', play: true),
        ),
      ),
    );

    await tester.pumpWidget(specimen(MotionPreference.full));
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      find.byKey(const ValueKey('synapse-signal-burst-canvas')),
      findsOneWidget,
    );

    await tester.pumpWidget(specimen(MotionPreference.off));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('synapse-signal-burst-canvas')),
      findsNothing,
    );
  });

  testWidgets('a deferred receipt can animate after returning to Study', (
    tester,
  ) async {
    final surface = ValueNotifier(MotionSurface.clinical);
    addTearDown(surface.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<MotionSurface>(
          valueListenable: surface,
          builder: (context, value, _) => SynapseMotionScope(
            surface: value,
            child: const SizedBox(
              width: 300,
              height: 300,
              child: SignalBurstOverlay(
                receiptId: 'deferred-receipt',
                play: true,
              ),
            ),
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('synapse-signal-burst-canvas')),
      findsNothing,
    );

    surface.value = MotionSurface.study;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(
      find.byKey(const ValueKey('synapse-signal-burst-canvas')),
      findsOneWidget,
    );
  });
}
