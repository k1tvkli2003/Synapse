import 'package:synapse_core/synapse_core.dart';

/// Seed Terms content (prompt 11). Real medical terminology across paths, using
/// all eight exercise kinds so the drill renderer is exercised end-to-end.
class TermsSeed {
  const TermsSeed._();

  static const List<CoursePath> paths = [
    CoursePath(
      id: 'p_roots',
      title: 'Medical Roots',
      description: 'Greek & Latin building blocks of medical language.',
      iconKey: 'book',
      units: [
        Unit(
          id: 'u_roots_1',
          title: 'Body Systems',
          subtitle: 'Core organ roots',
          lessons: [
            Lesson(
              id: 'l_roots_organs',
              title: 'Organ roots',
              conceptIds: ['c_cardio_root', 'c_hepato_root', 'c_nephro_root'],
              exercises: [
                Exercise(id: 'e1', kind: ExerciseKind.multipleChoice, conceptId: 'c_cardio_root', prompt: 'What does the root "cardi/o" mean?', options: ['Liver', 'Heart', 'Kidney', 'Lung'], correctIndex: 1, explanation: 'Cardi/o = heart (cardiology, myocarditis).'),
                Exercise(id: 'e2', kind: ExerciseKind.multipleChoice, conceptId: 'c_hepato_root', prompt: 'What does "hepat/o" refer to?', options: ['Kidney', 'Stomach', 'Liver', 'Brain'], correctIndex: 2, explanation: 'Hepat/o = liver (hepatitis).'),
                Exercise(id: 'e3', kind: ExerciseKind.typeAnswer, conceptId: 'c_nephro_root', prompt: 'Type the organ that "nephr/o" refers to.', answer: 'kidney', explanation: 'Nephr/o = kidney (nephrology).'),
                Exercise(id: 'e4', kind: ExerciseKind.matchPairs, prompt: 'Match each root to its meaning.', pairs: {'cardi/o': 'heart', 'hepat/o': 'liver', 'nephr/o': 'kidney', 'pneum/o': 'lung'}),
                Exercise(id: 'e5', kind: ExerciseKind.trueFalse, prompt: '"Nephr/o" means liver.', options: ['True', 'False'], correctIndex: 1, explanation: 'Nephr/o means kidney; hepat/o means liver.'),
              ],
            ),
            Lesson(
              id: 'l_roots_suffix',
              title: 'Suffixes',
              conceptIds: ['c_cardio_root'],
              exercises: [
                Exercise(id: 'e1', kind: ExerciseKind.multipleChoice, prompt: 'The suffix "-itis" means…', options: ['Removal', 'Inflammation', 'Pain', 'Enlargement'], correctIndex: 1, explanation: '-itis = inflammation (hepatitis, carditis).'),
                Exercise(id: 'e2', kind: ExerciseKind.multipleChoice, prompt: '"-megaly" means…', options: ['Enlargement', 'Narrowing', 'Bleeding', 'Hardening'], correctIndex: 0, explanation: '-megaly = enlargement (hepatomegaly).'),
                Exercise(id: 'e3', kind: ExerciseKind.fillBlank, prompt: 'Inflammation of the liver is hepat____.', answer: 'itis', explanation: 'Hepat + itis = hepatitis.'),
                Exercise(id: 'e4', kind: ExerciseKind.wordBank, prompt: 'Build: "enlargement of the heart".', tokens: ['cardio', 'megaly', 'itis', 'pathy'], answer: 'cardio megaly'),
              ],
            ),
          ],
        ),
      ],
    ),
    CoursePath(
      id: 'p_cardio',
      title: 'Cardiology',
      description: 'Rhythms, signs and the vocabulary of the heart.',
      iconKey: 'heart',
      units: [
        Unit(
          id: 'u_cardio_1',
          title: 'Rhythms',
          lessons: [
            Lesson(
              id: 'l_cardio_rhythms',
              title: 'Naming rhythms',
              conceptIds: ['c_afib', 'c_bradycardia', 'c_vtach'],
              exercises: [
                Exercise(id: 'e1', kind: ExerciseKind.multipleChoice, conceptId: 'c_bradycardia', prompt: 'A heart rate below 60 bpm is called…', options: ['Tachycardia', 'Bradycardia', 'Fibrillation', 'Flutter'], correctIndex: 1, explanation: 'Brady- = slow.'),
                Exercise(id: 'e2', kind: ExerciseKind.reverseChoice, conceptId: 'c_afib', prompt: 'Which term means an irregularly irregular atrial rhythm?', options: ['Atrial flutter', 'Atrial fibrillation', 'Sinus arrhythmia', 'Junctional rhythm'], correctIndex: 1, explanation: 'Atrial fibrillation = irregularly irregular, no P waves.'),
                Exercise(id: 'e3', kind: ExerciseKind.typeAnswer, conceptId: 'c_vtach', prompt: 'Type the abbreviation for ventricular tachycardia.', answer: 'vt', explanation: 'VT (also V-tach).'),
                Exercise(id: 'e4', kind: ExerciseKind.trueFalse, conceptId: 'c_bradycardia', prompt: '"Tachy-" means slow.', options: ['True', 'False'], correctIndex: 1, explanation: 'Tachy- = fast; brady- = slow.'),
              ],
            ),
          ],
        ),
      ],
    ),
    CoursePath(
      id: 'p_pharm',
      title: 'Pharmacology',
      description: 'Drug classes and how they fight disease.',
      iconKey: 'pill',
      units: [
        Unit(
          id: 'u_pharm_1',
          title: 'Antibiotics',
          lessons: [
            Lesson(
              id: 'l_pharm_abx',
              title: 'Antibiotic classes',
              conceptIds: ['c_beta_lactam', 'c_mrsa'],
              exercises: [
                Exercise(id: 'e1', kind: ExerciseKind.multipleChoice, conceptId: 'c_beta_lactam', prompt: 'Beta-lactams work by inhibiting…', options: ['Protein synthesis', 'Cell-wall synthesis', 'DNA gyrase', 'Folate synthesis'], correctIndex: 1, explanation: 'Beta-lactams bind PBPs and block cell-wall cross-linking.'),
                Exercise(id: 'e2', kind: ExerciseKind.multipleChoice, conceptId: 'c_mrsa', prompt: 'First-line for MRSA is…', options: ['Amoxicillin', 'Vancomycin', 'Cephalexin', 'Penicillin G'], correctIndex: 1, explanation: 'MRSA is resistant to beta-lactams; use vancomycin/linezolid.'),
                Exercise(id: 'e3', kind: ExerciseKind.matchPairs, prompt: 'Match drug to class.', pairs: {'Ciprofloxacin': 'Fluoroquinolone', 'Vancomycin': 'Glycopeptide', 'Azithromycin': 'Macrolide', 'Ceftriaxone': 'Cephalosporin'}),
                Exercise(id: 'e4', kind: ExerciseKind.fillBlank, prompt: 'Fluoroquinolones inhibit DNA ______.', answer: 'gyrase', explanation: 'They target DNA gyrase / topoisomerase.'),
              ],
            ),
          ],
        ),
      ],
    ),
  ];

  static CoursePath? pathById(String id) {
    for (final p in paths) {
      if (p.id == id) return p;
    }
    return null;
  }

  static Lesson? lessonById(String id) {
    for (final p in paths) {
      for (final u in p.units) {
        for (final l in u.lessons) {
          if (l.id == id) return l;
        }
      }
    }
    return null;
  }
}
