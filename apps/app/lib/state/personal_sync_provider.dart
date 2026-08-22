import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';

import '../data/learner_data/secure_learner_data_key_provider.dart';
import '../data/personal_sync/personal_device_identity.dart';
import '../data/personal_sync/personal_device_sync_service.dart';
import '../data/personal_sync/personal_content_dispatcher.dart';
import '../data/personal_sync/personal_sync_dispatcher.dart';
import '../data/personal_sync/personal_workspace_key_store.dart';
import '../data/personal_sync/recovery_kit.dart';
import 'app_providers.dart';
import 'curriculum_provider.dart';

enum PersonalSyncPhase {
  unavailable,
  loading,
  unpaired,
  recoveryKitPending,
  paired,
  candidateWaitingForApproval,
  working,
  error,
}

final class PersonalSyncState {
  const PersonalSyncState({
    required this.phase,
    this.runtime,
    this.invitation,
    this.pendingRecoveryKit,
    this.errorCode,
  });

  const PersonalSyncState.unavailable()
    : this(phase: PersonalSyncPhase.unavailable);

  const PersonalSyncState.loading() : this(phase: PersonalSyncPhase.loading);

  final PersonalSyncPhase phase;
  final PersonalSyncRuntime? runtime;
  final PersonalPairingInvitation? invitation;
  final String? pendingRecoveryKit;
  final String? errorCode;

  bool get isPaired => runtime != null;
  bool get needsRecoveryKitExport =>
      phase == PersonalSyncPhase.recoveryKitPending &&
      pendingRecoveryKit != null;
}

final personalSyncSecureStoreProvider = Provider<SecureStringStore>(
  (ref) => const FlutterSecureStringStore(),
);

final personalSyncPlatformProvider = Provider<PersonalDevicePlatform?>((ref) {
  if (kIsWeb) return PersonalDevicePlatform.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows => PersonalDevicePlatform.windows,
    TargetPlatform.android => PersonalDevicePlatform.android,
    _ => null,
  };
});

final personalSyncGatewayProvider = Provider<PersonalSyncGateway?>((ref) {
  final raw = ref.watch(appConfigProvider).personalSyncGatewayUrl;
  if (raw.isEmpty) return null;
  return HttpPersonalSyncGateway(baseUri: Uri.parse(raw));
});

final personalWorkspaceKeyStoreProvider =
    Provider<SecureWorkspaceSyncKeyProvider>((ref) {
      return SecureWorkspaceSyncKeyProvider(
        secureStore: ref.watch(personalSyncSecureStoreProvider),
      );
    });

final personalSyncRuntimeStoreProvider = Provider<PersonalSyncRuntimeStore>((
  ref,
) {
  return PersonalSyncRuntimeStore(
    secureStore: ref.watch(personalSyncSecureStoreProvider),
  );
});

final personalDeviceIdentityStoreProvider =
    Provider<PersonalDeviceIdentityStore?>((ref) {
      final platform = ref.watch(personalSyncPlatformProvider);
      if (platform == null) return null;
      return PersonalDeviceIdentityStore(
        secureStore: ref.watch(personalSyncSecureStoreProvider),
        platform: platform,
      );
    });

final personalDeviceSyncServiceProvider = Provider<PersonalDeviceSyncService?>((
  ref,
) {
  final gateway = ref.watch(personalSyncGatewayProvider);
  final platform = ref.watch(personalSyncPlatformProvider);
  final identities = ref.watch(personalDeviceIdentityStoreProvider);
  if (gateway == null || platform == null || identities == null) return null;
  return PersonalDeviceSyncService(
    gateway: gateway,
    identities: identities,
    workspaceKeys: ref.watch(personalWorkspaceKeyStoreProvider),
    runtimeStore: ref.watch(personalSyncRuntimeStoreProvider),
    platform: platform,
  );
});

/// Local encrypted queue for personal multi-device events. It shares the
/// existing learner Data Plane but has its own namespaces, so a sync failure
/// can never block or overwrite an active lesson checkpoint.
final personalSyncOutboxProvider = Provider<PersonalSyncOutboxRepository>((
  ref,
) {
  return PersonalSyncOutboxRepository(
    records: ref.watch(indexedLearnerRecordStoreProvider),
    clock: ref.watch(clockProvider),
  );
});

final personalSyncEnvelopeCipherProvider = Provider<PersonalSyncEnvelopeCipher>(
  (ref) {
    return PersonalSyncEnvelopeCipher(
      keys: ref.watch(personalWorkspaceKeyStoreProvider),
    );
  },
);

