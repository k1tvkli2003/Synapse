import 'package:synapse_core/synapse_core.dart';

/// A community-style mnemonics library (prompt 13). Real, widely-taught hooks.
class MnemonicsSeed {
  const MnemonicsSeed._();

  static List<Mnemonic> all = [
    Mnemonic(id: 'm_socrates', title: 'Pain history', body: 'SOCRATES', expansion: 'Site, Onset, Character, Radiation, Associations, Time course, Exacerbating/relieving, Severity', authorName: 'Dr. Amaro', tags: ['history', 'pain'], conceptIds: const ['c_chest_pain'], upvotes: 412, createdAt: DateTime(2025, 9, 2)),
    Mnemonic(id: 'm_mudpiles', title: 'High anion-gap acidosis', body: 'MUDPILES', expansion: 'Methanol, Uremia, DKA, Propylene glycol, Iron/INH, Lactic acidosis, Ethylene glycol, Salicylates', authorName: 'Sara N.', tags: ['acid-base', 'nephrology'], conceptIds: const ['c_anion_gap', 'c_acidosis'], upvotes: 388, createdAt: DateTime(2025, 8, 18)),
    Mnemonic(id: 'm_opqrst', title: 'Symptom assessment', body: 'OPQRST', expansion: 'Onset, Provocation, Quality, Radiation, Severity, Time', authorName: 'Maya', tags: ['history'], conceptIds: const ['c_chest_pain'], upvotes: 256, createdAt: DateTime(2025, 7, 30)),
    Mnemonic(id: 'm_macrocytic', title: 'Macrocytic anemia causes', body: 'FAT RBC', expansion: 'Fetus (pregnancy), Antifolates, Thyroid (hypo), Reticulocytosis, B12/folate, Cirrhosis/alcohol', authorName: 'Dev', tags: ['hematology'], conceptIds: const ['c_macro_anemia', 'c_anemia'], upvotes: 173, createdAt: DateTime(2025, 9, 12)),
    Mnemonic(id: 'm_hyperk', title: 'Hyperkalemia treatment', body: 'C BIG K Drop', expansion: 'Calcium, Bicarb, Insulin+Glucose, Kayexalate/Dialysis, β-agonist', authorName: 'ICU Nurse', tags: ['emergency', 'electrolytes'], conceptIds: const ['c_hyperkalemia'], upvotes: 301, createdAt: DateTime(2025, 6, 4)),
    Mnemonic(id: 'm_6ps', title: 'Acute limb ischemia', body: 'The 6 Ps', expansion: 'Pain, Pallor, Pulselessness, Paresthesia, Paralysis, Poikilothermia', authorName: 'Vascular', tags: ['surgery', 'vascular'], upvotes: 142, createdAt: DateTime(2025, 5, 21)),
    Mnemonic(id: 'm_cardiac', title: 'Causes of clubbing', body: 'CLUBBING', expansion: 'Cyanotic heart disease, Lung (cancer, fibrosis), Ulcerative colitis, Bronchiectasis, Benign mesothelioma, Infective endocarditis, Neurogenic tumors, GI malabsorption', authorName: 'Maya', tags: ['exam'], upvotes: 98, createdAt: DateTime(2025, 9, 1)),
    Mnemonic(id: 'm_diarrhea', title: 'Bloody diarrhea bugs', body: 'CHESS', expansion: 'Campylobacter, Hemorrhagic E. coli, Entamoeba, Salmonella, Shigella', authorName: 'Micro TA', tags: ['microbiology', 'GI'], conceptIds: const ['c_infection'], upvotes: 211, createdAt: DateTime(2025, 8, 8)),
    Mnemonic(id: 'm_jvp', title: 'Causes of raised JVP', body: 'PQRST', expansion: 'Pericardial effusion, Quantity of fluid (overload), Right heart failure, SVC obstruction, Tricuspid regurgitation/stenosis', authorName: 'Cardio', tags: ['cardiology', 'exam'], upvotes: 87, createdAt: DateTime(2025, 7, 2)),
    Mnemonic(id: 'm_warfarin', title: 'Warfarin interactions', body: 'Have a SAD MEAL', expansion: 'Sulfonamides, Amiodarone, Diltiazem, Metronidazole, Erythromycin, Azoles, Levofloxacin', authorName: 'PharmD', tags: ['pharmacology'], conceptIds: const ['c_beta_lactam'], upvotes: 165, createdAt: DateTime(2025, 6, 28)),
    Mnemonic(id: 'm_murmurs', title: 'Systolic vs diastolic murmurs', body: 'PASS / PAID', expansion: 'Systolic: Pulmonary/Aortic Stenosis, mitral/tricuspid regurg (Spit). Diastolic: Aortic/Pulmonary regurg, mitral/tricuspid stenosis (Paid)', authorName: 'Sara N.', tags: ['cardiology', 'auscultation'], conceptIds: const ['c_systolic_murmur'], upvotes: 199, createdAt: DateTime(2025, 9, 19)),
    Mnemonic(id: 'm_anaphylaxis', title: 'Anaphylaxis management', body: 'A to E + Epi', expansion: 'Airway, Breathing, Circulation, Disability, Exposure — and IM epinephrine early', authorName: 'EM', tags: ['emergency'], conceptIds: const ['c_anaphylaxis'], upvotes: 233, createdAt: DateTime(2025, 8, 30)),
  ];
}
