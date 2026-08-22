import 'package:synapse_core/synapse_core.dart';
import 'package:test/test.dart';

void main() {
  group('curriculum study workspace models', () {
    test('keeps learner identity stable across curriculum releases', () {
      final key = CurriculumStudyWorkspaceKey(
        sourceId: 'source.harrison-sim',
        nodeId: 'node.micro.001',
      );
      final note = CurriculumStudyNote(
        id: 'note.001',
        locale: ContentLocale.fa,
        body: 'نکتهٔ شخصی دربارهٔ این میکرودرس',
        anchorId: 'interaction.001',
        revision: 1,
        createdAt: DateTime.utc(2026, 7, 18, 8),
        updatedAt: DateTime.utc(2026, 7, 18, 8),
      );
      final workspace = CurriculumStudyWorkspace(
        key: key,
        lastOpenedReleaseId: 'release.002',
        isBookmarked: true,
        notes: [note],
        focusSecondsTotal: 1500,
        focusSessionCount: 1,
        lastFocusSegmentId: 'focus.001',
        lastFocusSegmentSeconds: 1500,
        lastFocusCompletedAt: DateTime.utc(2026, 7, 18, 8, 25),
        revision: 4,
        createdAt: DateTime.utc(2026, 7, 18, 8),
        updatedAt: DateTime.utc(2026, 7, 18, 8, 25),
      );

      expect(key.stableId, 'source.harrison-sim|node.micro.001');
      expect(CurriculumStudyWorkspaceKey.fromJson(key.toJson()), key);
      expect(CurriculumStudyNote.fromJson(note.toJson()), note);
      expect(CurriculumStudyWorkspace.fromJson(workspace.toJson()), workspace);
      expect(workspace.key.stableId, isNot(contains('release.002')));
    });

    test('rejects ambiguous focus and duplicate-note state', () {
      final key = CurriculumStudyWorkspaceKey(
        sourceId: 'source.harrison-sim',
        nodeId: 'node.micro.001',
      );
      final note = CurriculumStudyNote(
        id: 'note.001',
        locale: ContentLocale.en,
        body: 'A personal study note',
        revision: 1,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      expect(
        () => CurriculumStudyWorkspace(
          key: key,
          lastOpenedReleaseId: 'release.001',
          isBookmarked: false,
          notes: [note, note],
          focusSecondsTotal: 0,
          focusSessionCount: 0,
          revision: 1,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
        throwsArgumentError,
      );
      expect(
        () => CurriculumStudyWorkspace(
          key: key,
          lastOpenedReleaseId: 'release.001',
          isBookmarked: false,
          notes: const [],
          focusSecondsTotal: 60,
          focusSessionCount: 1,
          lastFocusSegmentId: 'focus.001',
          revision: 1,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
        throwsArgumentError,
      );
    });

    test('bounds learner-authored note bodies', () {
      expect(
        () => CurriculumStudyNote(
          id: 'note.001',
          locale: ContentLocale.en,
          body: 'x' * (CurriculumStudyNote.maxBodyLength + 1),
          revision: 1,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
        throwsArgumentError,
      );
    });
  });
}
