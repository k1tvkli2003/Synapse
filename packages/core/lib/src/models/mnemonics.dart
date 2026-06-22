import 'package:equatable/equatable.dart';

import 'ids.dart';

/// A community mnemonic with votes, tags and an optional concept anchor
/// (prompt 04 §5 / 13).
class Mnemonic extends Equatable {
  const Mnemonic({
    required this.id,
    required this.title,
    required this.body,
    this.expansion,
    this.authorId,
    this.authorName = 'Synapse',
    this.tags = const [],
    this.conceptIds = const [],
    this.upvotes = 0,
    this.downvotes = 0,
    this.myVote = 0,
    this.saved = false,
    this.createdAt,
  });

  final MnemonicId id;
  final String title;

  /// The mnemonic itself, e.g. "SOCRATES".
  final String body;

  /// What each letter / line expands to.
  final String? expansion;
  final UserId? authorId;
  final String authorName;
  final List<TagId> tags;
  final List<ConceptId> conceptIds;
  final int upvotes;
  final int downvotes;

  /// Current user's vote: -1, 0, +1.
  final int myVote;
  final bool saved;
  final DateTime? createdAt;

  int get score => upvotes - downvotes;

  Mnemonic copyWith({int? upvotes, int? downvotes, int? myVote, bool? saved}) => Mnemonic(
        id: id,
        title: title,
        body: body,
        expansion: expansion,
        authorId: authorId,
        authorName: authorName,
        tags: tags,
        conceptIds: conceptIds,
        createdAt: createdAt,
        upvotes: upvotes ?? this.upvotes,
        downvotes: downvotes ?? this.downvotes,
        myVote: myVote ?? this.myVote,
        saved: saved ?? this.saved,
      );

  @override
  List<Object?> get props => [id, upvotes, downvotes, myVote, saved];
}

class Collection extends Equatable {
  const Collection({required this.id, required this.title, this.mnemonicIds = const []});
  final String id;
  final String title;
  final List<MnemonicId> mnemonicIds;

  @override
  List<Object?> get props => [id, title, mnemonicIds];
}
