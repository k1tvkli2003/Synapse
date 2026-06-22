import 'package:synapse_core/synapse_core.dart';

/// Virtual Patient encounters (prompt 34) — each weaves multiple modules so a
/// case is impossible to finish with one module alone. Completing one
/// distributes mastery to every concept it touches (prompt 32).
class CasesSeed {
  const CasesSeed._();

  static const List<VirtualPatientCase> all = [
    VirtualPatientCase(
      id: 'case_chestpain',
      title: 'Crushing chest pain',
      demographics: '58-year-old man, smoker, hypertensive',
      presentation: 'A 58-year-old man arrives with 40 minutes of crushing substernal chest pain radiating to the left arm, diaphoretic and nauseated.',
      difficulty: 3,
      finalDiagnosis: 'Acute STEMI',
      conceptIds: ['c_chest_pain', 'c_stemi', 'c_systolic_murmur'],
      stages: [
        CaseStage(module: ModuleKey.algorithms, title: 'Triage', prompt: 'What is your immediate first step?', options: ['Send him to radiology for a chest X-ray', 'ABCs, O₂, IV access, monitor + 12-lead ECG within 10 min', 'Reassure and discharge', 'Give a proton-pump inhibitor and wait'], correctIndex: 1, conceptIds: ['c_chest_pain'], rationale: 'Undifferentiated chest pain: stabilise and obtain an ECG within 10 minutes.'),
        CaseStage(module: ModuleKey.ecg, title: 'Read the ECG', prompt: 'The monitor shows this tracing. What is it?', options: ['Normal sinus rhythm', 'STEMI', 'Atrial fibrillation', 'Pericarditis'], correctIndex: 1, conceptIds: ['c_stemi'], rationale: 'Localised ST elevation with reciprocal change = STEMI.', payload: {'rhythm': 'stemi'}),
        CaseStage(module: ModuleKey.sounds, title: 'Auscultate', prompt: 'You hear a holosystolic murmur at the apex radiating to the axilla. Most likely?', options: ['Aortic stenosis', 'Acute mitral regurgitation', 'Pericardial rub', 'Innocent flow murmur'], correctIndex: 1, conceptIds: ['c_systolic_murmur'], rationale: 'Papillary muscle dysfunction after MI can cause acute MR.', payload: {'sound': 's_mr'}),
        CaseStage(module: ModuleKey.algorithms, title: 'Disposition', prompt: 'Best definitive management?', options: ['Outpatient stress test next week', 'Primary PCI (cath lab)', 'PPI trial', 'CT abdomen'], correctIndex: 1, conceptIds: ['c_stemi'], rationale: 'STEMI → emergent reperfusion with primary PCI.'),
      ],
    ),
    VirtualPatientCase(
      id: 'case_weak_dialysis',
      title: 'Weakness in a dialysis patient',
      demographics: '63-year-old woman, ESRD, missed dialysis',
      presentation: 'A 63-year-old on hemodialysis missed two sessions and now feels weak with palpitations.',
      difficulty: 3,
      finalDiagnosis: 'Severe hyperkalemia',
      conceptIds: ['c_hyperkalemia', 'c_ecg_hyperk', 'c_potassium'],
      stages: [
        CaseStage(module: ModuleKey.labs, title: 'Interpret the BMP', prompt: 'K⁺ 7.1, HCO₃ 18, Cr 8.2. The most dangerous value is…', options: ['Bicarbonate', 'Potassium', 'Creatinine', 'Sodium'], correctIndex: 1, conceptIds: ['c_hyperkalemia'], rationale: 'K⁺ 7.1 is immediately life-threatening.', payload: {'panel': 'bmp'}),
        CaseStage(module: ModuleKey.ecg, title: 'Check the ECG', prompt: 'Which finding do you expect first?', options: ['Peaked T waves', 'Delta wave', 'Q waves', 'U waves'], correctIndex: 0, conceptIds: ['c_ecg_hyperk'], rationale: 'Peaked T waves are the earliest ECG sign of hyperkalemia.', payload: {'rhythm': 'hyperkalemia'}),
        CaseStage(module: ModuleKey.algorithms, title: 'First drug', prompt: 'With ECG changes, the FIRST agent to give is…', options: ['Insulin + glucose', 'IV calcium gluconate', 'Salbutamol', 'Furosemide'], correctIndex: 1, conceptIds: ['c_hyperkalemia'], rationale: 'Calcium stabilises the myocardium first; then shift and remove K⁺.'),
      ],
    ),
  ];

  static VirtualPatientCase? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }
}
