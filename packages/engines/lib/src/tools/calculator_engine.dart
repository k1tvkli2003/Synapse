import 'dart:math' as math;

import 'package:synapse_core/synapse_core.dart';

/// The computed output of a [ClinicalTool] run (prompt 47).
class ToolResult {
  const ToolResult({
    required this.value,
    required this.display,
    this.band,
    this.breakdown = const [],
    this.error,
  });

  final double value;
  final String display;
  final OutputBand? band;
  final List<String> breakdown;
  final String? error;

  bool get hasError => error != null;
}

/// A deterministic, pure-Dart, offline calculator engine (prompt 47 §1). Scores
/// are fully data-driven (additive points); formulas dispatch on `formulaKey`.
/// Every formula is unit-tested so results are trustworthy.
class CalculatorEngine {
  const CalculatorEngine._();

  /// Evaluate [tool] given raw [inputs] (keyed by [ToolInput.key]).
  /// Numbers are `num`; selects carry the chosen [ToolOption.value]; booleans
  /// are `bool`.
  static ToolResult evaluate(ClinicalTool tool, Map<String, dynamic> inputs) {
    try {
      final (value, breakdown) = switch (tool.formulaKey) {
        'sum' => _sum(tool, inputs),
        'bmi' => _bmi(inputs),
        'bsa' => _bsa(inputs),
        'gfr_ckdepi' => _gfrCkdEpi(inputs),
        'map' => _map(inputs),
        'anion_gap' => _anionGap(inputs),
        'corrected_ca' => _correctedCa(inputs),
        'corrected_na' => _correctedNa(inputs),
        'meld' => _meld(inputs),
        'glucose_conv' => _glucoseConv(inputs),
        'due_date' => _dueDate(inputs),
        _ => (double.nan, <String>['Unknown formula: ${tool.formulaKey}']),
      };

      if (value.isNaN) {
        return ToolResult(value: value, display: '—', error: 'Enter all required fields');
      }

      final band = _matchBand(tool.bands, value);
      final rounded = _round(value, tool.formulaKey);
      final unit = tool.outputUnit != null ? ' ${tool.outputUnit}' : '';
      return ToolResult(
        value: value,
        display: '$rounded$unit',
        band: band,
        breakdown: breakdown,
      );
    } catch (_) {
      return const ToolResult(value: double.nan, display: '—', error: 'Check your inputs');
    }
  }

  // ---- additive score ----
  static (double, List<String>) _sum(ClinicalTool tool, Map<String, dynamic> inputs) {
    var total = 0.0;
    final lines = <String>[];
    for (final input in tool.inputs) {
      final raw = inputs[input.key];
      switch (input.type) {
        case ToolInputType.boolean:
          if (raw == true) {
            total += input.points;
            if (input.points != 0) lines.add('${input.label}: +${_n(input.points)}');
          }
        case ToolInputType.select:
          final opt = input.options.firstWhere(
            (o) => o.value == _toNum(raw),
            orElse: () => const ToolOption(label: '', value: 0, points: 0),
          );
          if (opt.points != 0) lines.add('${input.label} (${opt.label}): +${_n(opt.points)}');
          total += opt.points;
        case ToolInputType.number:
          final v = _toNum(raw);
          total += v * input.points;
          if (input.points != 0 && v != 0) lines.add('${input.label}: +${_n(v * input.points)}');
      }
    }
    return (total, lines);
  }

  // ---- named formulas ----
  static (double, List<String>) _bmi(Map<String, dynamic> i) {
    final kg = _req(i, 'weight'), m = _req(i, 'height') / 100;
    if (m <= 0) return (double.nan, const []);
    final bmi = kg / (m * m);
    return (bmi, ['$kg kg / (${m.toStringAsFixed(2)} m)²']);
  }

  static (double, List<String>) _bsa(Map<String, dynamic> i) {
    final kg = _req(i, 'weight'), cm = _req(i, 'height');
    // Mosteller formula.
    final bsa = math.sqrt(cm * kg / 3600);
    return (bsa, ['√(height × weight / 3600) — Mosteller']);
  }

