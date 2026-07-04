import 'package:equatable/equatable.dart';

import 'evidence.dart';
import 'ids.dart';

/// The class of a clinical tool (prompt 47 §1).
enum ToolCategory {
  score,
  formula,
  converter,
  decision;

  String get label => switch (this) {
        ToolCategory.score => 'Score',
        ToolCategory.formula => 'Formula',
        ToolCategory.converter => 'Converter',
        ToolCategory.decision => 'Decision tool',
      };
}

/// Input widget kind for a tool field (prompt 47 §1).
enum ToolInputType { number, select, boolean }

/// One choice in a `select`/`boolean` input — carries the points it contributes
/// to additive scores (CHA₂DS₂-VASc, Wells, CURB-65, …).
class ToolOption extends Equatable {
  const ToolOption({required this.label, required this.value, this.points = 0});
  final String label;

  /// Stable value for formulas (e.g. numeric coefficient or a flag).
  final double value;

  /// Points contributed to a `sum` score when selected.
  final double points;

  @override
  List<Object?> get props => [label, value, points];
}

/// A single input field of a [ClinicalTool] (prompt 47 §1).
class ToolInput extends Equatable {
  const ToolInput({
    required this.key,
    required this.label,
    this.type = ToolInputType.number,
    this.unit,
    this.options = const [],
    this.min,
    this.max,
    this.defaultValue,
    this.points = 0,
    this.help,
  });

  final String key;
  final String label;
  final ToolInputType type;
  final String? unit;

  /// For [ToolInputType.select].
  final List<ToolOption> options;

  /// For [ToolInputType.number] validation.
  final double? min;
  final double? max;
  final double? defaultValue;

  /// Points a `boolean` input contributes to a `sum` score when true.
  final double points;
  final String? help;

  @override
  List<Object?> get props => [key, label, type, unit, options, min, max];
}

/// A coloured interpretation band for a result (prompt 47 §1).
class OutputBand extends Equatable {
  const OutputBand({
    required this.min,
    required this.max,
    required this.label,
    required this.interpretation,
    required this.colorHex,
  });

  final double min;
  final double max;
  final String label;
  final String interpretation;
  final int colorHex;

  bool contains(double v) => v >= min && v <= max;

  @override
  List<Object?> get props => [min, max, label, colorHex];
}

/// A data-driven calculator/score (prompt 47 §1). New tools need no code: scores
/// are additive (`formulaKey == 'sum'`); formulas dispatch on [formulaKey] in
/// the calculator engine.
class ClinicalTool extends Equatable {
  const ClinicalTool({
    required this.id,
    required this.name,
    this.conceptIds = const [],
    this.category = ToolCategory.score,
    required this.formulaKey,
    this.description,
    this.inputs = const [],
    this.outputUnit,
    this.outputLabel = 'Result',
    this.bands = const [],
    this.references = const [],
    this.relatedDiseaseIds = const [],
    this.relatedDrugIds = const [],
    this.specialty,
    this.evidence = const Evidence(),
    this.review = const ReviewState(),
  });

  final String id;
  final String name;
  final List<ConceptId> conceptIds;
  final ToolCategory category;

  /// 'sum' for additive scores; otherwise a named formula in the engine.
  final String formulaKey;
  final String? description;
  final List<ToolInput> inputs;
  final String? outputUnit;
  final String outputLabel;
  final List<OutputBand> bands;
  final List<Citation> references;
  final List<String> relatedDiseaseIds;
  final List<String> relatedDrugIds;
  final String? specialty;
  final Evidence evidence;
  final ReviewState review;

  bool matches(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return false;
    if (name.toLowerCase().contains(q)) return true;
    return (description ?? '').toLowerCase().contains(q) ||
        (specialty ?? '').toLowerCase().contains(q);
  }

  @override
  List<Object?> get props => [id, name, category, formulaKey, inputs];
}
