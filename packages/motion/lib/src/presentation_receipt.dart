enum MotionPreference { full, reduced, off }

enum MotionSurface { study, clinical, evidence }

enum MotionTier { micro, standard, milestone, showpiece, functional }

enum PresentationPriority { low, normal, high, critical }

enum PresentationStatus {
  queued,
  playing,
  played,
  interrupted,
  skipped,
  reduced,
  suppressed,
  expired,
}

extension PresentationStatusX on PresentationStatus {
  bool get isTerminal => switch (this) {
    PresentationStatus.played ||
    PresentationStatus.interrupted ||
    PresentationStatus.skipped ||
    PresentationStatus.reduced ||
    PresentationStatus.suppressed ||
    PresentationStatus.expired => true,
    PresentationStatus.queued || PresentationStatus.playing => false,
  };
}

extension PresentationPriorityX on PresentationPriority {
  int get rank => switch (this) {
    PresentationPriority.low => 0,
    PresentationPriority.normal => 1,
    PresentationPriority.high => 2,
    PresentationPriority.critical => 3,
  };
}

final class PresentationReceipt {
  PresentationReceipt({
    required this.receiptId,
    required this.sourceEventId,
    required this.sequenceKey,
    required this.tier,
    required this.occurredAtUtc,
    this.priority = PresentationPriority.normal,
    this.celebratory = true,
    this.coalescingKey,
    this.expiresAtUtc,
    Map<String, Object?> payload = const {},
  }) : payload = _freezeMap(payload) {
    _requireToken(receiptId, 'receiptId');
    _requireToken(sourceEventId, 'sourceEventId');
    _requireToken(sequenceKey, 'sequenceKey');
    if (coalescingKey != null) _requireToken(coalescingKey!, 'coalescingKey');
    if (expiresAtUtc != null && !expiresAtUtc!.isAfter(occurredAtUtc)) {
      throw ArgumentError.value(
        expiresAtUtc,
        'expiresAtUtc',
        'Expiry must be later than occurrence.',
      );
    }
  }

  static const currentSchemaVersion = 1;

  final String receiptId;
  final String sourceEventId;
  final String sequenceKey;
  final MotionTier tier;
  final PresentationPriority priority;
  final bool celebratory;
  final String? coalescingKey;
  final DateTime occurredAtUtc;
  final DateTime? expiresAtUtc;
  final Map<String, Object?> payload;

  String get deduplicationKey => '$sourceEventId|$sequenceKey';

  bool isExpiredAt(DateTime value) {
    final expiry = expiresAtUtc;
    return expiry != null && !value.toUtc().isBefore(expiry.toUtc());
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': currentSchemaVersion,
    'receiptId': receiptId,
    'sourceEventId': sourceEventId,
    'sequenceKey': sequenceKey,
    'tier': _tierCode(tier),
    'priority': _priorityCode(priority),
    'celebratory': celebratory,
    'coalescingKey': coalescingKey,
    'occurredAtUtc': occurredAtUtc.toUtc().toIso8601String(),
    'expiresAtUtc': expiresAtUtc?.toUtc().toIso8601String(),
    'payload': payload,
  };

  factory PresentationReceipt.fromJson(Map<String, Object?> json) {
    final version = json['schemaVersion'];
    if (version != currentSchemaVersion) {
      throw FormatException(
        'Unsupported presentation receipt schema: $version',
      );
    }
    final rawPayload = json['payload'];
    return PresentationReceipt(
      receiptId: _requiredString(json, 'receiptId'),
      sourceEventId: _requiredString(json, 'sourceEventId'),
      sequenceKey: _requiredString(json, 'sequenceKey'),
      tier: _tierFromCode(_requiredString(json, 'tier')),
      priority: _priorityFromCode(_requiredString(json, 'priority')),
      celebratory: json['celebratory'] as bool? ?? true,
      coalescingKey: json['coalescingKey'] as String?,
      occurredAtUtc: DateTime.parse(
        _requiredString(json, 'occurredAtUtc'),
      ).toUtc(),
      expiresAtUtc: switch (json['expiresAtUtc']) {
        final String value => DateTime.parse(value).toUtc(),
        _ => null,
      },
      payload: rawPayload is Map
          ? Map<String, Object?>.from(rawPayload)
          : const {},
    );
  }
}

