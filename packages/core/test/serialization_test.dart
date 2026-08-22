import 'package:synapse_core/synapse_core.dart';
import 'package:test/test.dart';

void main() {
  test('authoritative events persist inside a versioned envelope', () {
    final event = LessonCompleted(
      source: ModuleKey.terms,
      correct: 4,
      total: 5,
      conceptIds: const ['concept.fixture'],
      at: DateTime.utc(2026, 7, 17, 12),
    );

    final json = SynapseEventCodec.encode(event);
    final decoded = SynapseEventCodec.decode(json) as LessonCompleted;

    expect(json['schemaVersion'], SynapseEventCodec.currentSchemaVersion);
    expect(json['type'], 'LessonCompleted');
    expect(decoded.source, ModuleKey.terms);
    expect(decoded.conceptIds, const ['concept.fixture']);
  });

  test('unsupported event schema fails explicitly', () {
    expect(
      () => SynapseEventCodec.decode({
        'schemaVersion': 999,
        'type': 'LessonCompleted',
        'payload': const <String, dynamic>{},
      }),
      throwsA(
        isA<SerializationException>().having(
          (error) => error.code,
          'code',
          SerializationIssueCode.unsupportedSchemaVersion,
        ),
      ),
    );
  });

  test('stable enum codec is independent from declaration index', () {
    final codec = StableEnumCodec<ModuleKey>({
      'reference': ModuleKey.terms,
      'clinical': ModuleKey.ecg,
    });

    expect(codec.encode(ModuleKey.ecg), 'clinical');
    expect(codec.decode('reference'), ModuleKey.terms);
    expect(() => codec.decode(1), throwsA(isA<SerializationException>()));
  });

  test('legacy reduceMotion preference migrates to reduced mode', () {
    final prefs = UserPrefs.fromJson(const {'reduceMotion': true});

    expect(prefs.motionMode, MotionModePref.reduced);
    expect(prefs.reduceMotion, isTrue);
    expect(prefs.toJson(), isNot(contains('motionMode')));
    expect(prefs.toJson()['reduceMotion'], isTrue);
  });

  test('off motion mode round-trips without losing the legacy projection', () {
    const prefs = UserPrefs(motionMode: MotionModePref.off);
    final restored = UserPrefs.fromJson(prefs.toJson());

    expect(restored.motionMode, MotionModePref.off);
    expect(restored.reduceMotion, isTrue);
  });
}
