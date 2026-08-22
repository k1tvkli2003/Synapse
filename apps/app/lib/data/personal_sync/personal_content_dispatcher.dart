import 'dart:async';

import 'package:synapse_services/synapse_services.dart';

import 'personal_device_sync_service.dart';

enum PersonalContentDispatchPhase {
  idle,
  offline,
  refreshing,
  retryScheduled,
  failed,
}

/// Safe operational state for the signed curriculum channel. It carries no
/// package body, access token, lesson content, or learner-authored data.
final class PersonalContentDispatchState {
  const PersonalContentDispatchState({
    required this.phase,
    this.lastResult,
    this.errorCode,
    this.retryAt,
    this.consecutiveFailures = 0,
  });

  const PersonalContentDispatchState.idle()
    : this(phase: PersonalContentDispatchPhase.idle);

  final PersonalContentDispatchPhase phase;
  final PersonalContentDeliveryResult? lastResult;
  final String? errorCode;
  final DateTime? retryAt;
  final int consecutiveFailures;
}

enum PersonalContentDispatchReceiptKind {
  completed,
  deferred,
  retryScheduled,
  failed,
}

final class PersonalContentDispatchReceipt {
  const PersonalContentDispatchReceipt._({
    required this.kind,
    this.result,
    this.errorCode,
    this.retryAt,
  });

  const PersonalContentDispatchReceipt.completed(
    PersonalContentDeliveryResult result,
  ) : this._(
        kind: PersonalContentDispatchReceiptKind.completed,
        result: result,
      );

  const PersonalContentDispatchReceipt.deferred({String? errorCode})
    : this._(
        kind: PersonalContentDispatchReceiptKind.deferred,
        errorCode: errorCode,
      );

  const PersonalContentDispatchReceipt.retryScheduled({
    required String errorCode,
    required DateTime retryAt,
  }) : this._(
         kind: PersonalContentDispatchReceiptKind.retryScheduled,
         errorCode: errorCode,
         retryAt: retryAt,
       );

  const PersonalContentDispatchReceipt.failed({required String errorCode})
    : this._(
        kind: PersonalContentDispatchReceiptKind.failed,
        errorCode: errorCode,
      );

  final PersonalContentDispatchReceiptKind kind;
  final PersonalContentDeliveryResult? result;
  final String? errorCode;
  final DateTime? retryAt;
}

/// Foreground-compatible refresh scheduler for signed chapter packages. It is
/// separate from encrypted learner-event sync so a content signature failure
/// never delays a locally completed Academy session or its progress outbox.
final class PersonalContentDispatcher {
  PersonalContentDispatcher({
    required this.readRuntime,
    required this.ensureAccessToken,
    required this.coordinator,
    required this.isOnline,
    required this.onState,
    required this.onActivated,
    DateTime Function()? now,
    this.baseRetryDelay = const Duration(seconds: 2),
    this.maxRetryDelay = const Duration(minutes: 5),
  }) : _now = now ?? DateTime.now {
    if (baseRetryDelay <= Duration.zero || maxRetryDelay < baseRetryDelay) {
      throw ArgumentError('Invalid personal content retry policy.');
    }
  }

  final Future<PersonalSyncRuntime?> Function() readRuntime;
  final Future<String> Function() ensureAccessToken;
  final PersonalContentDeliveryCoordinator coordinator;
  final bool Function() isOnline;
  final void Function(PersonalContentDispatchState state) onState;
  final void Function(PersonalContentDeliveryResult result) onActivated;
  final DateTime Function() _now;
  final Duration baseRetryDelay;
  final Duration maxRetryDelay;

  Timer? _retryTimer;
  Future<PersonalContentDispatchReceipt>? _active;
  var _rerunRequested = false;
  var _consecutiveFailures = 0;
  var _disposed = false;

  Future<PersonalContentDispatchReceipt> requestRefresh() {
    if (_disposed) {
      return Future.value(
        const PersonalContentDispatchReceipt.deferred(
          errorCode: 'personal_content_dispatcher_disposed',
        ),
      );
    }
    _retryTimer?.cancel();
    _retryTimer = null;
    _rerunRequested = true;
    final active = _active;
    if (active != null) return active;
    late final Future<PersonalContentDispatchReceipt> next;
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

  Future<PersonalContentDispatchReceipt> _drain() async {
    PersonalContentDispatchReceipt last =
        const PersonalContentDispatchReceipt.deferred();
    do {
      _rerunRequested = false;
      last = await _runOnce();
    } while (_rerunRequested &&
        last.kind == PersonalContentDispatchReceiptKind.completed &&
        !_disposed);
    return last;
  }

  Future<PersonalContentDispatchReceipt> _runOnce() async {
    if (!isOnline()) {
      _emit(
        const PersonalContentDispatchState(
          phase: PersonalContentDispatchPhase.offline,
        ),
      );
      return const PersonalContentDispatchReceipt.deferred(
        errorCode: 'offline',
      );
    }
    try {
      final runtime = await readRuntime();
      if (runtime == null) {
        _emit(const PersonalContentDispatchState.idle());
        return const PersonalContentDispatchReceipt.deferred(
          errorCode: 'personal_workspace_unpaired',
        );
      }
      if (!runtime.recoveryKitExported) {
        _emit(const PersonalContentDispatchState.idle());
        return const PersonalContentDispatchReceipt.deferred(
          errorCode: 'recovery_kit_required',
        );
      }
      _emit(
        PersonalContentDispatchState(
          phase: PersonalContentDispatchPhase.refreshing,
          consecutiveFailures: _consecutiveFailures,
        ),
      );
      final accessToken = await ensureAccessToken();
      final freshRuntime = await readRuntime();
      if (freshRuntime == null || !freshRuntime.recoveryKitExported) {
        throw const PersonalDeviceSyncException(
          'personal_workspace_unpaired',
          'The personal workspace disappeared before content refresh.',
        );
      }
      final result = await coordinator.refresh(accessToken: accessToken);
      _consecutiveFailures = 0;
      if (result.kind == PersonalContentDeliveryResultKind.activated) {
        onActivated(result);
      }
      _emit(
        PersonalContentDispatchState(
          phase: PersonalContentDispatchPhase.idle,
          lastResult: result,
        ),
      );
      return PersonalContentDispatchReceipt.completed(result);
    } on Object catch (error) {
      final errorCode = _errorCode(error);
      if (_isRetryable(error)) {
        _consecutiveFailures += 1;
        final delay = _retryDelay(error);
        final retryAt = _now().toUtc().add(delay);
        _emit(
          PersonalContentDispatchState(
            phase: PersonalContentDispatchPhase.retryScheduled,
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
            unawaited(
              active.whenComplete(() {
                if (!_disposed) unawaited(requestRefresh());
              }),
            );
            return;
          }
          unawaited(requestRefresh());
        });
        return PersonalContentDispatchReceipt.retryScheduled(
          errorCode: errorCode,
          retryAt: retryAt,
        );
      }
      _emit(
        PersonalContentDispatchState(
          phase: PersonalContentDispatchPhase.failed,
          errorCode: errorCode,
          consecutiveFailures: _consecutiveFailures,
        ),
      );
      return PersonalContentDispatchReceipt.failed(errorCode: errorCode);
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
    PersonalContentDeliveryException(:final code) => code,
    PersonalDeviceSyncException(:final code) => code,
    TimeoutException() => 'content_refresh_timeout',
    _ => 'personal_content_refresh_failed',
  };

  void _emit(PersonalContentDispatchState state) {
    if (!_disposed) onState(state);
  }
}
