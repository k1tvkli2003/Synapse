import 'package:equatable/equatable.dart';

import 'ids.dart';
import 'module_key.dart';

/// The shared shape every learnable thing exposes (prompt 33). A term, card,
/// mnemonic, ECG case, heart sound, lab pattern, algorithm node, drama cue or
/// virtual-patient case all register as a [LearnItem] so global search (36),
/// the concept hub (30) and the study plan (35) can treat them uniformly.
class LearnItem extends Equatable {
  const LearnItem({
    required this.id,
    required this.module,
    required this.title,
    required this.route,
    this.subtitle,
    this.conceptIds = const [],
    this.keywords = const [],
    this.difficulty = 2,
  });

  final LearnItemId id;
  final ModuleKey module;

  /// Human title shown in search results and the concept hub.
  final String title;
  final String? subtitle;

  /// Deep-link route that opens this item (from the route map, prompt 31).
  final String route;

  /// Concepts this item anchors to — the cross-module glue.
  final List<ConceptId> conceptIds;

  /// Extra search keywords beyond the title/subtitle.
  final List<String> keywords;

  /// 1 (easiest) … 5 (hardest); used by the learner model & study plan.
  final int difficulty;

  bool matches(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return false;
    if (title.toLowerCase().contains(q)) return true;
    if ((subtitle ?? '').toLowerCase().contains(q)) return true;
    return keywords.any((k) => k.toLowerCase().contains(q));
  }

  @override
  List<Object?> get props => [id, module, title, subtitle, route, conceptIds, difficulty];
}
