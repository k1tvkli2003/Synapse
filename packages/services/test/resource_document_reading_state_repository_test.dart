import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:test/test.dart';

const _digest =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  late MemoryKeyValueStore store;
  late MutableClock clock;
  late ResourceDocument document;

  setUp(() {
    store = MemoryKeyValueStore();
    clock = MutableClock(DateTime.utc(2026, 7, 22, 12));
    document = ResourceDocument(
      id: 'document.pdf.001',
      displayName: 'Cardiology.pdf',
      mediaType: 'application/pdf',
      contentSha256: _digest,
      byteLength: 4096,
      pageCount: 120,
      origin: ResourceDocumentOrigin.userImport,
      createdAt: clock.nowUtc(),
    );
  });

  test(
    'restores one private reward-neutral page position after restart',
    () async {
      final first = LocalResourceDocumentReadingStateRepository(
        store: store,
        clock: clock,
      );
      final saved = await first.savePosition(
        document: document,
        pageNumber: 34,
        pagePositionMillionths: 0,
        expectedRevision: null,
      );
      final restarted = LocalResourceDocumentReadingStateRepository(
        store: store,
        clock: clock,
      );

      expect(await restarted.read(document.id), saved);
      final wire = store
          .snapshot[LocalResourceDocumentReadingStateRepository.stateKey]
          .toString();
      expect(wire, contains('pageNumber: 34'));
      expect(wire.toLowerCase(), isNot(contains('xp')));
      expect(wire.toLowerCase(), isNot(contains('mastery')));
    },
  );

  test(
    'idempotent save keeps revision and stale competing write fails',
    () async {
      final repository = LocalResourceDocumentReadingStateRepository(
        store: store,
        clock: clock,
      );
      final first = await repository.savePosition(
        document: document,
        pageNumber: 4,
        pagePositionMillionths: 0,
        expectedRevision: null,
      );
      final same = await repository.savePosition(
        document: document,
        pageNumber: 4,
        pagePositionMillionths: 0,
        expectedRevision: first.revision,
      );
      expect(same.revision, first.revision);

      final second = await repository.savePosition(
        document: document,
        pageNumber: 5,
        pagePositionMillionths: 0,
        expectedRevision: first.revision,
      );
      expect(second.revision, 2);
      await expectLater(
        repository.savePosition(
          document: document,
          pageNumber: 6,
          pagePositionMillionths: 0,
          expectedRevision: first.revision,
        ),
        throwsA(
          isA<ResourceDocumentReadingStateException>().having(
            (error) => error.code,
            'code',
            'stale_document_reading_position_revision',
          ),
        ),
      );
    },
  );

  test(
    'corrupt integrity summary is reported without throwing private data',
    () async {
      await store.write(LocalResourceDocumentReadingStateRepository.stateKey, {
        'schemaVersion': 1,
        'records': <String, Object?>{},
        'integrity': {
          'recordCount': 9,
          'pageNumberTotal': 0,
          'revisionTotal': 0,
        },
      });
      final repository = LocalResourceDocumentReadingStateRepository(
        store: store,
        clock: clock,
      );

      final issues = await repository.auditIntegrity();

      expect(issues, hasLength(1));
      expect(issues.single.code, 'corrupt_document_reading_state_registry');
    },
  );
}