/// Materializes encrypted remote events in the local Data Plane before the
/// Academy obtains a compact release-bound resume checkpoint from them.
final personalSyncProjectionStoreProvider =
    Provider<PersonalSyncProjectionStore>(
      (ref) => PersonalSyncProjectionStore(
        records: ref.watch(indexedLearnerRecordStoreProvider),
      ),
    );

final personalSyncCurriculumReconcilerProvider =
    Provider<PersonalSyncCurriculumReconciler>((ref) {
      return PersonalSyncCurriculumReconciler(
        projections: ref.watch(personalSyncProjectionStoreProvider),
        records: ref.watch(indexedLearnerRecordStoreProvider),
        progress: ref.watch(curriculumSessionProgressRepositoryProvider),
        onReconciled: (checkpoint) {
          // Do not wait for a network operation in the UI. These invalidations
          // only refresh local read models after a durable encrypted merge.
          ref.invalidate(curriculumSessionProgressProvider(checkpoint.key));
          ref.invalidate(
            curriculumSessionProgressSnapshotProvider(checkpoint.key),
          );
        },
      );
    });

final personalSyncCoordinatorProvider = Provider<PersonalSyncCoordinator?>((
  ref,
) {
  final gateway = ref.watch(personalSyncGatewayProvider);
  if (gateway == null) return null;
  return PersonalSyncCoordinator(
    gateway: gateway,
    outbox: ref.watch(personalSyncOutboxProvider),
    cipher: ref.watch(personalSyncEnvelopeCipherProvider),
    projections: ref.watch(personalSyncCurriculumReconcilerProvider),
  );
});

final personalSyncDispatchStateProvider =
    StateProvider<PersonalSyncDispatchState>(
      (ref) => const PersonalSyncDispatchState.idle(),
    );

/// Foreground-compatible background drain. It coalesces Academy writes and
/// re-runs when the app's connectivity state returns; suspended/terminated
/// apps simply retain the encrypted outbox for the next foreground.
final personalSyncDispatcherProvider = Provider<PersonalSyncDispatcher?>((ref) {
  final service = ref.watch(personalDeviceSyncServiceProvider);
  final coordinator = ref.watch(personalSyncCoordinatorProvider);
  if (service == null || coordinator == null) return null;
  final dispatcher = PersonalSyncDispatcher(
    readRuntime: service.restoreRuntime,
    ensureAccessToken: service.ensureAccessToken,
    markSuccessfulSync: service.markSuccessfulSync,
    coordinator: coordinator,
    isOnline: () => ref.read(networkOnlineProvider),
    onState: (state) {
      ref.read(personalSyncDispatchStateProvider.notifier).state = state;
      // Content delivery is independent from learner-event reconciliation. It
      // begins after a successful foreground sync but never delays it or turns
      // a signed-package failure into a lost local checkpoint.
      if (state.phase == PersonalSyncDispatchPhase.idle &&
          state.lastResult != null) {
        final content = ref.read(personalContentDispatcherProvider);
        if (content != null) unawaited(content.requestRefresh());
      }
    },
  );
  ref.listen<bool>(networkOnlineProvider, (previous, online) {
    if (online && previous != true) unawaited(dispatcher.requestSync());
  });
  Future<void>.microtask(() {
    // Startup/relaunch is a recovery trigger for queued offline work. The
    // dispatcher itself exits before network I/O when no paired workspace or
    // exported Recovery Kit exists.
    unawaited(dispatcher.requestSync());
  });
  ref.onDispose(dispatcher.dispose);
  return dispatcher;
});

/// The immutable package transport is enabled only when a public, pinned
/// internal-channel keyring is configured. An absent keyring is a deliberate
/// fail-closed local-only mode, not an error and never a reason to delay study.
final personalContentDeliveryCoordinatorProvider =
    Provider<PersonalContentDeliveryCoordinator?>((ref) {
      final gateway = ref.watch(personalSyncGatewayProvider);
      final trust = ref.watch(personalContentTrustVerifierProvider);
      if (gateway == null || trust == null) return null;
      return PersonalContentDeliveryCoordinator(
        gateway: gateway,
        packages: ref.watch(curriculumPackageRepositoryProvider),
        channelState: PersonalContentChannelStateRepository(
          store: ref.watch(personalContentChannelStoreProvider),
          clock: ref.watch(clockProvider),
        ),
      );
    });

final personalContentDispatchStateProvider =
    StateProvider<PersonalContentDispatchState>(
      (ref) => const PersonalContentDispatchState.idle(),
    );

