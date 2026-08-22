import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:test/test.dart';

void main() {
  late MemoryKeyValueStore store;
  late MutableClock clock;
  late CurriculumReadingPositionKey key;
  late LocalCurriculumReadingStateRepository repository;

  setUp(() {
    store = MemoryKeyValueStore();
    clock = MutableClock(DateTime.utc(2026, 7, 18, 14));
    key = CurriculumReadingPositionKey(
      sourceId: 'source.harrison-sim',
      microLessonNodeId: 'node.micro.001',
      documentId: 'study.document.001',
    );
    repository = LocalCurriculumReadingStateRepository(
      store: store,
      clock: clock,
    );
  });

  test('persists a semantic anchor across repository restart', () async {
    final saved = await _save(repository, key: key);
    final restarted = LocalCurriculumReadingStateRepository(
      store: store,
      clock: clock,
    );

    expect(await restarted.read(key), saved);
    expect(saved.blockId, 'study.block.002');
    expect(saved.anchorUnitId, 'l10n.study.body.002');
    expect(
      store.snapshot[LocalCurriculumReadingStateRepository.stateKey].toString(),
      isNot(contains('lesson body')),
    );
    expect(await restarted.auditIntegrity(), isEmpty);
  });

  test('identical retries are idempotent and stale changes fail', () async {
    final saved = await _save(repository, key: key);
    final retried = await _save(repository, key: key);
    expect(retried, saved);

    await expectLater(
      _save(
        repository,
        key: key,
        blockId: 'study.block.003',
        blockOrdinal: 3,
        expectedRevision: null,
      ),
      throwsA(
        isA<CurriculumReadingStateException>().having(
          (error) => error.code,
          'code',
          'stale_reading_position_revision',
        ),
      ),
    );
  });

  test(
    'release and locale changes preserve the same semantic identity',
    () async {
      final first = await _save(repository, key: key);
      clock.advance(const Duration(minutes: 2));
      final updated = await _save(
        repository,
        key: key,
        releaseId: 'release.002',
        locale: ContentLocale.fa,
        expectedRevision: first.revision,
      );

      expect(updated.key, first.key);
      expect(updated.lastReadReleaseId, 'release.002');
      expect(updated.lastLocale, ContentLocale.fa);
      expect(updated.revision, first.revision + 1);
    },
  );

  test('lists by source and clears with compare-and-set safety', () async {
    final saved = await _save(repository, key: key);
    expect(await repository.listForSource(key.sourceId), [saved]);

    await expectLater(
      repository.clear(key: key, expectedRevision: saved.revision + 1),
      throwsA(isA<CurriculumReadingStateException>()),
    );
    expect(
      await repository.clear(key: key, expectedRevision: saved.revision),
      isTrue,
    );
    expect(await repository.clear(key: key, expectedRevision: 1), isFalse);
  });

  test('detects integrity drift without package or learner text', () async {
    await _save(repository, key: key);
    final raw = Map<String, Object?>.from(
      store.snapshot[LocalCurriculumReadingStateRepository.stateKey] as Map,
    );
    raw['integrity'] = {
      ...Map<String, Object?>.from(raw['integrity']! as Map),
      'positionPermilleTotal': 999,
    };
    await store.write(LocalCurriculumReadingStateRepository.stateKey, raw);

    final issues = await repository.auditIntegrity();
    expect(issues.single.code, 'corrupt_reading_state_registry');
    expect(issues.single.message, isNot(contains('lesson body')));
  });
}

Future<CurriculumReadingPosition> _save(
  CurriculumReadingStateRepository repository, {
  required CurriculumReadingPositionKey key,
  String releaseId = 'release.001',
  String blockId = 'study.block.002',
  int blockOrdinal = 2,
  ContentLocale locale = ContentLocale.en,
  int? expectedRevision,
}) => repository.savePosition(
  key: key,
  releaseId: releaseId,
  blockId: blockId,
  blockOrdinal: blockOrdinal,
  anchorUnitId: 'l10n.study.body.002',
  documentPositionPermille: 500,
  locale: locale,
  expectedRevision: expectedRevision,
);
