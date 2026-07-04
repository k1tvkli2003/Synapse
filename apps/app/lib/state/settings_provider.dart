import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_core/synapse_core.dart';

import 'app_providers.dart';

/// Persisted user preferences (theme, locale, motion, daily goal, onboarding).
class SettingsNotifier extends Notifier<UserPrefs> {
  static const _key = 'settings';

  @override
  UserPrefs build() {
    final store = ref.watch(sharedPreferencesProvider);
    final json = store.readJson(_key);
    return json != null ? UserPrefs.fromJson(json) : const UserPrefs();
  }

  void _persist(UserPrefs prefs) {
    state = prefs;
    ref.read(sharedPreferencesProvider).writeJson(_key, prefs.toJson());
  }

  void setTheme(ThemeModePref theme) => _persist(state.copyWith(theme: theme));
  void setReduceMotion(bool v) => _persist(state.copyWith(reduceMotion: v));
  void setDailyGoal(int xp) => _persist(state.copyWith(dailyGoalXp: xp));
  void setAnalyticsOptIn(bool v) => _persist(state.copyWith(analyticsOptIn: v));
  void setInterests(List<String> interests) => _persist(state.copyWith(interests: interests));
  void setNotifications(NotificationPrefs n) => _persist(state.copyWith(notifications: n));

  bool get onboarded => ref.read(sharedPreferencesProvider).readBool('onboarded') ?? false;
  void completeOnboarding() => ref.read(sharedPreferencesProvider).writeBool('onboarded', true);
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, UserPrefs>(SettingsNotifier.new);

/// Resolved [ThemeMode] from the persisted preference (prompt 08 §2).
final themeModeProvider = Provider<ThemeMode>((ref) {
  final pref = ref.watch(settingsProvider).theme;
  return switch (pref) {
    ThemeModePref.dark => ThemeMode.dark,
    ThemeModePref.light => ThemeMode.light,
    ThemeModePref.system => ThemeMode.system,
  };
});
