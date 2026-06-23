import 'package:equatable/equatable.dart';

import 'diseases.dart';
import 'evidence.dart';
import 'ids.dart';

/// Severity of a drug–drug interaction (prompt 46 §2).
enum InteractionSeverity {
  minor,
  moderate,
  major,
  contraindicated;

  String get label => switch (this) {
        InteractionSeverity.minor => 'Minor',
        InteractionSeverity.moderate => 'Moderate',
        InteractionSeverity.major => 'Major',
        InteractionSeverity.contraindicated => 'Contraindicated',
      };

  /// Higher = more dangerous; used to rank checker output.
  int get rank => index;
}

/// Educational dosing across populations (prompt 46 §1). Never prescribing advice.
class Dosing extends Equatable {
  const Dosing({this.adult, this.pediatric, this.renal, this.hepatic});
  final String? adult;
  final String? pediatric;
  final String? renal;
  final String? hepatic;

  @override
  List<Object?> get props => [adult, pediatric, renal, hepatic];
}

/// Pharmacokinetics (prompt 46 §1).
class Pharmacokinetics extends Equatable {
  const Pharmacokinetics({
    this.absorption,
    this.distribution,
    this.metabolism,
    this.excretion,
    this.halfLife,
  });
  final String? absorption;
  final String? distribution;
  final String? metabolism;
  final String? excretion;
  final String? halfLife;

  bool get isEmpty =>
      absorption == null && distribution == null && metabolism == null &&
      excretion == null && halfLife == null;

  @override
  List<Object?> get props => [absorption, distribution, metabolism, excretion, halfLife];
}

/// One edge in the interaction graph (prompt 46 §1/§2). Either a specific
/// [withDrugId] or a [withClassId] (class-level interaction) is set.
class DrugInteraction extends Equatable {
  const DrugInteraction({
    this.withDrugId,
    this.withClassId,
    required this.severity,
    required this.effect,
    this.mechanism,
  });

  final String? withDrugId;
  final String? withClassId;
  final InteractionSeverity severity;
  final String effect;
  final String? mechanism;

  @override
  List<Object?> get props => [withDrugId, withClassId, severity, effect, mechanism];
}

/// The normalized drug-class layer (prompt 46 §1).
class DrugClass extends Equatable {
  const DrugClass({
    required this.id,
    required this.name,
    this.conceptId,
    this.summary,
    this.classEffects = const [],
    this.memberIds = const [],
    this.system = BodySystem.general,
  });

  final String id;
  final String name;
  final ConceptId? conceptId;
  final String? summary;
  final List<String> classEffects;
  final List<String> memberIds;
  final BodySystem system;

  @override
  List<Object?> get props => [id, name, conceptId, memberIds];
}

/// Common vs serious adverse effects (prompt 46 §1).
class AdverseEffects extends Equatable {
  const AdverseEffects({this.common = const [], this.serious = const []});
  final List<String> common;
  final List<String> serious;

  @override
  List<Object?> get props => [common, serious];
}

/// A structured, Concept-anchored drug record (prompt 46 §1).
class Drug extends Equatable {
  const Drug({
    required this.id,
    required this.conceptId,
    required this.genericName,
    this.brandNames = const [],
    this.classIds = const [],
    this.atcCode,
    required this.mechanism,
    this.indications = const [],
    this.indicationDiseaseIds = const [],
    this.offLabel = const [],
    this.dosing = const Dosing(),
    this.routes = const [],
    this.formulations = const [],
    this.pk = const Pharmacokinetics(),
    this.contraindications = const [],
    this.cautions = const [],
    this.pregnancyCategory,
    this.blackBoxWarning,
    this.adverse = const AdverseEffects(),
    this.monitoring = const [],
    this.interactions = const [],
    this.antidote,
    this.counseling = const [],
    this.highYield = const [],
    this.mnemonicIds = const [],
    this.difficulty = 3,
    this.evidence = const Evidence(),
    this.review = const ReviewState(),
  });

  final String id;
  final ConceptId conceptId;
  final String genericName;
  final List<String> brandNames;
  final List<String> classIds;
  final String? atcCode;

  final String mechanism;
  final List<String> indications;
  final List<String> indicationDiseaseIds;
  final List<String> offLabel;

  final Dosing dosing;
  final List<String> routes;
  final List<String> formulations;
  final Pharmacokinetics pk;

  final List<String> contraindications;
  final List<String> cautions;
  final String? pregnancyCategory;
  final String? blackBoxWarning;
  final AdverseEffects adverse;
  final List<String> monitoring;
  final List<DrugInteraction> interactions;
  final String? antidote;
  final List<String> counseling;

  final List<String> highYield;
  final List<MnemonicId> mnemonicIds;
  final int difficulty;
  final Evidence evidence;
  final ReviewState review;

  bool get hasBlackBox => blackBoxWarning != null;

  bool matches(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return false;
    if (genericName.toLowerCase().contains(q)) return true;
    return brandNames.any((b) => b.toLowerCase().contains(q));
  }

  @override
  List<Object?> get props => [id, conceptId, genericName, classIds, difficulty];
}
