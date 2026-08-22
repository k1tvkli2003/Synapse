import 'dart:async';

import 'package:synapse_services/synapse_services.dart';

import 'personal_device_sync_service.dart';

enum PersonalSyncDispatchPhase {
  idle,
  offline,
  syncing,
  retryScheduled,
  failed,
}

/// Privacy-safe transport state for a single app process. It deliberately
/// contains no access token, clear event, lesson body, or learner response.
final class PersonalSyncDispatchState {
  const PersonalSyncDispatchState({
    required this.phase,
    this.lastResult,
    this.errorCode,
    this.retryAt,
    this.consecutiveFailures = 0,
  });

  const PersonalSyncDispatchState.idle()
    : this(phase: PersonalSyncDispatchPhase.idle);

  final PersonalSyncDispatchPhase phase;
  final PersonalSyncRunResult? lastResult;
  final String? errorCode;
  final DateTime? retryAt;
  final int consecutiveFailures;
}

/// Outcome of one requested foreground/background-compatible sync drain.
/// The encrypted outbox remains durable even when this receipt is `deferred`
/// or `retryScheduled`.
final class PersonalSyncDispatchReceipt {
  const PersonalSyncDispatchReceipt._({
    required this.kind,
    this.result,
    this.errorCode,
    this.retryAt,
  });

  const PersonalSyncDispatchReceipt.completed(PersonalSyncRunResult result)
    : this._(kind: PersonalSyncDispatchReceiptKind.completed, result: result);

  const PersonalSyncDispatchReceipt.deferred({String? errorCode})
    : this._(
        kind: PersonalSyncDispatchReceiptKind.deferred,
        errorCode: errorCode,
      );

  const PersonalSyncDispatchReceipt.retryScheduled({
    required String errorCode,
    required DateTime retryAt,
  }) : this._(
         kind: PersonalSyncDispatchReceiptKind.retryScheduled,
         errorCode: errorCode,
         retryAt: retryAt,
       );

  const PersonalSyncDispatchReceipt.failed({required String errorCode})
    : this._(
        kind: PersonalSyncDispatchReceiptKind.failed,
        errorCode: errorCode,
      );

  final PersonalSyncDispatchReceiptKind kind;
  final PersonalSyncRunResult? result;
  final String? errorCode;
  final DateTime? retryAt;
}

enum PersonalSyncDispatchReceiptKind {
  completed,
  deferred,
  retryScheduled,
  failed,
}

/// Serializes personal-sync drains, coalesces new local events, and retries
/// safe transient failures with bounded exponential backoff. This is an
/// in-process scheduler: on a suspended Web tab or terminated mobile app the
/// encrypted outbox survives and the next app foreground resumes it.
final class PersonalSyncDispatcher {
  PersonalSyncDispatcher({
    required this.readRuntime,
    required this.ensureAccessToken,
    required this.markSuccessfulSync,
    required this.coordinator,
    required this.isOnline,
    required this.onState,
    DateTime Function()? now,
    this.baseRetryDelay = const Duration(seconds: 2),
    this.maxRetryDelay = const Duration(minutes: 5),
  }) : _now = now ?? DateTime.now {
    if (baseRetryDelay <= Duration.zero || maxRetryDelay < baseRetryDelay) {
      throw ArgumentError('Invalid personal-sync retry policy.');
    }
  }

  final Future<PersonalSyncRuntime?> Function() readRuntime;
  final Future<String> Function() ensureAccessToken;
  final Future<void> Function(DateTime completedAt) markSuccessfulSync;
  final PersonalSyncCoordinator coordinator;
  final bool Function() isOnline;
  final void Function(PersonalSyncDispatchState state) onState;
  final DateTime Function() _now;
  final Duration baseRetryDelay;
  final Duration maxRetryDelay;

  Timer? _retryTimer;
  Future<PersonalSyncDispatchReceipt>? _active;
  var _rerunRequested = false;
  var _consecutiveFailures = 0;
  var _disposed = false;

