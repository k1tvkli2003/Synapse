import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:test/test.dart';

void main() {
  late MemoryKeyValueStore store;
  late MutableClock clock;
  late CurriculumStudyWorkspaceKey key;
  late LocalCurriculumStudyWorkspaceRepository repository;

  setUp(() {
    store = MemoryKeyValueStore();
    clock = MutableClock(DateTime.utc(2026, 7, 18, 9));
    key = CurriculumStudyWorkspaceKey(
      sourceId: 'source.harrison-sim',
      nodeId: 'node.micro.001',
    );
    repository = _repository(store, clock, ['note.001', 'note.002']);
  });

  test('persists notes bookmark and focus across repository restart', () async {
    var workspace = await repository.open(key: key, releaseId: 'release.001');
    workspace = await repository.setBookmarked(
      key: key,
      releaseId: 'release.001',
      isBookmarked: true,
      expectedRevision: workspace.revision,
    );
    workspace = await repository.addNote(
      key: key,
      releaseId: 'release.001',
      locale: ContentLocale.en,
      body: '  First line\r\nSecond line  ',
      anchorId: 'interaction.001',
      expectedRevision: workspace.revision,
    );
    clock.advance(const Duration(minutes: 25));
    workspace = await repository.recordFocusSegment(
      key: key,
      releaseId: 'release.001',
      segmentId: 'focus.001',
      durationSeconds: 1500,
      expectedRevision: workspace.revision,
    );

    final restarted = _repository(store, clock, ['unused.001']);
    final restored = await restarted.read(key);
    expect(restored, workspace);
    expect(restored!.isBookmarked, isTrue);
    expect(restored.notes.single.body, 'First line\nSecond line');
    expect(restored.focusSecondsTotal, 1500);
    expect(restored.focusSessionCount, 1);
    expect(await restarted.auditIntegrity(), isEmpty);
  });

  test('release update preserves stable learner material', () async {
    var workspace = await repository.open(key: key, releaseId: 'release.001');
    workspace = await repository.addNote(
      key: key,
      releaseId: 'release.001',
      locale: ContentLocale.fa,
      body: 'یادداشت شخصی',
      expectedRevision: workspace.revision,
    );

    final reopened = await repository.open(key: key, releaseId: 'release.002');
    expect(reopened.key, key);
    expect(reopened.lastOpenedReleaseId, 'release.002');
    expect(reopened.notes, workspace.notes);
    expect(reopened.revision, workspace.revision + 1);
    expect((await repository.listForSource(key.sourceId)).single, reopened);
  });

  test('rejects stale writers and stale note editors', () async {
    final opened = await repository.open(key: key, releaseId: 'release.001');
    final withNote = await repository.addNote(
      key: key,
      releaseId: 'release.001',
      locale: ContentLocale.en,
      body: 'Original',
      expectedRevision: opened.revision,
    );

    await expectLater(
      repository.setBookmarked(
        key: key,
        releaseId: 'release.001',
        isBookmarked: true,
        expectedRevision: opened.revision,
      ),
      throwsA(
        isA<CurriculumStudyWorkspaceException>().having(
          (error) => error.code,
          'code',
          'stale_workspace_revision',
        ),
      ),
    );

    final updated = await repository.updateNote(
      key: key,
      releaseId: 'release.001',
      noteId: withNote.notes.single.id,
      body: 'Updated',
      expectedWorkspaceRevision: withNote.revision,
      expectedNoteRevision: withNote.notes.single.revision,
    );
    await expectLater(
      repository.updateNote(
        key: key,
        releaseId: 'release.001',
        noteId: updated.notes.single.id,
        body: 'Stale overwrite',
        expectedWorkspaceRevision: updated.revision,
        expectedNoteRevision: withNote.notes.single.revision,
      ),
      throwsA(
        isA<CurriculumStudyWorkspaceException>().having(
          (error) => error.code,
          'code',
          'stale_workspace_note_revision',
        ),
      ),
    );
  });

  test('focus retry is idempotent and conflicting reuse fails', () async {
    final opened = await repository.open(key: key, releaseId: 'release.001');
    final recorded = await repository.recordFocusSegment(
      key: key,
      releaseId: 'release.001',
      segmentId: 'focus.001',
      durationSeconds: 300,
      expectedRevision: opened.revision,
    );
    final retried = await repository.recordFocusSegment(
      key: key,
      releaseId: 'release.001',
      segmentId: 'focus.001',
      durationSeconds: 300,
      expectedRevision: opened.revision,
    );
    expect(retried, recorded);
    expect(retried.focusSessionCount, 1);

    await expectLater(
      repository.recordFocusSegment(
        key: key,
        releaseId: 'release.001',
        segmentId: 'focus.001',
        durationSeconds: 301,
        expectedRevision: recorded.revision,
      ),
      throwsA(
        isA<CurriculumStudyWorkspaceException>().having(
          (error) => error.code,
          'code',
          'focus_segment_conflict',
        ),
      ),
    );
  });

  test('serializes same-store mutations across repository instances', () async {
    final opened = await repository.open(key: key, releaseId: 'release.001');
    final second = _repository(store, clock, ['note.002']);

    final outcomes = await Future.wait<Object>([
      repository
          .addNote(
            key: key,
            releaseId: 'release.001',
            locale: ContentLocale.en,
            body: 'First writer',
            expectedRevision: opened.revision,
          )
          .then<Object>((value) => value)
          .catchError((Object error) => error),
      second
          .addNote(
            key: key,
            releaseId: 'release.001',
            locale: ContentLocale.en,
            body: 'Second writer',
            expectedRevision: opened.revision,
          )
          .then<Object>((value) => value)
          .catchError((Object error) => error),
    ]);

    expect(outcomes.whereType<CurriculumStudyWorkspace>(), hasLength(1));
    expect(
      outcomes.whereType<CurriculumStudyWorkspaceException>().single.code,
      'stale_workspace_revision',
    );
    expect((await repository.read(key))!.notes, hasLength(1));
  });

  test('detects integrity summary drift without exposing note text', () async {
    final opened = await repository.open(key: key, releaseId: 'release.001');
    await repository.addNote(
      key: key,
      releaseId: 'release.001',
      locale: ContentLocale.en,
      body: 'Private text must not enter diagnostics',
      expectedRevision: opened.revision,
    );
    final raw = Map<String, Object?>.from(
      store.snapshot[LocalCurriculumStudyWorkspaceRepository.stateKey] as Map,
    );
    raw['integrity'] = {
      ...Map<String, Object?>.from(raw['integrity']! as Map),
      'noteCount': 999,
    };
    await store.write(LocalCurriculumStudyWorkspaceRepository.stateKey, raw);

    final issues = await repository.auditIntegrity();
    expect(issues.single.code, 'corrupt_workspace_registry');
    expect(issues.single.message, isNot(contains('Private text')));
  });
}

LocalCurriculumStudyWorkspaceRepository _repository(
  KeyValueStore store,
  Clock clock,
  List<String> ids,
) => LocalCurriculumStudyWorkspaceRepository(
  store: store,
  clock: clock,
  idSource: SequenceIdSource(ids),
);
