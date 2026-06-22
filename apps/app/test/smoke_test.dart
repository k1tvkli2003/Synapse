import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse_app/app.dart';
import 'package:synapse_app/state/app_providers.dart';
import 'package:synapse_app/state/persistence.dart';

void main() {
  testWidgets('Synapse boots to the splash screen without errors', (tester) async {
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
    expect(find.text('Synapse'), findsOneWidget);

    // Advance past the splash delay → onboarding (fresh install).
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
