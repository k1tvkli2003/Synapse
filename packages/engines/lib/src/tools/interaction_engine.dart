import 'package:synapse_core/synapse_core.dart';

/// A single found interaction between two selected drugs (prompt 46 §2).
class FoundInteraction {
  const FoundInteraction({
    required this.a,
    required this.b,
    required this.severity,
    required this.effect,
    this.mechanism,
  });

  final Drug a;
  final Drug b;
  final InteractionSeverity severity;
  final String effect;
  final String? mechanism;
}

/// The educational drug-interaction checker (prompt 46 §2). Walks the directed
/// [Drug.interactions] graph for every pair in the selection and returns
/// severity-ranked results. Deterministic + pure Dart so it works offline.
class InteractionEngine {
  const InteractionEngine._();

  static List<FoundInteraction> check(List<Drug> selected) {
    final found = <FoundInteraction>[];

    for (var i = 0; i < selected.length; i++) {
      for (var j = i + 1; j < selected.length; j++) {
        final a = selected[i], b = selected[j];
        final hit = _between(a, b) ?? _between(b, a);
        if (hit != null) {
          // Normalize ordering so the higher-severity description wins.
          found.add(FoundInteraction(
            a: a,
            b: b,
            severity: hit.severity,
            effect: hit.effect,
            mechanism: hit.mechanism,
          ));
        } else {
          // Class-level interaction check.
          final classHit = _classBetween(a, b) ?? _classBetween(b, a);
          if (classHit != null) {
            found.add(FoundInteraction(
              a: a,
              b: b,
              severity: classHit.severity,
              effect: classHit.effect,
              mechanism: classHit.mechanism,
            ));
          }
        }
      }
    }

    found.sort((x, y) => y.severity.rank.compareTo(x.severity.rank));
    return found;
  }

  static DrugInteraction? _between(Drug from, Drug to) {
    for (final ix in from.interactions) {
      if (ix.withDrugId == to.id) return ix;
    }
    return null;
  }

  static DrugInteraction? _classBetween(Drug from, Drug to) {
    for (final ix in from.interactions) {
      if (ix.withClassId != null && to.classIds.contains(ix.withClassId)) return ix;
    }
    return null;
  }
}
