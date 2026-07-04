import 'package:synapse_core/synapse_core.dart';

/// Seed ECG drill cases (prompt 14). Each renders from its [rhythm] via the
/// generator, so no image assets are required.
class EcgSeed {
  const EcgSeed._();

  static const List<EcgCase> all = [
    EcgCase(
      id: 'ecg_sinus',
      title: 'Rhythm strip — adult, asymptomatic',
      diagnosis: 'Normal sinus rhythm',
      options: ['Normal sinus rhythm', 'Atrial fibrillation', 'First-degree AV block', 'Sinus tachycardia'],
      correctIndex: 0,
      conceptId: 'c_chest_pain',
      difficulty: 1,
      rateBpm: 72,
      rhythm: EcgRhythm.sinus,
      findings: ['Regular R-R', 'P before every QRS', 'Rate 60–100'],
      teaching: 'Upright P waves, constant PR, narrow QRS, rate 60–100 and regular = normal sinus rhythm.',
    ),
    EcgCase(
      id: 'ecg_afib',
      title: '74y, palpitations',
      diagnosis: 'Atrial fibrillation',
      options: ['Sinus arrhythmia', 'Atrial fibrillation', 'Multifocal atrial tachycardia', 'Atrial flutter'],
      correctIndex: 1,
      conceptId: 'c_afib',
      difficulty: 2,
      rateBpm: 110,
      rhythm: EcgRhythm.afib,
      findings: ['Irregularly irregular', 'No discernible P waves', 'Fibrillatory baseline'],
      teaching: 'Irregularly irregular rhythm with absent P waves and a wavy baseline is atrial fibrillation.',
    ),
    EcgCase(
      id: 'ecg_stemi',
      title: '58y, crushing chest pain',
      diagnosis: 'STEMI',
      options: ['Pericarditis', 'Early repolarization', 'STEMI', 'Left bundle branch block'],
      correctIndex: 2,
      conceptId: 'c_stemi',
      difficulty: 3,
      rateBpm: 88,
      rhythm: EcgRhythm.stemi,
      findings: ['ST elevation', 'Reciprocal changes', 'Convex ST segments'],
      teaching: 'Localised ST elevation with reciprocal depression is a STEMI until proven otherwise — activate the cath lab.',
    ),
    EcgCase(
      id: 'ecg_hyperk',
      title: '63y, dialysis missed, weak',
      diagnosis: 'Hyperkalemia',
      options: ['Hypokalemia', 'Hyperkalemia', 'Hypercalcemia', 'Normal'],
      correctIndex: 1,
      conceptId: 'c_hyperkalemia',
      difficulty: 3,
      rateBpm: 80,
      rhythm: EcgRhythm.hyperkalemia,
      findings: ['Peaked T waves', 'Widening QRS', 'Flattened P waves'],
      teaching: 'Tall, peaked, symmetric T waves with QRS widening = hyperkalemia. Give calcium if there are ECG changes.',
    ),
    EcgCase(
      id: 'ecg_vtach',
      title: '66y, syncope, HR 180',
      diagnosis: 'Ventricular tachycardia',
      options: ['SVT with aberrancy', 'Ventricular tachycardia', 'Atrial flutter', 'Sinus tachycardia'],
      correctIndex: 1,
      conceptId: 'c_vtach',
      difficulty: 4,
      rateBpm: 180,
      rhythm: EcgRhythm.vtach,
      findings: ['Wide QRS', 'Regular, fast', 'AV dissociation'],
      teaching: 'A regular wide-complex tachycardia in an older patient is VT until proven otherwise.',
    ),
    EcgCase(
      id: 'ecg_brady',
      title: '80y, dizzy, HR 42',
      diagnosis: 'Sinus bradycardia',
      options: ['Sinus bradycardia', 'Junctional rhythm', 'Complete heart block', 'Normal'],
      correctIndex: 0,
      conceptId: 'c_bradycardia',
      difficulty: 2,
      rateBpm: 42,
      rhythm: EcgRhythm.bradycardia,
      findings: ['Rate < 60', 'P before every QRS', 'Regular'],
      teaching: 'Each QRS preceded by a normal P at a rate < 60 is sinus bradycardia.',
    ),
    EcgCase(
      id: 'ecg_tachy',
      title: '24y, anxiety, HR 140',
      diagnosis: 'Sinus tachycardia',
      options: ['Atrial flutter', 'Sinus tachycardia', 'AVNRT', 'Atrial fibrillation'],
      correctIndex: 1,
      conceptId: 'c_chest_pain',
      difficulty: 2,
      rateBpm: 140,
      rhythm: EcgRhythm.tachycardia,
      findings: ['Rate > 100', 'P before every QRS', 'Regular'],
      teaching: 'Regular narrow-complex tachycardia with visible P waves before each QRS = sinus tachycardia.',
    ),
    EcgCase(
      id: 'ecg_vfib',
      title: 'Code blue — unresponsive',
      diagnosis: 'Ventricular fibrillation',
      options: ['Asystole', 'Ventricular fibrillation', 'Fine atrial fibrillation', 'Artifact'],
      correctIndex: 1,
      conceptId: 'c_vtach',
      difficulty: 3,
      rateBpm: 300,
      rhythm: EcgRhythm.vfib,
      findings: ['Chaotic baseline', 'No organised QRS', 'No pulse'],
      teaching: 'Chaotic, disorganised waveform with no QRS in a pulseless patient = VF → defibrillate immediately.',
    ),
  ];

  static EcgCase? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }
}
