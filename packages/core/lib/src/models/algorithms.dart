import 'package:equatable/equatable.dart';

import 'ids.dart';

enum AlgoNodeKind { decision, outcome }

/// One branch out of a decision node.
class AlgoOption extends Equatable {
  const AlgoOption({required this.label, required this.next});
  final String label;
  final String next; // target node id

  @override
  List<Object?> get props => [label, next];
}

/// A node in a clinical decision flowchart — either a question with options, or
/// a terminal outcome/recommendation (prompt 04 §5 / 17).
class AlgoNode extends Equatable {
  const AlgoNode({
    required this.id,
    required this.kind,
    required this.text,
    this.options = const [],
    this.detail,
    this.conceptId,
  });

  final String id;
  final AlgoNodeKind kind;
  final String text;
  final List<AlgoOption> options; // decision nodes
  final String? detail; // outcome explanation / recommendation
  final ConceptId? conceptId;

  bool get isOutcome => kind == AlgoNodeKind.outcome;

  @override
  List<Object?> get props => [id, kind, text, options, detail];
}

class DiagnosticAlgorithm extends Equatable {
  const DiagnosticAlgorithm({
    required this.id,
    required this.title,
    required this.startNodeId,
    required this.nodes,
    this.description,
    this.specialty,
    this.conceptIds = const [],
    this.authorName = 'Synapse',
    this.source,
  });

  final AlgorithmId id;
  final String title;
  final String? description;
  final String? specialty;
  final String startNodeId;
  final Map<String, AlgoNode> nodes;
  final List<ConceptId> conceptIds;
  final String authorName;

  /// Citation backing the flowchart (clinical trust, prompt 50).
  final String? source;

  AlgoNode? node(String id) => nodes[id];
  AlgoNode? get start => nodes[startNodeId];
  int get nodeCount => nodes.length;

  @override
  List<Object?> get props => [id, title, startNodeId, nodes];
}

/// A saved play-through: the ordered node ids the user visited.
class SavedSession extends Equatable {
  const SavedSession({
    required this.algorithmId,
    required this.path,
    this.at,
    this.outcomeText,
  });

  final AlgorithmId algorithmId;
  final List<String> path;
  final DateTime? at;
  final String? outcomeText;

  @override
  List<Object?> get props => [algorithmId, path, at];
}
