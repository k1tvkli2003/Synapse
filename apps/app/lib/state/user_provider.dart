import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';

import 'app_providers.dart';

/// The current user profile (prompt 06/08). Local demo identity by default,
/// persisted so edits survive restarts.
class UserNotifier extends Notifier<UserProfile> {
  static const _key = 'profile';

  @override
  UserProfile build() {
    final store = ref.watch(sharedPreferencesProvider);
    final json = store.readJson(_key);
    return json != null ? UserProfile.fromJson(json) : DemoSeed.user;
  }

  void update(UserProfile profile) {
    state = profile;
    ref.read(sharedPreferencesProvider).writeJson(_key, profile.toJson());
  }

  void edit({String? displayName, String? specialty, String? bio, UserRole? role, int? year}) {
    update(state.copyWith(
      displayName: displayName,
      specialty: specialty,
      bio: bio,
      role: role,
      year: year,
      updatedAt: DateTime.now(),
    ));
  }
}

final userProvider = NotifierProvider<UserNotifier, UserProfile>(UserNotifier.new);