String _tierCode(MotionTier value) => switch (value) {
  MotionTier.micro => 'micro',
  MotionTier.standard => 'standard',
  MotionTier.milestone => 'milestone',
  MotionTier.showpiece => 'showpiece',
  MotionTier.functional => 'functional',
};

MotionTier _tierFromCode(String value) => switch (value) {
  'micro' => MotionTier.micro,
  'standard' => MotionTier.standard,
  'milestone' => MotionTier.milestone,
  'showpiece' => MotionTier.showpiece,
  'functional' => MotionTier.functional,
  _ => throw FormatException('Unknown motion tier: $value'),
};

String _priorityCode(PresentationPriority value) => switch (value) {
  PresentationPriority.low => 'low',
  PresentationPriority.normal => 'normal',
  PresentationPriority.high => 'high',
  PresentationPriority.critical => 'critical',
};

PresentationPriority _priorityFromCode(String value) => switch (value) {
  'low' => PresentationPriority.low,
  'normal' => PresentationPriority.normal,
  'high' => PresentationPriority.high,
  'critical' => PresentationPriority.critical,
  _ => throw FormatException('Unknown presentation priority: $value'),
};

String _statusCode(PresentationStatus value) => switch (value) {
  PresentationStatus.queued => 'queued',
  PresentationStatus.playing => 'playing',
  PresentationStatus.played => 'played',
  PresentationStatus.interrupted => 'interrupted',
  PresentationStatus.skipped => 'skipped',
  PresentationStatus.reduced => 'reduced',
  PresentationStatus.suppressed => 'suppressed',
  PresentationStatus.expired => 'expired',
};

PresentationStatus _statusFromCode(String value) => switch (value) {
  'queued' => PresentationStatus.queued,
  'playing' => PresentationStatus.playing,
  'played' => PresentationStatus.played,
  'interrupted' => PresentationStatus.interrupted,
  'skipped' => PresentationStatus.skipped,
  'reduced' => PresentationStatus.reduced,
  'suppressed' => PresentationStatus.suppressed,
  'expired' => PresentationStatus.expired,
  _ => throw FormatException('Unknown presentation status: $value'),
};

final class PresentationRecord {
  const PresentationRecord({
    required this.receipt,
    required this.status,
    required this.statusAtUtc,
  });

  final PresentationReceipt receipt;
  final PresentationStatus status;
  final DateTime statusAtUtc;

  PresentationRecord withStatus(PresentationStatus next, DateTime atUtc) =>
      PresentationRecord(
        receipt: receipt,
        status: next,
        statusAtUtc: atUtc.toUtc(),
      );

  Map<String, Object?> toJson() => {
    'receipt': receipt.toJson(),
    'status': _statusCode(status),
    'statusAtUtc': statusAtUtc.toUtc().toIso8601String(),
  };

  factory PresentationRecord.fromJson(Map<String, Object?> json) =>
      PresentationRecord(
        receipt: PresentationReceipt.fromJson(
          Map<String, Object?>.from(json['receipt']! as Map),
        ),
        status: _statusFromCode(_requiredString(json, 'status')),
        statusAtUtc: DateTime.parse(
          _requiredString(json, 'statusAtUtc'),
        ).toUtc(),
      );
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string');
  }
  return value;
}

void _requireToken(String value, String name) {
  if (value.trim().isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty.');
  }
}

Map<String, Object?> _freezeMap(Map<String, Object?> source) =>
    Map<String, Object?>.unmodifiable(
      source.map((key, value) => MapEntry(key, _freezeJson(value))),
    );

Object? _freezeJson(Object? value) => switch (value) {
  null || String() || num() || bool() => value,
  List<Object?>() => List<Object?>.unmodifiable(value.map(_freezeJson)),
  Map<String, Object?>() => _freezeMap(value),
  Map() => _freezeMap(Map<String, Object?>.from(value)),
  _ => throw ArgumentError.value(
    value,
    'payload',
    'Presentation payloads must be JSON-safe.',
  ),
};
