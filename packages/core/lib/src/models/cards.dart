import 'package:equatable/equatable.dart';

import 'ids.dart';

/// A flashcard deck. The cards themselves reuse [SrsCard] (prompt 04 §5) so they
/// schedule through the shared SRS engine and mix into the Daily Review.
class Deck extends Equatable {
  const Deck({
    required this.id,
    required this.title,
    this.description,
    this.cardIds = const [],
    this.conceptIds = const [],
    this.colorHex = 0xFF6FD3E8,
  });

  final DeckId id;
  final String title;
  final String? description;
  final List<CardId> cardIds;
  final List<ConceptId> conceptIds;
  final int colorHex;

  int get size => cardIds.length;

  Deck copyWith({String? title, String? description, List<CardId>? cardIds}) => Deck(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        cardIds: cardIds ?? this.cardIds,
        conceptIds: conceptIds,
        colorHex: colorHex,
      );

  @override
  List<Object?> get props => [id, title, cardIds, conceptIds];
}

/// A node in the knowledge-graph view of Cards.
class GraphNode extends Equatable {
  const GraphNode({
    required this.conceptId,
    required this.label,
    required this.x,
    required this.y,
    this.mastery = 0.0,
  });

  final ConceptId conceptId;
  final String label;

  /// Normalised layout position in `[0, 1]` (rendered by a CustomPainter).
  final double x;
  final double y;
  final double mastery;

  @override
  List<Object?> get props => [conceptId, x, y, mastery];
}

class GraphEdge extends Equatable {
  const GraphEdge({required this.from, required this.to, this.label});
  final ConceptId from;
  final ConceptId to;
  final String? label;

  @override
  List<Object?> get props => [from, to];
}
