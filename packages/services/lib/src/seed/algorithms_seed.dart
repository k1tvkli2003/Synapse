import 'package:synapse_core/synapse_core.dart';

/// Interactive clinical decision flowcharts (prompt 17). Educational, sourced,
/// and concept-anchored. Not for real clinical decision-making.
class AlgorithmsSeed {
  const AlgorithmsSeed._();

  static const List<DiagnosticAlgorithm> all = [
    DiagnosticAlgorithm(
      id: 'algo_chestpain',
      title: 'Acute chest pain triage',
      description: 'A simplified teaching pathway for undifferentiated chest pain.',
      specialty: 'Emergency / Cardiology',
      source: 'Adapted from teaching pathways (educational).',
      conceptIds: ['c_chest_pain', 'c_stemi'],
      startNodeId: 'n1',
      nodes: {
        'n1': AlgoNode(id: 'n1', kind: AlgoNodeKind.decision, text: 'Is the patient hemodynamically unstable?', conceptId: 'c_chest_pain', options: [
          AlgoOption(label: 'Unstable', next: 'n_resus'),
          AlgoOption(label: 'Stable', next: 'n2'),
        ]),
        'n_resus': AlgoNode(id: 'n_resus', kind: AlgoNodeKind.outcome, text: 'Resuscitate first', detail: 'ABCs, O₂, IV access, monitor, call for help. Then continue work-up.'),
        'n2': AlgoNode(id: 'n2', kind: AlgoNodeKind.decision, text: 'ECG within 10 minutes — ST elevation?', conceptId: 'c_stemi', options: [
          AlgoOption(label: 'ST elevation', next: 'n_stemi'),
          AlgoOption(label: 'No ST elevation', next: 'n3'),
        ]),
        'n_stemi': AlgoNode(id: 'n_stemi', kind: AlgoNodeKind.outcome, text: 'STEMI pathway', detail: 'Activate the cath lab for primary PCI; give aspirin. Time is muscle.', conceptId: 'c_stemi'),
        'n3': AlgoNode(id: 'n3', kind: AlgoNodeKind.decision, text: 'Troponin elevated or dynamic?', options: [
          AlgoOption(label: 'Elevated', next: 'n_nstemi'),
          AlgoOption(label: 'Normal', next: 'n4'),
        ]),
        'n_nstemi': AlgoNode(id: 'n_nstemi', kind: AlgoNodeKind.outcome, text: 'NSTEMI / unstable angina', detail: 'Admit, antiplatelet + anticoagulation, risk-stratify for angiography.'),
        'n4': AlgoNode(id: 'n4', kind: AlgoNodeKind.outcome, text: 'Consider non-cardiac causes', detail: 'PE, dissection, GERD, musculoskeletal, anxiety. Use HEART score + serial troponin.'),
      },
    ),
    DiagnosticAlgorithm(
      id: 'algo_anaphylaxis',
      title: 'Anaphylaxis management',
      description: 'Recognise and treat anaphylaxis quickly.',
      specialty: 'Emergency',
      source: 'Adapted from resuscitation guidelines (educational).',
      conceptIds: ['c_anaphylaxis'],
      startNodeId: 'a1',
      nodes: {
        'a1': AlgoNode(id: 'a1', kind: AlgoNodeKind.decision, text: 'Sudden onset + airway/breathing/circulation problem + likely allergen?', conceptId: 'c_anaphylaxis', options: [
          AlgoOption(label: 'Yes — anaphylaxis', next: 'a_epi'),
          AlgoOption(label: 'Uncertain', next: 'a_obs'),
        ]),
        'a_epi': AlgoNode(id: 'a_epi', kind: AlgoNodeKind.decision, text: 'Give IM adrenaline 0.5 mg. Improved after 5 min?', options: [
          AlgoOption(label: 'Improving', next: 'a_monitor'),
          AlgoOption(label: 'No improvement', next: 'a_repeat'),
        ]),
        'a_repeat': AlgoNode(id: 'a_repeat', kind: AlgoNodeKind.outcome, text: 'Repeat adrenaline + escalate', detail: 'Repeat IM adrenaline every 5 min, IV fluids, call critical care, consider adrenaline infusion.'),
        'a_monitor': AlgoNode(id: 'a_monitor', kind: AlgoNodeKind.outcome, text: 'Observe & treat', detail: 'High-flow O₂, IV fluids, observe ≥6–12h for biphasic reaction. Prescribe an auto-injector.'),
        'a_obs': AlgoNode(id: 'a_obs', kind: AlgoNodeKind.outcome, text: 'Observe and reassess', detail: 'If criteria evolve, treat as anaphylaxis. Do not delay adrenaline if in doubt.'),
      },
    ),
    DiagnosticAlgorithm(
      id: 'algo_brady',
      title: 'Symptomatic bradycardia',
      description: 'A teaching adaptation of the ACLS bradycardia approach.',
      specialty: 'Cardiology / Emergency',
      source: 'Adapted from ACLS teaching (educational).',
      conceptIds: ['c_bradycardia'],
      startNodeId: 'b1',
      nodes: {
        'b1': AlgoNode(id: 'b1', kind: AlgoNodeKind.decision, text: 'HR < 50 with signs of poor perfusion?', conceptId: 'c_bradycardia', options: [
          AlgoOption(label: 'Yes', next: 'b_atropine'),
          AlgoOption(label: 'No / stable', next: 'b_monitor'),
        ]),
        'b_atropine': AlgoNode(id: 'b_atropine', kind: AlgoNodeKind.decision, text: 'Atropine 1 mg IV. Responded?', options: [
          AlgoOption(label: 'Responded', next: 'b_monitor'),
          AlgoOption(label: 'No response', next: 'b_pace'),
        ]),
        'b_pace': AlgoNode(id: 'b_pace', kind: AlgoNodeKind.outcome, text: 'Pacing / chronotropes', detail: 'Transcutaneous pacing and/or dopamine or epinephrine infusion; seek expert help.'),
        'b_monitor': AlgoNode(id: 'b_monitor', kind: AlgoNodeKind.outcome, text: 'Monitor & investigate cause', detail: 'Identify reversible causes (drugs, ischemia, electrolytes, hypothyroid).'),
      },
    ),
  ];

  static DiagnosticAlgorithm? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
