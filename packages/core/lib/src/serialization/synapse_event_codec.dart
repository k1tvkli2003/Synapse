import '../events/synapse_event.dart';
import '../models/module_key.dart';
import '../models/reward.dart';
import 'stable_enum_codec.dart';
import 'versioned_envelope.dart';

/// The only supported persistence boundary for authoritative domain events.
abstract final class SynapseEventCodec {
  static const currentSchemaVersion = 1;

  static final _moduleCodec = StableEnumCodec<ModuleKey>({
    for (final module in ModuleKey.values) module.name: module,
  });
  static final _rewardKindCodec = StableEnumCodec<RewardKind>({
    for (final kind in RewardKind.values) kind.name: kind,
  });

  static Map<String, dynamic> encode(SynapseEvent event) {
    final legacy = encodeLegacy(event);
    final type = legacy.remove('type')! as String;
    return VersionedEnvelope(
      schemaVersion: currentSchemaVersion,
      type: type,
      payload: legacy,
    ).toJson();
  }

  static SynapseEvent decode(Map<String, dynamic> json) {
    final envelope = VersionedEnvelope.fromJson(
      json,
      supportedVersions: const {currentSchemaVersion},
    );
    return decodeLegacy({...envelope.payload, 'type': envelope.type});
  }

  /// Compatibility reader for the archived pre-envelope fixtures.
  static SynapseEvent decodeLegacy(Map<String, dynamic> json) {
    final at = _date(json, 'at');
    return switch (json['type']) {
      'ConceptStudied' => ConceptStudied(
        conceptId: _string(json, 'conceptId'),
        source: _moduleCodec.decode(json['source']),
        correct: _bool(json, 'correct'),
        at: at,
      ),
      'ConceptStruggled' => ConceptStruggled(
        conceptId: _string(json, 'conceptId'),
        source: _moduleCodec.decode(json['source']),
        at: at,
      ),
      'ItemMastered' => ItemMastered(
        conceptId: _string(json, 'conceptId'),
        at: at,
      ),
      'LessonCompleted' => LessonCompleted(
        source: _moduleCodec.decode(json['source']),
        correct: _integer(json, 'correct'),
        total: _integer(json, 'total'),
        conceptIds: _strings(json, 'conceptIds'),
        at: at,
      ),
      'CaseCompleted' => CaseCompleted(
        caseId: _string(json, 'caseId'),
        conceptIds: _strings(json, 'conceptIds'),
        at: at,
      ),
      'RewardGranted' => RewardGranted(
        event: _decodeReward(_map(json, 'event')),
        at: at,
      ),
      'StreakChanged' => StreakChanged(
        current: _integer(json, 'current'),
        at: at,
      ),
      'ContentCreated' => ContentCreated(
        source: _moduleCodec.decode(json['source']),
        itemId: _string(json, 'itemId'),
        at: at,
      ),
      'SocialInteraction' => SocialInteraction(
        source: _moduleCodec.decode(json['source']),
        kind: _string(json, 'kind'),
        at: at,
      ),
      'QuestProgressed' => QuestProgressed(
        questId: _string(json, 'questId'),
        at: at,
      ),
      final type => throw SerializationException(
        code: SerializationIssueCode.unknownWireValue,
        message: 'Unknown SynapseEvent type.',
        source: type,
      ),
    };
  }

  /// Compatibility writer used only by the preservation/rollback harness.
  static Map<String, dynamic> encodeLegacy(SynapseEvent event) {
    final common = <String, dynamic>{'at': event.at.toIso8601String()};
    return switch (event) {
      ConceptStudied() => {
        ...common,
        'conceptId': event.conceptId,
        'correct': event.correct,
        'source': _moduleCodec.encode(event.source),
        'type': 'ConceptStudied',
      },
      ConceptStruggled() => {
        ...common,
        'conceptId': event.conceptId,
        'source': _moduleCodec.encode(event.source),
        'type': 'ConceptStruggled',
      },
      ItemMastered() => {
        ...common,
        'conceptId': event.conceptId,
        'type': 'ItemMastered',
      },
      LessonCompleted() => {
        ...common,
        'conceptIds': event.conceptIds,
        'correct': event.correct,
        'source': _moduleCodec.encode(event.source),
        'total': event.total,
        'type': 'LessonCompleted',
      },
      CaseCompleted() => {
        ...common,
        'caseId': event.caseId,
        'conceptIds': event.conceptIds,
        'type': 'CaseCompleted',
      },
      RewardGranted() => {
        ...common,
        'event': _encodeReward(event.event),
        'type': 'RewardGranted',
      },
      StreakChanged() => {
        ...common,
        'current': event.current,
        'type': 'StreakChanged',
      },
      ContentCreated() => {
        ...common,
        'itemId': event.itemId,
        'source': _moduleCodec.encode(event.source),
        'type': 'ContentCreated',
      },
      SocialInteraction() => {
        ...common,
        'kind': event.kind,
        'source': _moduleCodec.encode(event.source),
        'type': 'SocialInteraction',
      },
      QuestProgressed() => {
        ...common,
        'questId': event.questId,
        'type': 'QuestProgressed',
      },
    };
  }

  static RewardEvent _decodeReward(Map<String, dynamic> json) => RewardEvent(
    source: _moduleCodec.decode(json['source']),
    kind: _rewardKindCodec.decode(json['kind']),
    xp: _integer(json, 'xp'),
    gems: _integer(json, 'gems'),
    conceptIds: _strings(json, 'conceptIds'),
    firstTry: _bool(json, 'firstTry'),
    at: _date(json, 'at'),
  );

  static Map<String, dynamic> _encodeReward(RewardEvent event) => {
    'at': event.at.toIso8601String(),
    'conceptIds': event.conceptIds,
    'firstTry': event.firstTry,
    'gems': event.gems,
    'kind': _rewardKindCodec.encode(event.kind),
    'source': _moduleCodec.encode(event.source),
    'xp': event.xp,
  };
}

Map<String, dynamic> _map(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map) return Map<String, dynamic>.from(value);
  throw _invalid(key, value);
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw _invalid(key, value);
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw _invalid(key, value);
}

bool _bool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw _invalid(key, value);
}

DateTime _date(Map<String, dynamic> json, String key) {
  final value = json[key];
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed != null) return parsed;
  throw _invalid(key, value);
}

List<String> _strings(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List && value.every((item) => item is String)) {
    return List<String>.unmodifiable(value.cast<String>());
  }
  throw _invalid(key, value);
}

SerializationException _invalid(String key, Object? value) =>
    SerializationException(
      code: SerializationIssueCode.invalidField,
      message: 'Invalid or missing field: $key.',
      source: value,
    );