  /// Coalesces calls while a drain is already running. A new checkpoint that
  /// arrives mid-run causes exactly one follow-up drain after the active one.
  Future<PersonalSyncDispatchReceipt> requestSync() {
    if (_disposed) {
      return Future.value(
        const PersonalSyncDispatchReceipt.deferred(
          errorCode: 'personal_sync_dispatcher_disposed',
        ),
      );
    }
    _retryTimer?.cancel();
    _retryTimer = null;
    _rerunRequested = true;
    final active = _active;
    if (active != null) return active;
    late final Future<PersonalSyncDispatchReceipt> next;
    next = _drain().whenComplete(() {
      if (identical(_active, next)) _active = null;
    });
    _active = next;
    return next;
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  Future<PersonalSyncDispatchReceipt> _drain() async {
    PersonalSyncDispatchReceipt last =
        const PersonalSyncDispatchReceipt.deferred();
    do {
      _rerunRequested = false;
      last = await _runOnce();
    } while (_rerunRequested &&
        last.kind == PersonalSyncDispatchReceiptKind.completed &&
        !_disposed);
    return last;
  }

  Future<PersonalSyncDispatchReceipt> _runOnce() async {
    if (!isOnline()) {
      _emit(
        const PersonalSyncDispatchState(
          phase: PersonalSyncDispatchPhase.offline,
        ),
      );
      return const PersonalSyncDispatchReceipt.deferred(errorCode: 'offline');
    }
    try {
      final runtime = await readRuntime();
      if (runtime == null) {
        _emit(const PersonalSyncDispatchState.idle());
        return const PersonalSyncDispatchReceipt.deferred(
          errorCode: 'personal_workspace_unpaired',
        );
      }
      if (!runtime.recoveryKitExported) {
        _emit(const PersonalSyncDispatchState.idle());
        return const PersonalSyncDispatchReceipt.deferred(
          errorCode: 'recovery_kit_required',
        );
      }
      _emit(
        PersonalSyncDispatchState(
          phase: PersonalSyncDispatchPhase.syncing,
          consecutiveFailures: _consecutiveFailures,
        ),
      );
      final accessToken = await ensureAccessToken();
      final freshRuntime = await readRuntime();
      if (freshRuntime == null || !freshRuntime.recoveryKitExported) {
        throw const PersonalDeviceSyncException(
          'personal_workspace_unpaired',
          'The personal workspace disappeared before synchronization.',
        );
      }
      final result = await coordinator.syncOnce(
        accessToken: accessToken,
        workspaceId: freshRuntime.workspace.id,
      );
      await markSuccessfulSync(_now().toUtc());
      _consecutiveFailures = 0;
      _emit(
        PersonalSyncDispatchState(
          phase: PersonalSyncDispatchPhase.idle,
          lastResult: result,
        ),
      );
      return PersonalSyncDispatchReceipt.completed(result);
    } on Object catch (error) {
      final errorCode = _errorCode(error);
      if (_isRetryable(error)) {
        _consecutiveFailures += 1;
        final delay = _retryDelay(error);
        final retryAt = _now().toUtc().add(delay);
        _emit(
          PersonalSyncDispatchState(
            phase: PersonalSyncDispatchPhase.retryScheduled,
            errorCode: errorCode,
            retryAt: retryAt,
            consecutiveFailures: _consecutiveFailures,
          ),
        );
        _retryTimer = Timer(delay, () {
          _retryTimer = null;
          if (_disposed) return;
          final active = _active;
          if (active != null) {
            // A very short server retry hint can fire before the current
            // Future clears. Chain the retry behind it instead of silently
            // coalescing it into a completed failure receipt.
            unawaited(
              active.whenComplete(() {
                if (!_disposed) unawaited(requestSync());
              }),
            );
            return;
          }
          unawaited(requestSync());
        });
        return PersonalSyncDispatchReceipt.retryScheduled(
          errorCode: errorCode,
          retryAt: retryAt,
        );
      }
      _emit(
        PersonalSyncDispatchState(
          phase: PersonalSyncDispatchPhase.failed,
          errorCode: errorCode,
          consecutiveFailures: _consecutiveFailures,
        ),
      );
      return PersonalSyncDispatchReceipt.failed(errorCode: errorCode);
    }
  }

  Duration _retryDelay(Object error) {
    if (error case PersonalSyncApiException(:final retryAfter?)) {
      return retryAfter > maxRetryDelay ? maxRetryDelay : retryAfter;
    }
    final exponent = (_consecutiveFailures - 1).clamp(0, 8).toInt();
    final milliseconds = baseRetryDelay.inMilliseconds * (1 << exponent);
    final bounded = milliseconds > maxRetryDelay.inMilliseconds
        ? maxRetryDelay.inMilliseconds
        : milliseconds;
    return Duration(milliseconds: bounded);
  }

  bool _isRetryable(Object error) =>
      error is TimeoutException ||
      (error is PersonalSyncApiException && error.isRetryable);

  String _errorCode(Object error) => switch (error) {
    PersonalSyncApiException(:final code) => code,
    PersonalDeviceSyncException(:final code) => code,
    LearnerDataPlaneException(:final code) => code,
    PersonalSyncCryptoException(:final code) => code,
    PersonalSyncCurriculumReconcilerException(:final code) => code,
    TimeoutException() => 'sync_timeout',
    _ => 'personal_sync_failed',
  };

  void _emit(PersonalSyncDispatchState state) {
    if (!_disposed) onState(state);
  }
}
