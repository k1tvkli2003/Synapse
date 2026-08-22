enum BootstrapStage { config, localStore, auth, sync, locale, router }

enum BootstrapStageStatus {
  pending,
  running,
  ready,
  skippedOffline,
  degraded,
  failed,
}

enum BootstrapOutcome { idle, running, ready, degraded, failed }

typedef BootstrapAction = Future<void> Function();
typedef BootstrapTransitionListener = void Function(BootstrapSnapshot snapshot);

final class BootstrapOperation {
  const BootstrapOperation({
    required this.stage,
    required this.action,
    this.critical = true,
    this.requiresNetwork = false,
  });

  final BootstrapStage stage;
  final BootstrapAction action;
  final bool critical;
  final bool requiresNetwork;
}

final class BootstrapFailure {
  const BootstrapFailure({required this.stage, required this.errorType});

  final BootstrapStage stage;

  /// Runtime type only. Error messages can include private user data.
  final String errorType;
}

final class BootstrapSnapshot {
  BootstrapSnapshot({
    required this.outcome,
    required Map<BootstrapStage, BootstrapStageStatus> stages,
    this.currentStage,
    this.failure,
  }) : stages = Map.unmodifiable(stages);

  factory BootstrapSnapshot.initial(Iterable<BootstrapStage> stages) =>
      BootstrapSnapshot(
        outcome: BootstrapOutcome.idle,
        stages: {
          for (final stage in stages) stage: BootstrapStageStatus.pending,
        },
      );

  final BootstrapOutcome outcome;
  final Map<BootstrapStage, BootstrapStageStatus> stages;
  final BootstrapStage? currentStage;
  final BootstrapFailure? failure;

  bool get canRetry =>
      outcome == BootstrapOutcome.failed ||
      outcome == BootstrapOutcome.degraded;

  BootstrapStageStatus statusOf(BootstrapStage stage) =>
      stages[stage] ?? BootstrapStageStatus.pending;
}

/// Ordered, retryable, offline-first application bootstrap state machine.
final class BootstrapCoordinator {
  BootstrapCoordinator({
    required Iterable<BootstrapOperation> operations,
    this.onTransition,
  }) : operations = List.unmodifiable(operations) {
    final stages = this.operations.map((operation) => operation.stage).toList();
    if (stages.toSet().length != stages.length) {
      throw ArgumentError('Bootstrap stages must be unique.');
    }
    _snapshot = BootstrapSnapshot.initial(stages);
  }

  final List<BootstrapOperation> operations;
  final BootstrapTransitionListener? onTransition;
  late BootstrapSnapshot _snapshot;
  bool _executing = false;

  BootstrapSnapshot get snapshot => _snapshot;

  Future<BootstrapSnapshot> start({required bool online}) async {
    _snapshot = BootstrapSnapshot.initial(
      operations.map((operation) => operation.stage),
    );
    return _run(from: 0, online: online);
  }

  Future<BootstrapSnapshot> retry({required bool online}) async {
    if (!snapshot.canRetry) return snapshot;
    final firstRetryIndex = operations.indexWhere((operation) {
      final status = snapshot.statusOf(operation.stage);
      return status == BootstrapStageStatus.failed ||
          status == BootstrapStageStatus.degraded ||
          status == BootstrapStageStatus.skippedOffline;
    });
    if (firstRetryIndex < 0) return snapshot;

    final stages = {...snapshot.stages};
    for (final operation in operations.skip(firstRetryIndex)) {
      stages[operation.stage] = BootstrapStageStatus.pending;
    }
    _snapshot = BootstrapSnapshot(
      outcome: BootstrapOutcome.idle,
      stages: stages,
    );
    _notify();
    return _run(from: firstRetryIndex, online: online);
  }

  Future<BootstrapSnapshot> _run({
    required int from,
    required bool online,
  }) async {
    if (_executing) throw StateError('Bootstrap is already running.');
    _executing = true;
    var degraded = false;
    try {
      for (var index = from; index < operations.length; index += 1) {
        final operation = operations[index];
        if (operation.requiresNetwork && !online) {
          degraded = true;
          _setStage(
            operation.stage,
            BootstrapStageStatus.skippedOffline,
            outcome: BootstrapOutcome.running,
          );
          continue;
        }

        _setStage(
          operation.stage,
          BootstrapStageStatus.running,
          outcome: BootstrapOutcome.running,
          currentStage: operation.stage,
        );
        try {
          await operation.action();
          _setStage(
            operation.stage,
            BootstrapStageStatus.ready,
            outcome: BootstrapOutcome.running,
          );
        } catch (error) {
          final failure = BootstrapFailure(
            stage: operation.stage,
            errorType: error.runtimeType.toString(),
          );
          if (operation.critical) {
            _setStage(
              operation.stage,
              BootstrapStageStatus.failed,
              outcome: BootstrapOutcome.failed,
              failure: failure,
            );
            return snapshot;
          }
          degraded = true;
          _setStage(
            operation.stage,
            BootstrapStageStatus.degraded,
            outcome: BootstrapOutcome.running,
            failure: failure,
          );
        }
      }
      _snapshot = BootstrapSnapshot(
        outcome: degraded || _hasDegradedStage
            ? BootstrapOutcome.degraded
            : BootstrapOutcome.ready,
        stages: snapshot.stages,
      );
      _notify();
      return snapshot;
    } finally {
      _executing = false;
    }
  }

  bool get _hasDegradedStage => snapshot.stages.values.any(
    (status) =>
        status == BootstrapStageStatus.degraded ||
        status == BootstrapStageStatus.skippedOffline,
  );

  void _setStage(
    BootstrapStage stage,
    BootstrapStageStatus status, {
    required BootstrapOutcome outcome,
    BootstrapStage? currentStage,
    BootstrapFailure? failure,
  }) {
    _snapshot = BootstrapSnapshot(
      outcome: outcome,
      stages: {...snapshot.stages, stage: status},
      currentStage: currentStage,
      failure: failure,
    );
    _notify();
  }

  void _notify() => onTransition?.call(snapshot);
}
