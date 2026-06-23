import 'package:synapse_core/synapse_core.dart';

import 'lab_reference.dart';

/// A deterministic, versioned rule engine (prompt 16). Same input → same output,
/// every interpretation carries the rule id that fired (audit trail) and the
/// concepts it touches (so a struggled pattern propagates across the app).
class LabRuleEngine {
  const LabRuleEngine._();

  static const String version = 'v1.0.0';

  static RuleResult evaluate(LabPanelType panel, Map<String, double> v) {
    final analytes = LabReference.analytes(panel);
    final flags = <String, LabFlag>{};
    for (final a in analytes) {
      if (v.containsKey(a.id)) flags[a.id] = a.flagFor(v[a.id]!);
    }

    final interps = <Interpretation>[];
    final indices = <String, double>{};

    switch (panel) {
      case LabPanelType.cbc:
        _cbc(v, flags, interps);
      case LabPanelType.bmp:
        _bmp(v, flags, interps, indices);
      case LabPanelType.lft:
        _lft(v, flags, interps, indices);
    }

    if (interps.isEmpty) {
      interps.add(const Interpretation(
        title: 'No abnormal pattern detected',
        detail: 'All entered values are within their reference intervals.',
        firedRuleId: 'baseline',
      ));
    }

    // Sort most-severe first.
    interps.sort((a, b) => b.severity.index.compareTo(a.severity.index));

    return RuleResult(
      panel: panel,
      flags: flags,
      interpretations: interps,
      derivedIndices: indices,
      rulesetVersion: version,
      evaluatedAt: DateTime.now(),
    );
  }

  // ---- CBC ----
  static void _cbc(Map<String, double> v, Map<String, LabFlag> f, List<Interpretation> out) {
    final hgb = v['hgb'];
    final mcv = v['mcv'];
    if (hgb != null && hgb < 12.0) {
      final sev = hgb < 7 ? InterpretationSeverity.critical : InterpretationSeverity.concern;
      var morph = 'Anemia';
      var concept = 'c_anemia';
      if (mcv != null) {
        if (mcv < 80) {
          morph = 'Microcytic anemia';
          concept = 'c_micro_anemia';
        } else if (mcv > 100) {
          morph = 'Macrocytic anemia';
          concept = 'c_macro_anemia';
        } else {
          morph = 'Normocytic anemia';
        }
      }
      out.add(Interpretation(
        title: morph,
        detail: 'Hemoglobin ${hgb.toStringAsFixed(1)} g/dL is below the reference range'
            '${mcv != null ? ' with MCV ${mcv.toStringAsFixed(0)} fL' : ''}. '
            '${morph.startsWith('Micro') ? 'Consider iron deficiency or thalassemia.' : morph.startsWith('Macro') ? 'Consider B12/folate deficiency.' : 'Consider acute blood loss, hemolysis or chronic disease.'}',
        severity: sev,
        conceptIds: [concept, 'c_anemia'],
        nextSteps: morph.startsWith('Micro')
            ? const ['Iron studies (ferritin, TIBC)', 'Peripheral smear']
            : morph.startsWith('Macro')
                ? const ['B12 & folate', 'Reticulocyte count']
                : const ['Reticulocyte count', 'Peripheral smear'],
        firedRuleId: 'cbc.anemia',
      ));
    }

    final wbc = v['wbc'];
    if (wbc != null && wbc > 11.0) {
      out.add(Interpretation(
        title: 'Leukocytosis',
        detail: 'WBC ${wbc.toStringAsFixed(1)} ×10⁹/L is elevated — commonly infection, '
            'inflammation, stress or steroids.',
        severity: wbc > 30 ? InterpretationSeverity.concern : InterpretationSeverity.watch,
        conceptIds: const ['c_wbc', 'c_infection'],
        nextSteps: const ['Differential count', 'Assess for source of infection'],
        firedRuleId: 'cbc.leukocytosis',
      ));
    } else if (wbc != null && wbc < 4.0) {
      out.add(Interpretation(
        title: 'Leukopenia',
        detail: 'WBC ${wbc.toStringAsFixed(1)} ×10⁹/L is low — viral infection, marrow '
            'suppression or medication effect.',
        severity: wbc < 1 ? InterpretationSeverity.critical : InterpretationSeverity.concern,
        conceptIds: const ['c_wbc'],
        firedRuleId: 'cbc.leukopenia',
      ));
    }

    final plt = v['plt'];
    if (plt != null && plt < 150) {
      out.add(Interpretation(
        title: 'Thrombocytopenia',
        detail: 'Platelets ${plt.toStringAsFixed(0)} ×10⁹/L are low. Bleeding risk rises '
            'sharply below 20.',
        severity: plt < 20 ? InterpretationSeverity.critical : InterpretationSeverity.concern,
        conceptIds: const ['c_thrombocytopenia'],
        nextSteps: const ['Peripheral smear', 'Review medications'],
        firedRuleId: 'cbc.thrombocytopenia',
      ));
    }
  }

