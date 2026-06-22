import 'package:equatable/equatable.dart';

import 'ids.dart';

/// An audio-first social post — a short clinical voice clip (prompt 19).
class Round extends Equatable {
  const Round({
    required this.id,
    required this.title,
    required this.authorName,
    required this.durationSec,
    this.authorHandle = '',
    this.audioUrl,
    this.transcript,
    this.tags = const [],
    this.conceptIds = const [],
    this.likes = 0,
    this.commentCount = 0,
    this.liked = false,
    this.remixOf,
    this.createdAt,
  });

  final RoundId id;
  final String title;
  final String authorName;
  final String authorHandle;
  final double durationSec;
  final String? audioUrl;
  final String? transcript;
  final List<String> tags;
  final List<ConceptId> conceptIds;
  final int likes;
  final int commentCount;
  final bool liked;
  final RoundId? remixOf;
  final DateTime? createdAt;

  Round copyWith({int? likes, bool? liked, int? commentCount}) => Round(
        id: id,
        title: title,
        authorName: authorName,
        authorHandle: authorHandle,
        durationSec: durationSec,
        audioUrl: audioUrl,
        transcript: transcript,
        tags: tags,
        conceptIds: conceptIds,
        remixOf: remixOf,
        createdAt: createdAt,
        likes: likes ?? this.likes,
        liked: liked ?? this.liked,
        commentCount: commentCount ?? this.commentCount,
      );

  @override
  List<Object?> get props => [id, likes, liked, commentCount];
}

class RoundComment extends Equatable {
  const RoundComment({
    required this.id,
    required this.roundId,
    required this.authorName,
    required this.body,
    this.at,
  });

  final String id;
  final RoundId roundId;
  final String authorName;
  final String body;
  final DateTime? at;

  @override
  List<Object?> get props => [id, roundId, authorName, body];
}
