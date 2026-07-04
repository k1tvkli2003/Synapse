import 'package:synapse_core/synapse_core.dart';

/// Heart & lung auscultation library (prompt 15). Waveforms are synthesised, so
/// no audio assets are required for the trainer to function offline.
class SoundsSeed {
  const SoundsSeed._();

  static const List<BodySound> all = [
    BodySound(id: 's_normal', name: 'Normal S1/S2', kind: SoundKind.heart, options: ['Normal S1/S2', 'S3 gallop', 'Systolic murmur', 'Pericardial rub'], correctIndex: 0, location: 'Apex', description: '"Lub-dub" — closure of mitral/tricuspid then aortic/pulmonic valves.', timingHint: 'Two-component'),
    BodySound(id: 's_s3', name: 'S3 gallop', kind: SoundKind.heart, options: ['Split S2', 'S3 gallop', 'Opening snap', 'Ejection click'], correctIndex: 1, conceptId: 'c_s3', location: 'Apex, bell, left lateral', description: 'Low-pitched early-diastolic sound; volume overload / heart failure.', timingHint: 'Early diastolic'),
    BodySound(id: 's_as', name: 'Aortic stenosis murmur', kind: SoundKind.heart, options: ['Mitral regurgitation', 'Aortic stenosis', 'Aortic regurgitation', 'Mitral stenosis'], correctIndex: 1, conceptId: 'c_systolic_murmur', location: 'Right upper sternal border → carotids', description: 'Harsh crescendo-decrescendo systolic murmur radiating to the carotids.', timingHint: 'Mid-systolic'),
    BodySound(id: 's_mr', name: 'Mitral regurgitation', kind: SoundKind.heart, options: ['Aortic stenosis', 'Mitral regurgitation', 'VSD', 'Tricuspid stenosis'], correctIndex: 1, conceptId: 'c_systolic_murmur', location: 'Apex → axilla', description: 'Holosystolic (pansystolic) murmur radiating to the axilla.', timingHint: 'Holosystolic'),
    BodySound(id: 's_wheeze', name: 'Expiratory wheeze', kind: SoundKind.lung, options: ['Crackles', 'Wheeze', 'Stridor', 'Pleural rub'], correctIndex: 1, conceptId: 'c_wheeze', location: 'Diffuse', description: 'High-pitched musical expiratory sound of airway narrowing (asthma/COPD).', timingHint: 'Expiratory'),
    BodySound(id: 's_crackles', name: 'Fine crackles', kind: SoundKind.lung, options: ['Wheeze', 'Crackles', 'Bronchial breathing', 'Normal'], correctIndex: 1, conceptId: 'c_crackles', location: 'Bases', description: 'Discontinuous popping (Velcro) sounds; pulmonary edema or fibrosis.', timingHint: 'Inspiratory'),
    BodySound(id: 's_stridor', name: 'Stridor', kind: SoundKind.lung, options: ['Wheeze', 'Stridor', 'Crackles', 'Rhonchi'], correctIndex: 1, location: 'Upper airway / neck', description: 'High-pitched inspiratory sound of upper-airway obstruction — an emergency.', timingHint: 'Inspiratory'),
    BodySound(id: 's_rub', name: 'Pleural rub', kind: SoundKind.lung, options: ['Pleural rub', 'Wheeze', 'Crackles', 'Normal'], correctIndex: 0, location: 'Localised', description: 'Creaking "leather" sound from inflamed pleural surfaces.', timingHint: 'Bi-phasic'),
  ];

  static BodySound? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }
}