  // ---- BMP ----
  static void _bmp(Map<String, double> v, Map<String, LabFlag> f, List<Interpretation> out, Map<String, double> idx) {
    final na = v['na'];
    final cl = v['cl'];
    final hco3 = v['hco3'];
    final k = v['k'];

    if (na != null && cl != null && hco3 != null) {
      final ag = na - (cl + hco3);
      idx['Anion gap'] = double.parse(ag.toStringAsFixed(1));
      if (ag > 12) {
        out.add(Interpretation(
          title: 'High anion-gap metabolic acidosis',
          detail: 'Anion gap ${ag.toStringAsFixed(0)} mmol/L (>12). Remember MUDPILES: '
              'methanol, uremia, DKA, propylene glycol, INH, lactic acidosis, ethylene glycol, salicylates.',
          severity: InterpretationSeverity.concern,
          conceptIds: const ['c_acidosis', 'c_anion_gap'],
          nextSteps: const ['VBG/ABG', 'Lactate, ketones', 'Calculate delta-delta'],
          firedRuleId: 'bmp.hagma',
        ));
      }
    }

    if (k != null) {
      if (k > 5.0) {
        out.add(Interpretation(
          title: k > 6.5 ? 'Severe hyperkalemia' : 'Hyperkalemia',
          detail: 'Potassium ${k.toStringAsFixed(1)} mmol/L. Watch for peaked T waves and '
              'widened QRS on ECG — a true emergency above 6.5.',
          severity: k > 6.5 ? InterpretationSeverity.critical : InterpretationSeverity.concern,
          conceptIds: const ['c_hyperkalemia', 'c_ecg_hyperk'],
          nextSteps: const ['STAT ECG', 'Calcium gluconate if ECG changes', 'Insulin + glucose'],
          firedRuleId: 'bmp.hyperkalemia',
        ));
      } else if (k < 3.5) {
        out.add(Interpretation(
          title: 'Hypokalemia',
          detail: 'Potassium ${k.toStringAsFixed(1)} mmol/L. Can cause U waves, arrhythmia '
              'and weakness; replete and check magnesium.',
          severity: k < 2.5 ? InterpretationSeverity.critical : InterpretationSeverity.concern,
          conceptIds: const ['c_hypokalemia'],
          nextSteps: const ['Replace K⁺', 'Check magnesium'],
          firedRuleId: 'bmp.hypokalemia',
        ));
      }
    }

    if (na != null) {
      if (na < 135) {
        out.add(Interpretation(
          title: 'Hyponatremia',
          detail: 'Sodium ${na.toStringAsFixed(0)} mmol/L. Assess volume status; correct '
              'slowly to avoid osmotic demyelination.',
          severity: na < 120 ? InterpretationSeverity.critical : InterpretationSeverity.concern,
          conceptIds: const ['c_hyponatremia'],
          nextSteps: const ['Serum + urine osmolality', 'Volume assessment'],
          firedRuleId: 'bmp.hyponatremia',
        ));
      } else if (na > 145) {
        out.add(Interpretation(
          title: 'Hypernatremia',
          detail: 'Sodium ${na.toStringAsFixed(0)} mmol/L — usually a free-water deficit.',
          severity: InterpretationSeverity.concern,
          conceptIds: const ['c_hypernatremia'],
          firedRuleId: 'bmp.hypernatremia',
        ));
      }
    }

    final bun = v['bun'];
    final cr = v['cr'];
    if (bun != null && cr != null && cr > 0) {
      final ratio = bun / cr;
      idx['BUN/Cr ratio'] = double.parse(ratio.toStringAsFixed(1));
      if (cr > 1.3) {
        out.add(Interpretation(
          title: 'Elevated creatinine (possible AKI)',
          detail: 'Creatinine ${cr.toStringAsFixed(2)} mg/dL with BUN/Cr ratio '
              '${ratio.toStringAsFixed(0)}. A ratio >20 suggests a prerenal cause.',
          severity: cr > 4 ? InterpretationSeverity.critical : InterpretationSeverity.concern,
          conceptIds: const ['c_aki'],
          nextSteps: const ['Trend creatinine', 'Urine output', 'Review nephrotoxins'],
          firedRuleId: 'bmp.aki',
        ));
      }
    }

    final glu = v['glu'];
    if (glu != null && glu > 125) {
      out.add(Interpretation(
        title: glu > 250 ? 'Marked hyperglycemia' : 'Hyperglycemia',
        detail: 'Glucose ${glu.toStringAsFixed(0)} mg/dL. If markedly high, evaluate for '
            'DKA/HHS, especially with a high anion gap.',
        severity: glu > 250 ? InterpretationSeverity.concern : InterpretationSeverity.watch,
        conceptIds: const ['c_hyperglycemia', 'c_dka'],
        firedRuleId: 'bmp.hyperglycemia',
      ));
    }
  }

