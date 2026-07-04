import 'package:equatable/equatable.dart';

import 'diseases.dart';
import 'evidence.dart';
import 'ids.dart';

/// The reference banks that make up the unified Library (prompt 48).
enum LibraryKind {
  atlas,
  imaging,
  procedure,
  guideline,
  journal;

  String get label => switch (this) {
        LibraryKind.atlas => 'Anatomy Atlas',
        LibraryKind.imaging => 'Imaging',
        LibraryKind.procedure => 'Procedures',
        LibraryKind.guideline => 'Guidelines',
        LibraryKind.journal => 'Journal Club',
      };

  String get singular => switch (this) {
        LibraryKind.atlas => 'Atlas entry',
        LibraryKind.imaging => 'Imaging case',
        LibraryKind.procedure => 'Procedure',
        LibraryKind.guideline => 'Guideline',
        LibraryKind.journal => 'Trial summary',
      };

  String get route => switch (this) {
        LibraryKind.atlas => '/library/atlas',
        LibraryKind.imaging => '/library/imaging',
        LibraryKind.procedure => '/library/procedures',
        LibraryKind.guideline => '/library/guidelines',
        LibraryKind.journal => '/library/journal',
      };
}

/// A revealable finding on an imaging case or atlas plate (prompt 48 §1/§2).
class RevealPoint extends Equatable {
  const RevealPoint({required this.label, required this.detail});
  final String label;
  final String detail;

  @override
  List<Object?> get props => [label, detail];
}

/// One numbered step of a procedure or atlas walkthrough (prompt 48 §3).
class LibraryStep extends Equatable {
  const LibraryStep({required this.title, this.detail, this.caution});
  final String title;
  final String? detail;
  final String? caution;

  @override
  List<Object?> get props => [title, detail, caution];
}

/// A unified, Concept-anchored Library entry (prompt 48 §6). One shape backs the
/// Anatomy Atlas, Imaging bank, Procedures, Guidelines and Journal Club so the
/// Library shell, search and the concept hub treat them uniformly.
class LibraryEntry extends Equatable {
  const LibraryEntry({
    required this.id,
    required this.kind,
    required this.title,
    this.conceptIds = const [],
    this.subtitle,
    required this.summary,
    this.body = const [],
    this.steps = const [],
    this.reveals = const [],
    this.system = BodySystem.general,
    this.bullets = const [],
    this.indications = const [],
    this.contraindications = const [],
    this.relatedDiseaseIds = const [],
    this.relatedDrugIds = const [],
    this.year,
    this.evidence = const Evidence(),
    this.review = const ReviewState(),
    this.difficulty = 2,
  });

  final String id;
  final LibraryKind kind;
  final String title;
  final List<ConceptId> conceptIds;
  final String? subtitle;
  final String summary;

  /// Free-text paragraphs (guidelines, journal background).
  final List<String> body;

  /// Ordered steps (procedures, atlas walkthroughs).
  final List<LibraryStep> steps;

  /// Reveal-on-tap findings (imaging, atlas labels).
  final List<RevealPoint> reveals;

  final BodySystem system;
  final List<String> bullets;
  final List<String> indications;
  final List<String> contraindications;
  final List<String> relatedDiseaseIds;
  final List<String> relatedDrugIds;
  final int? year;
  final Evidence evidence;
  final ReviewState review;
  final int difficulty;

  String get route => '${kind.route}/$id';

  bool matches(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return false;
    return title.toLowerCase().contains(q) ||
        summary.toLowerCase().contains(q) ||
        (subtitle ?? '').toLowerCase().contains(q);
  }

  @override
  List<Object?> get props => [id, kind, title, conceptIds, difficulty];
}
