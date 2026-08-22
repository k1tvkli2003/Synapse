import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse_app/app.dart';
import 'package:synapse_app/brand/synapse_identity.dart';
import 'package:synapse_app/state/app_providers.dart';
import 'package:synapse_app/state/persistence.dart';

void main() {
  testWidgets('Synapse boots to the splash screen without errors', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = PersistedStore(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(store)],
        child: const SynapseApp(),
      ),
    );

    // Splash renders the brand mark.
    expect(find.byType(SynapseAppIcon), findsOneWidget);
    expect(find.byType(SynapseWordmark), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Advance past the splash delay → onboarding (fresh install).
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Who are you?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Onboarding remains overflow-free on a narrow short phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = PersistedStore(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(store)],
        child: const SynapseApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Who are you?'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('What do you want to focus on?'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Copilot'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Set your daily goal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
