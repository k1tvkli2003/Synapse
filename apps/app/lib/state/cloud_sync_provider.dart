import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, User;
import 'package:synapse_core/synapse_core.dart';

import '../cloud/cloud_auth_service.dart';
import '../cloud/cloud_sync_service.dart';
import 'app_providers.dart';
import 'game_provider.dart';
import 'user_provider.dart';

enum CloudSyncPhase { offline, signedOut, codeSent, syncing, signedIn, error }

class CloudSyncState extends Equatable {
  const CloudSyncState({
    this.phase = CloudSyncPhase.offline,
    this.email,
    this.message,
  });

  final CloudSyncPhase phase;
  final String? email;
  final String? message;

  CloudSyncState copyWith({
    CloudSyncPhase? phase,
    String? email,
    String? message,
  }) {
    return CloudSyncState(
      phase: phase ?? this.phase,
      email: email ?? this.email,
      message: message,
    );
  }

  @override
  List<Object?> get props => [phase, email, message];
}

final cloudAuthServiceProvider = Provider<CloudAuthService>(
  (ref) => const CloudAuthService(),
);
final cloudSyncServiceProvider = Provider<CloudSyncService>(
  (ref) => const CloudSyncService(),
);

/// Optional cross-device account sync layered on top of the offline-first
/// local store (prompt 05/23/42). A no-op whenever no backend is configured —
/// every read/mutation still goes through [gameProvider]/[userProvider] first;
/// this controller only mirrors that local state to Supabase in the
/// background and pulls it back down on sign-in.
class CloudSyncController extends Notifier<CloudSyncState> {
  StreamSubscription<AuthState>? _authSub;
  Timer? _profileDebounce;
  Timer? _gameDebounce;

  @override
  CloudSyncState build() {
    final config = ref.watch(appConfigProvider);
    if (!config.hasLegacySupabaseBackend) return const CloudSyncState();

    ref.onDispose(() {
      _authSub?.cancel();
      _profileDebounce?.cancel();
      _gameDebounce?.cancel();
    });

    _authSub = ref.read(cloudAuthServiceProvider).onAuthStateChange.listen((
      event,
    ) {
      final user = event.session?.user;
      if (user != null) {
        unawaited(_hydrate(user));
      } else if (state.phase == CloudSyncPhase.signedIn) {
        state = const CloudSyncState(phase: CloudSyncPhase.signedOut);
      }
    });

    ref.listen<GameState>(gameProvider, (prev, next) {
      if (state.phase != CloudSyncPhase.signedIn) return;
      _gameDebounce?.cancel();
      _gameDebounce = Timer(const Duration(seconds: 2), () {
        final uid = ref.read(cloudAuthServiceProvider).currentUser?.id;
        if (uid == null) return;
        ref
            .read(cloudSyncServiceProvider)
            .pushGameState(next.game, uid)
            .catchError((_) {});
      });
    });

    ref.listen<UserProfile>(userProvider, (prev, next) {
      if (state.phase != CloudSyncPhase.signedIn) return;
      _profileDebounce?.cancel();
      _profileDebounce = Timer(const Duration(seconds: 2), () {
        final uid = ref.read(cloudAuthServiceProvider).currentUser?.id;
        if (uid == null) return;
        ref
            .read(cloudSyncServiceProvider)
            .pushProfile(next, uid)
            .catchError((_) {});
      });
    });

    final existing = ref.read(cloudAuthServiceProvider).currentUser;
    if (existing != null) {
      Future.microtask(() => _hydrate(existing));
      return const CloudSyncState(phase: CloudSyncPhase.syncing);
    }
    return const CloudSyncState(phase: CloudSyncPhase.signedOut);
  }

  Future<void> sendCode(String email) async {
    state = CloudSyncState(phase: CloudSyncPhase.codeSent, email: email);
    try {
      await ref.read(cloudAuthServiceProvider).sendCode(email);
    } catch (e) {
      state = CloudSyncState(
        phase: CloudSyncPhase.error,
        email: email,
        message: _readable(e),
      );
    }
  }

  Future<void> confirmCode(String email, String code) async {
    state = CloudSyncState(phase: CloudSyncPhase.syncing, email: email);
    try {
      await ref.read(cloudAuthServiceProvider).verifyCode(email, code);
      // The auth-state listener picks up the new session and calls _hydrate.
    } catch (e) {
      state = CloudSyncState(
        phase: CloudSyncPhase.error,
        email: email,
        message: _readable(e),
      );
    }
  }

  Future<void> signOut() async {
    await ref.read(cloudAuthServiceProvider).signOut();
    state = const CloudSyncState(phase: CloudSyncPhase.signedOut);
  }

  Future<void> syncNow() async {
    final user = ref.read(cloudAuthServiceProvider).currentUser;
    if (user != null) await _hydrate(user);
  }

  Future<void> _hydrate(User user) async {
    state = CloudSyncState(phase: CloudSyncPhase.syncing, email: user.email);
    try {
      final svc = ref.read(cloudSyncServiceProvider);
      final remoteGame = await svc.fetchGameState(user.id);
      final remoteProfile = await svc.fetchProfile(user.id);

      final localGame = ref.read(gameProvider).game;
      final localHasProgress =
          localGame.xp.total > 0 ||
          localGame.wallet.gems > 0 ||
          localGame.streak.current > 0;

      if (remoteGameStateIsUntouched(remoteGame) && localHasProgress) {
        // First-ever sync for this account and this device already has real
        // progress: seed the cloud rather than overwrite it with the
        // trigger-created blank row.
        await svc.pushProfile(ref.read(userProvider), user.id);
        await svc.pushGameState(localGame, user.id);
      } else {
        if (remoteProfile != null) {
          ref.read(userProvider.notifier).update(profileFromRow(remoteProfile));
        }
        if (remoteGame != null) {
          ref
              .read(gameProvider.notifier)
              .hydrateFromCloud(gameStateFromRow(remoteGame));
        }
      }
      state = CloudSyncState(phase: CloudSyncPhase.signedIn, email: user.email);
    } catch (e) {
      state = CloudSyncState(
        phase: CloudSyncPhase.error,
        email: user.email,
        message: _readable(e),
      );
    }
  }

  String _readable(Object e) {
    final s = e.toString();
    return s.length > 160 ? '${s.substring(0, 160)}…' : s;
  }
}

final cloudSyncControllerProvider =
    NotifierProvider<CloudSyncController, CloudSyncState>(
      CloudSyncController.new,
    );
