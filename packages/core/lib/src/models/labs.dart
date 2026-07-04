import 'package:equatable/equatable.dart';

import 'ids.dart';

enum LabPanelType {
  cbc,
  bmp,
  lft;

  String get label => switch (this) {
        LabPanelType.cbc => 'CBC',
        LabPanelType.bmp => 'BMP',
        LabPanelType.lft => 'LFT',
      };

  String get fullName => switch (this) {
        LabPanelType.cbc => 'Complete Blood Count',
        LabPanelType.bmp => 'Basic Metabolic Panel',
        LabPanelType.lft => 'Liver Function Tests',
      };

  static LabPanelType? tryParse(String v) {
    for (final p in LabPanelType.values) {
      if (p.name == v) return p;
    }
    return null;
  }
}

enum LabFlag { low, normal, high, criticalLow, criticalHigh }

/// Definition of one measurable analyte and its reference interval.
class LabAnalyte extends Equatable {
  const LabAnalyte({
    required this.id,
    required this.name,
    required this.unit,
    required this.refLow,
    required this.refHigh,
    this.criticalLow,
    this.criticalHigh,
    this.conceptId,
  });

  final String id;
  final String name;
  final String unit;
  final double refLow;
  final double refHigh;
  final double? criticalLow;
  final double? criticalHigh;
  final ConceptId? conceptId;

  LabFlag flagFor(double value) {
    if (criticalLow != null && value <= criticalLow!) return LabFlag.criticalLow;
    if (criticalHigh != null && value >= criticalHigh!) return LabFlag.criticalHigh;
    if (value < refLow) return LabFlag.low;
    if (value > refHigh) return LabFlag.high;
    return LabFlag.normal;
  }

  @override
  List<Object?> get props => [id, name, unit, refLow, refHigh];
}

class LabValue extends Equatable {
  const LabValue({required this.analyteId, required this.value});
  final String analyteId;
  final double value;

  Map<String, dynamic> toJson() => {'analyteId': analyteId, 'value': value};
  factory LabValue.fromJson(Map<String, dynamic> j) =>
      LabValue(analyteId: j['analyteId'] as String, value: (j['value'] as num).toDouble());

  @override
  List<Object?> get props => [analyteId, value];
}

enum InterpretationSeverity { info, watch, concern, critical }

/// A single pattern-based finding produced by the rule engine (prompt 16).
class Interpretation extends Equatable {
  const Interpretation({
    required this.title,
    required this.detail,
    this.severity = InterpretationSeverity.info,
    this.conceptIds = const [],
    this.nextSteps = const [],
    this.firedRuleId,
  });

  final String title;
  final String detail;
  final InterpretationSeverity severity;
  final List<ConceptId> conceptIds;
  final List<String> nextSteps;

  /// Which rule fired this — part of the audit trail.
  final String? firedRuleId;

  @override
  List<Object?> get props => [title, detail, severity, firedRuleId];
}

/// The full deterministic output of evaluating a panel.
class RuleResult extends Equatable {
  const RuleResult({
    required this.panel,
    required this.flags,
    required this.interpretations,
    this.derivedIndices = const {},
    this.rulesetVersion = 'v1.0.0',
    this.evaluatedAt,
  });

  final LabPanelType panel;

  /// analyteId → flag for every entered value.
  final Map<String, LabFlag> flags;
  final List<Interpretation> interpretations;

  /// Computed indices (e.g. anion gap, AST/ALT ratio).
  final Map<String, double> derivedIndices;
  final String rulesetVersion;
  final DateTime? evaluatedAt;

  bool get hasCritical =>
      interpretations.any((i) => i.severity == InterpretationSeverity.critical);

  @override
  List<Object?> get props => [panel, flags, interpretations, derivedIndices, rulesetVersion];
}