  static (double, List<String>) _gfrCkdEpi(Map<String, dynamic> i) {
    final scr = _req(i, 'creatinine'); // mg/dL
    final age = _req(i, 'age');
    final female = i['sex'] == 1 || i['female'] == true;
    if (scr <= 0 || age <= 0) return (double.nan, const []);
    // CKD-EPI 2021 (race-free).
    final k = female ? 0.7 : 0.9;
    final a = female ? -0.241 : -0.302;
    final ratio = scr / k;
    final minTerm = math.pow(math.min(ratio, 1), a).toDouble();
    final maxTerm = math.pow(math.max(ratio, 1), -1.200).toDouble();
    var gfr = 142 * minTerm * maxTerm * math.pow(0.9938, age).toDouble();
    if (female) gfr *= 1.012;
    return (gfr, ['CKD-EPI 2021 (creatinine, race-free)']);
  }

  static (double, List<String>) _map(Map<String, dynamic> i) {
    final sbp = _req(i, 'sbp'), dbp = _req(i, 'dbp');
    final map = dbp + (sbp - dbp) / 3;
    return (map, ['DBP + ⅓(SBP − DBP)']);
  }

  static (double, List<String>) _anionGap(Map<String, dynamic> i) {
    final na = _req(i, 'na'), cl = _req(i, 'cl'), hco3 = _req(i, 'hco3');
    final ag = na - (cl + hco3);
    return (ag, ['Na − (Cl + HCO₃)']);
  }

  static (double, List<String>) _correctedCa(Map<String, dynamic> i) {
    final ca = _req(i, 'ca'), alb = _req(i, 'albumin');
    final corr = ca + 0.8 * (4.0 - alb);
    return (corr, ['Ca + 0.8 × (4 − albumin)']);
  }

  static (double, List<String>) _correctedNa(Map<String, dynamic> i) {
    final na = _req(i, 'na'), glu = _req(i, 'glucose');
    final corr = na + 0.016 * (glu - 100);
    return (corr, ['Na + 0.016 × (glucose − 100)']);
  }

  static (double, List<String>) _meld(Map<String, dynamic> i) {
    var cr = _req(i, 'creatinine'), bili = _req(i, 'bilirubin'), inr = _req(i, 'inr');
    cr = cr.clamp(1.0, 4.0);
    bili = math.max(bili, 1.0);
    inr = math.max(inr, 1.0);
    final meld = 3.78 * _ln(bili) + 11.2 * _ln(inr) + 9.57 * _ln(cr) + 6.43;
    return (meld.clamp(6, 40), ['MELD = 3.78·ln(bili) + 11.2·ln(INR) + 9.57·ln(Cr) + 6.43']);
  }

  static (double, List<String>) _glucoseConv(Map<String, dynamic> i) {
    final mg = _req(i, 'glucose');
    final mmol = mg / 18.0;
    return (mmol, ['mg/dL ÷ 18']);
  }

  static (double, List<String>) _dueDate(Map<String, dynamic> i) {
    // Returns days of gestation from LMP days entered; Naegele simplification.
    final lmpDays = _req(i, 'lmp_days');
    return (280 - lmpDays, ['280 − days since LMP (Naegele)']);
  }

  // ---- helpers ----
  static OutputBand? _matchBand(List<OutputBand> bands, double v) {
    for (final b in bands) {
      if (b.contains(v)) return b;
    }
    return null;
  }

  static double _req(Map<String, dynamic> i, String k) {
    final v = i[k];
    if (v == null) return double.nan;
    return _toNum(v);
  }

  static double _toNum(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? double.nan;
    if (v is bool) return v ? 1 : 0;
    return double.nan;
  }

  static double _ln(double x) => math.log(x);

  static String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static String _round(double v, String key) {
    // Integer scores; one or two decimals for formulas.
    const intFormulas = {'sum', 'meld', 'map', 'anion_gap', 'gfr_ckdepi', 'due_date'};
    if (intFormulas.contains(key)) return v.round().toString();
    return v.toStringAsFixed(2);
  }
}
