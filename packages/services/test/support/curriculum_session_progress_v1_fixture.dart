/// Frozen pre-migration learner checkpoint used to prove v1 -> v2
/// compatibility independently from the current rollback serializer.
const curriculumSessionProgressV1Fixture = <String, Object?>{
  'schemaVersion': 1,
  'records': <String, Object?>{
    'release.legacy.001|node.legacy.001|session.legacy.001': <String, Object?>{
      'key': <String, Object?>{
        'releaseId': 'release.legacy.001',
        'microLessonNodeId': 'node.legacy.001',
        'sessionId': 'session.legacy.001',
      },
      'phase': 'completed',
      'interactionIndex': 0,
      'revision': 4,
      'startedAt': '2026-07-17T08:00:00.000Z',
      'updatedAt': '2026-07-17T08:02:00.000Z',
      'selectedOptionId': null,
      'choiceResponses': <String, Object?>{
        'interaction.legacy.001': <String, Object?>{
          'id': 'choice-event.legacy.001',
          'interactionId': 'interaction.legacy.001',
          'selectedOptionId': 'option.legacy.a',
          'isCorrect': true,
          'answeredAt': '2026-07-17T08:01:00.000Z',
        },
      },
      'completedAt': '2026-07-17T08:02:00.000Z',
      'completionReceiptId': 'complete.legacy.001',
    },
  },
};