/// Foreground-compatible chapter-package refresh. It keeps an already-active
/// local release visible throughout download, verification, quarantine, and
/// activation; no lesson route waits for this provider.
final personalContentDispatcherProvider = Provider<PersonalContentDispatcher?>((
  ref,
) {
  final service = ref.watch(personalDeviceSyncServiceProvider);
  final coordinator = ref.watch(personalContentDeliveryCoordinatorProvider);
  if (service == null || coordinator == null) return null;
  final dispatcher = PersonalContentDispatcher(
    readRuntime: service.restoreRuntime,
    ensureAccessToken: service.ensureAccessToken,
    coordinator: coordinator,
    isOnline: () => ref.read(networkOnlineProvider),
    onState: (state) {
      ref.read(personalContentDispatchStateProvider.notifier).state = state;
    },
    onActivated: (_) {
      // Local registry activation completed first. This merely causes read
      // models to rebuild from local Drift/registry state on the next frame.
      ref.invalidate(curriculumRuntimeProvider);
    },
  );
  ref.listen<bool>(networkOnlineProvider, (previous, online) {
    if (online && previous != true) unawaited(dispatcher.requestRefresh());
  });
  Future<void>.microtask(() {
    unawaited(dispatcher.requestRefresh());
  });
  ref.onDispose(dispatcher.dispose);
  return dispatcher;
});

/// Academy writes only structured, privacy-safe receipts here after a local
/// checkpoint is already durable. The journal performs no network I/O.
final personalSyncCurriculumJournalProvider =
    Provider<PersonalSyncCurriculumJournal>((ref) {
      return PersonalSyncCurriculumJournal.lazy(
        currentContext: () async {
          final service = ref.read(personalDeviceSyncServiceProvider);
          final runtime = service == null
              ? null
              : await service.restoreRuntime();
          if (runtime == null || !runtime.recoveryKitExported) return null;
          return PersonalSyncDeviceContext(
            workspace: runtime.workspace,
            device: runtime.device,
          );
        },
        cipher: ref.watch(personalSyncEnvelopeCipherProvider),
        outbox: () async => ref.read(personalSyncOutboxProvider),
      );
    });

/// Device-only personal sync controller. It is intentionally independent from
/// legacy email/Supabase sync, which remains preserved but inactive whenever a
/// private gateway is configured.
final personalSyncControllerProvider =
    NotifierProvider<PersonalSyncController, PersonalSyncState>(
      PersonalSyncController.new,
    );

final class PersonalSyncController extends Notifier<PersonalSyncState> {
  @override
  PersonalSyncState build() {
    final service = ref.watch(personalDeviceSyncServiceProvider);
    if (service == null) return const PersonalSyncState.unavailable();
    Future.microtask(_restore);
    return const PersonalSyncState.loading();
  }

  Future<void> retry() => _restore();

  Future<void> bootstrapWindowsRoot({
    required String deviceLabel,
    required String bootstrapToken,
    required String recoveryPassphrase,
  }) async {
    final service = _serviceOrError();
    state = const PersonalSyncState(phase: PersonalSyncPhase.working);
    try {
      final draft = await RecoveryKitCodec().prepare(
        passphrase: recoveryPassphrase,
      );
      final bootstrap = await service.bootstrapWindowsRoot(
        deviceLabel: deviceLabel,
        bootstrapToken: bootstrapToken,
        recoveryDraft: draft,
      );
      state = PersonalSyncState(
        phase: PersonalSyncPhase.recoveryKitPending,
        runtime: bootstrap.runtime,
        pendingRecoveryKit: bootstrap.recoveryKit.serialize(),
      );
    } on Object catch (error) {
      state = PersonalSyncState(
        phase: PersonalSyncPhase.error,
        errorCode: _errorCode(error),
      );
    }
  }

  Future<void> markRecoveryKitExported() async {
    final service = _serviceOrError();
    state = const PersonalSyncState(phase: PersonalSyncPhase.working);
    try {
      await service.markRecoveryKitExported();
      await _restore();
    } on Object catch (error) {
      state = PersonalSyncState(
        phase: PersonalSyncPhase.error,
        errorCode: _errorCode(error),
      );
    }
  }