  // ---- LFT ----
  static void _lft(Map<String, double> v, Map<String, LabFlag> f, List<Interpretation> out, Map<String, double> idx) {
    final ast = v['ast'];
    final alt = v['alt'];
    final alp = v['alp'];
    final tbili = v['tbili'];
    final alb = v['alb'];

    final astHigh = ast != null && ast > 40;
    final altHigh = alt != null && alt > 56;
    final alpHigh = alp != null && alp > 147;

    if ((astHigh || altHigh) && !(alpHigh && !astHigh && !altHigh)) {
      final pattern = (alp != null && alp > 147 && (ast == null || ast <= 40) && (alt == null || alt <= 56));
      if (!pattern) {
        out.add(const Interpretation(
          title: 'Hepatocellular pattern',
          detail: 'Transaminases (AST/ALT) are disproportionately elevated — suggests '
              'hepatocyte injury (viral, toxic, ischemic, NAFLD).',
          severity: InterpretationSeverity.concern,
          conceptIds: ['c_hepatocellular'],
          nextSteps: ['Viral hepatitis serologies', 'Medication/alcohol history', 'Ultrasound'],
          firedRuleId: 'lft.hepatocellular',
        ));
      }
      if (ast != null && alt != null && alt > 0) {
        final ratio = ast / alt;
        idx['AST/ALT ratio'] = double.parse(ratio.toStringAsFixed(1));
        if (ratio >= 2) {
          out.add(Interpretation(
            title: 'AST/ALT ratio ≥ 2',
            detail: 'A ratio of ${ratio.toStringAsFixed(1)} classically points to alcoholic '
                'liver disease (or advanced fibrosis).',
            severity: InterpretationSeverity.watch,
            conceptIds: const ['c_alcoholic_hep'],
            firedRuleId: 'lft.ast_alt_ratio',
          ));
        }
      }
    }

    if (alpHigh && !(astHigh || altHigh)) {
      out.add(const Interpretation(
        title: 'Cholestatic pattern',
        detail: 'ALP is elevated out of proportion to transaminases — suggests biliary '
            'obstruction or cholestasis.',
        severity: InterpretationSeverity.concern,
        conceptIds: ['c_cholestasis'],
        nextSteps: ['GGT to confirm hepatic source', 'Right-upper-quadrant ultrasound'],
        firedRuleId: 'lft.cholestatic',
      ));
    }

    if (tbili != null && tbili > 1.2) {
      out.add(Interpretation(
        title: 'Hyperbilirubinemia',
        detail: 'Total bilirubin ${tbili.toStringAsFixed(1)} mg/dL. Jaundice becomes '
            'clinically visible above ~2.5–3 mg/dL.',
        severity: tbili > 10 ? InterpretationSeverity.concern : InterpretationSeverity.watch,
        conceptIds: const ['c_jaundice'],
        firedRuleId: 'lft.bilirubin',
      ));
    }

    if (alb != null && alb < 3.5) {
      out.add(Interpretation(
        title: 'Hypoalbuminemia',
        detail: 'Albumin ${alb.toStringAsFixed(1)} g/dL — chronic liver disease, '
            'malnutrition, nephrotic loss or inflammation.',
        severity: InterpretationSeverity.watch,
        conceptIds: const ['c_synthetic_liver'],
        firedRuleId: 'lft.albumin',
      ));
    }
  }
}
