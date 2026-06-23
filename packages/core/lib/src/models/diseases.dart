import 'package:equatable/equatable.dart';

import 'evidence.dart';
import 'ids.dart';

/// Body systems used to browse the Disease & Drug banks (prompt 45 §3).
enum BodySystem {
  cardiovascular,
  respiratory,
  renal,
  gastrointestinal,
  endocrine,
  neurology,
  hematology,
  infectious,
  musculoskeletal,
  psychiatry,
  dermatology,
  reproductive,
  general;

  String get label => switch (this) {
        BodySystem.cardiovascular => 'Cardiovascular',
        BodySystem.respiratory => 'Respiratory',
        BodySystem.renal => 'Renal',
        BodySystem.gastrointestinal => 'Gastrointestinal',
        BodySystem.endocrine => 'Endocrine',
        BodySystem.neurology => 'Neurology',
        BodySystem.hematology => 'Hematology',
        BodySystem.infectious => 'Infectious disease',
        BodySystem.musculoskeletal => 'Musculoskeletal',
        BodySystem.psychiatry => 'Psychiatry',
        BodySystem.dermatology => 'Dermatology',
        BodySystem.reproductive => 'Reproductive',
        BodySystem.general => 'General',
      };
}

/// The clinical picture section of a [Disease] (prompt 45 §1).
class Presentation extends Equatable {
  const Presentation({this.symptoms = const [], this.signs = const []});
  final List<String> symptoms;
  final List<String> signs;

  @override
  List<Object?> get props => [symptoms, signs];
}

/// The investigation plan — cross-links into Labs/ECG/Sounds/Imaging (prompt 45 §1).
class Workup extends Equatable {
  const Workup({
    this.labs = const [],
    this.imaging = const [],
    this.ecg,
    this.sounds,
  });

  final List<String> labs;
  final List<String> imaging;
  final String? ecg;
  final String? sounds;

  @override
  List<Object?> get props => [labs, imaging, ecg, sounds];
}

/// The management plan — cross-links into Drugs/Algorithms/OR (prompt 45 §1).
class Management extends Equatable {
  const Management({
    this.conservative = const [],
    this.medical = const [],
    this.surgical = const [],
    this.drugIds = const [],
    this.algorithmId,
  });

  final List<String> conservative;

  /// Free-text medical management bullets.
  final List<String> medical;
  final List<String> surgical;

  /// Structured links into the Drug Bank (prompt 46).
  final List<String> drugIds;

  /// Optional link into the Algorithms module (prompt 17).
  final AlgorithmId? algorithmId;

  @override
  List<Object?> get props => [conservative, medical, surgical, drugIds, algorithmId];
}

/// A structured, Concept-anchored disease record (prompt 45 §1). Each disease is
/// also a [Concept] node, so studying any linked item raises its mastery.
class Disease extends Equatable {
  const Disease({
    required this.id,
    required this.conceptId,
    required this.name,
    this.synonyms = const [],
    this.icd10 = const [],
    this.specialty = const [],
    this.system = BodySystem.general,
    required this.summary,
    this.epidemiology,
    this.etiology,
    this.riskFactors = const [],
    this.pathophysiology,
    this.presentation = const Presentation(),
    this.redFlags = const [],
    this.workup = const Workup(),
    this.differentials = const [],
    this.criteria = const [],
    this.staging,
    this.management = const Management(),
    this.prognosis,
    this.complications = const [],
    this.prevention,
    this.highYield = const [],
    this.mnemonicIds = const [],
    this.difficulty = 3,
    this.evidence = const Evidence(),
    this.review = const ReviewState(),
  });

  final String id;
  final ConceptId conceptId;
  final String name;
  final List<String> synonyms;
  final List<String> icd10;
  final List<String> specialty;
  final BodySystem system;

  final String summary;
  final String? epidemiology;
  final String? etiology;
  final List<String> riskFactors;
  final String? pathophysiology;
  final Presentation presentation;
  final List<String> redFlags;
  final Workup workup;

  /// Differential diagnoses — links to other [Disease] ids.
  final List<String> differentials;
  final List<String> criteria;
  final String? staging;
  final Management management;
  final String? prognosis;
  final List<String> complications;
  final String? prevention;

  final List<String> highYield;
  final List<MnemonicId> mnemonicIds;
  final int difficulty;
  final Evidence evidence;
  final ReviewState review;

  bool get hasRedFlags => redFlags.isNotEmpty;

  bool matches(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return false;
    if (name.toLowerCase().contains(q)) return true;
    if (synonyms.any((s) => s.toLowerCase().contains(q))) return true;
    return icd10.any((c) => c.toLowerCase().contains(q));
  }

  @override
  List<Object?> get props => [id, conceptId, name, system, summary, difficulty];
}