  Future<void> beginCandidatePairing({required String deviceLabel}) async {
    final service = _serviceOrError();
    state = const PersonalSyncState(phase: PersonalSyncPhase.working);
    try {
      final invitation = await service.startCandidatePairing(
        deviceLabel: deviceLabel,
      );
      state = PersonalSyncState(
        phase: PersonalSyncPhase.candidateWaitingForApproval,
        invitation: invitation,
      );
    } on Object catch (error) {
      state = PersonalSyncState(
        phase: PersonalSyncPhase.error,
        errorCode: _errorCode(error),
      );
    }
  }

  Future<void> approvePairingPayload(String payload) async {
    final service = _serviceOrError();
    state = const PersonalSyncState(phase: PersonalSyncPhase.working);
    try {
      await service.approvePairingInvitation(
        PersonalPairingInvitation.decode(payload),
      );
      await _restore();
    } on Object catch (error) {
      state = PersonalSyncState(
        phase: PersonalSyncPhase.error,
        errorCode: _errorCode(error),
      );
    }
  }

  Future<void> completeCandidatePairing() async {
    final service = _serviceOrError();
    state = const PersonalSyncState(phase: PersonalSyncPhase.working);
    try {
      await service.completeCandidatePairing();
      await _restore();
    } on Object catch (error) {
      state = PersonalSyncState(
        phase: PersonalSyncPhase.error,
        errorCode: _errorCode(error),
      );
    }
  }

  Future<void> refreshConnection() async {
    final service = _serviceOrError();
    state = const PersonalSyncState(phase: PersonalSyncPhase.working);
    try {
      await service.ensureAccessToken();
      await _restore();
    } on Object catch (error) {
      state = PersonalSyncState(
        phase: PersonalSyncPhase.error,
        errorCode: _errorCode(error),
      );
    }
  }

  /// Manual recovery action for Settings. Academy checkpoints call the same
  /// dispatcher in the background after they are locally durable, so learners
  /// never wait for a sync response while answering an interaction.
  Future<void> syncNow() async {
    final dispatcher = ref.read(personalSyncDispatcherProvider);
    if (dispatcher == null) {
      state = const PersonalSyncState(
        phase: PersonalSyncPhase.error,
        errorCode: 'personal_sync_unavailable',
      );
      return;
    }
    state = const PersonalSyncState(phase: PersonalSyncPhase.working);
    try {
      final receipt = await dispatcher.requestSync();
      if (receipt.kind == PersonalSyncDispatchReceiptKind.failed) {
        state = PersonalSyncState(
          phase: PersonalSyncPhase.error,
          errorCode: receipt.errorCode,
        );
        return;
      }
      await _restore();
    } on Object catch (error) {
      state = PersonalSyncState(
        phase: PersonalSyncPhase.error,
        errorCode: _errorCode(error),
      );
    }
  }

  Future<void> _restore() async {
    final service = ref.read(personalDeviceSyncServiceProvider);
    if (service == null) {
      state = const PersonalSyncState.unavailable();
      return;
    }
    state = const PersonalSyncState(phase: PersonalSyncPhase.loading);
    try {
      final runtime = await service.restoreRuntime();
      final recoveryKit = await service.pendingRecoveryKit();
      if (runtime != null) {
        state = runtime.recoveryKitExported || recoveryKit == null
            ? PersonalSyncState(
                phase: PersonalSyncPhase.paired,
                runtime: runtime,
              )
            : PersonalSyncState(
                phase: PersonalSyncPhase.recoveryKitPending,
                runtime: runtime,
                pendingRecoveryKit: recoveryKit,
              );
        return;
      }
      final pending = await service.pendingPairing();
      if (pending != null && !pending.isExpiredAt(DateTime.now().toUtc())) {
        state = PersonalSyncState(
          phase: PersonalSyncPhase.candidateWaitingForApproval,
          invitation: PersonalPairingInvitation.fromSession(pending.session),
        );
        return;
      }
      state = const PersonalSyncState(phase: PersonalSyncPhase.unpaired);
    } on Object catch (error) {
      state = PersonalSyncState(
        phase: PersonalSyncPhase.error,
        errorCode: _errorCode(error),
      );
    }
  }

  PersonalDeviceSyncService _serviceOrError() {
    final service = ref.read(personalDeviceSyncServiceProvider);
    if (service == null) {
      throw const PersonalDeviceSyncException(
        'personal_sync_unavailable',
        'Personal device sync is not configured for this platform.',
      );
    }
    return service;
  }

  String _errorCode(Object error) => switch (error) {
    PersonalDeviceSyncException(:final code) => code,
    RecoveryKitException(:final code) => code,
    PersonalSyncApiException(:final code) => code,
    _ => 'personal_sync_failed',
  };
}
