import 'package:synapse_core/synapse_core.dart';

/// Seed OSCE stations (prompt 52). Each is an AI standardized patient with a
/// hidden, keyword-matched script and a transparent rubric. Educational.
class OsceSeed {
  const OsceSeed._();

  static const List<OsceStation> all = [
    OsceStation(
      id: 'osce_chest_pain',
      title: 'Chest pain history',
      type: OsceType.history,
      patientName: 'Mr. Davies, 58',
      doorSign: 'A 58-year-old man presents to the emergency department with chest pain that started 1 hour ago. Take a focused history, then give your differential and plan.',
      openingLine: "Doctor, I've got this pressure in my chest and I'm a bit scared.",
      conceptIds: ['c_chest_pain', 'c_stemi', 'c_afib'],
      affect: 'Anxious',
      difficulty: 3,
      redFlags: ['Radiation to the arm/jaw', 'Diaphoresis', 'Exertional onset'],
      beats: [
        OsceBeat(topic: 'Site', keywords: ['where', 'site', 'location', 'point'], response: "It's right in the centre of my chest.", essential: true),
        OsceBeat(topic: 'Character', keywords: ['describe', 'character', 'sharp', 'dull', 'pressure', 'like'], response: "It feels like a heavy pressure, like something sitting on me.", essential: true),
        OsceBeat(topic: 'Radiation', keywords: ['radiate', 'spread', 'move', 'arm', 'jaw', 'shoulder'], response: "Yes — it goes down my left arm and up to my jaw.", essential: true),
        OsceBeat(topic: 'Onset', keywords: ['start', 'onset', 'begin', 'doing', 'when'], response: "It came on while I was climbing the stairs about an hour ago.", essential: true),
        OsceBeat(topic: 'Associated', keywords: ['sweat', 'nausea', 'short', 'breath', 'sick', 'clammy'], response: "I'm sweating a lot and feel a bit sick and breathless.", essential: true),
        OsceBeat(topic: 'Severity', keywords: ['severe', 'score', 'scale', 'bad', 'how much'], response: "I'd say it's an 8 out of 10.", essential: true),
        OsceBeat(topic: 'Risk factors', keywords: ['smoke', 'diabetes', 'cholesterol', 'blood pressure', 'family', 'history'], response: "I smoke 20 a day and my dad had a heart attack at 60.", essential: true, domain: OsceDomain.diagnosis),
        OsceBeat(topic: 'Reassurance', keywords: ['okay', 'worry', 'understand', 'here for you', 'look after'], response: "Thank you, that's reassuring to hear.", domain: OsceDomain.empathy),
        OsceBeat(topic: 'Medications', keywords: ['medication', 'tablets', 'drugs', 'taking'], response: "Just something for my blood pressure.", domain: OsceDomain.dataGathering),
      ],
      differentialOptions: ['Acute coronary syndrome', 'Pulmonary embolism', 'Musculoskeletal pain', 'Gastro-oesophageal reflux', 'Aortic dissection'],
      correctDifferential: ['Acute coronary syndrome'],
      planOptions: ['12-lead ECG immediately', 'Troponin', 'Aspirin 300mg', 'Reassure and discharge', 'CT pulmonary angiogram first'],
      correctPlan: ['12-lead ECG immediately', 'Troponin', 'Aspirin 300mg'],
    ),
    OsceStation(
      id: 'osce_breathless',
      title: 'Breathlessness history',
      type: OsceType.history,
      patientName: 'Mrs. Khan, 67',
      doorSign: 'A 67-year-old woman presents with progressive breathlessness over two weeks. Take a focused history and propose your differential and plan.',
      openingLine: "I just can't catch my breath like I used to, doctor.",
      conceptIds: ['c_chf', 'c_copd', 'c_pe'],
      affect: 'Tired',
      difficulty: 3,
      redFlags: ['Orthopnoea', 'Leg swelling', 'Sudden onset'],
      beats: [
        OsceBeat(topic: 'Onset/timing', keywords: ['start', 'when', 'gradual', 'sudden', 'long'], response: "It's been creeping up over the last couple of weeks.", essential: true),
        OsceBeat(topic: 'Orthopnoea', keywords: ['lie', 'flat', 'pillows', 'night', 'sleep'], response: "I have to sleep on three pillows now or I feel like I'm drowning.", essential: true),
        OsceBeat(topic: 'Oedema', keywords: ['swelling', 'legs', 'ankles', 'feet'], response: "My ankles have been really swollen.", essential: true),
        OsceBeat(topic: 'Exertion', keywords: ['walk', 'exertion', 'stairs', 'effort', 'far'], response: "I get breathless just walking to the kitchen now.", essential: true),
        OsceBeat(topic: 'Cough', keywords: ['cough', 'sputum', 'phlegm', 'wheeze'], response: "A little dry cough, no phlegm.", essential: true),
        OsceBeat(topic: 'Chest pain', keywords: ['pain', 'chest'], response: "No real pain, just the breathlessness.", domain: OsceDomain.safety),
        OsceBeat(topic: 'History', keywords: ['heart', 'pressure', 'history', 'conditions', 'past'], response: "I had a heart attack a few years ago and have high blood pressure.", essential: true, domain: OsceDomain.diagnosis),
        OsceBeat(topic: 'Empathy', keywords: ['understand', 'difficult', 'sorry', 'must be'], response: "It has been frightening, thank you for listening.", domain: OsceDomain.empathy),
      ],
      differentialOptions: ['Decompensated heart failure', 'COPD exacerbation', 'Pulmonary embolism', 'Pneumonia', 'Anxiety'],
      correctDifferential: ['Decompensated heart failure'],
      planOptions: ['BNP / NT-proBNP', 'Chest X-ray', 'ECG', 'Echocardiogram', 'Discharge with inhaler'],
      correctPlan: ['BNP / NT-proBNP', 'Chest X-ray', 'ECG', 'Echocardiogram'],
    ),
    OsceStation(
      id: 'osce_warfarin',
      title: 'Warfarin counseling',
      type: OsceType.counseling,
      patientName: 'Mr. Owen, 72',
      doorSign: 'A 72-year-old man is starting warfarin for atrial fibrillation. Counsel him on safe use. He is worried about side effects.',
      openingLine: "My GP said I need a blood thinner — I'm worried about bleeding.",
      conceptIds: ['c_afib', 'c_anticoagulant'],
      affect: 'Concerned',
      difficulty: 3,
      redFlags: ['Signs of major bleeding', 'Missed INR monitoring'],
      beats: [
        OsceBeat(topic: 'Purpose', keywords: ['why', 'purpose', 'for', 'reason', 'stroke'], response: "So it stops clots and strokes? That makes sense.", essential: true, domain: OsceDomain.communication),
        OsceBeat(topic: 'INR monitoring', keywords: ['inr', 'blood test', 'monitor', 'check'], response: "How often will I need the blood tests?", essential: true),
        OsceBeat(topic: 'Bleeding signs', keywords: ['bleed', 'bruise', 'blood', 'stool', 'gums'], response: "What should I look out for?", essential: true, domain: OsceDomain.safety),
        OsceBeat(topic: 'Diet/interactions', keywords: ['food', 'diet', 'greens', 'alcohol', 'interaction', 'other medication'], response: "Does it matter what I eat or drink?", essential: true),
        OsceBeat(topic: 'Missed dose', keywords: ['miss', 'forget', 'dose'], response: "What if I forget a dose?", essential: true),
        OsceBeat(topic: 'Empathy', keywords: ['understand', 'worry', 'reassure', 'normal to'], response: "Thanks, I feel a bit better about it now.", domain: OsceDomain.empathy),
      ],
      differentialOptions: ['Patient understands purpose', 'Patient understands monitoring', 'Patient knows bleeding signs', 'Patient knows interactions'],
      correctDifferential: ['Patient understands purpose', 'Patient understands monitoring', 'Patient knows bleeding signs', 'Patient knows interactions'],
      planOptions: ['Carry an anticoagulation alert card', 'Regular INR testing', 'Report unusual bleeding', 'Avoid sudden big changes in leafy greens'],
      correctPlan: ['Carry an anticoagulation alert card', 'Regular INR testing', 'Report unusual bleeding', 'Avoid sudden big changes in leafy greens'],
    ),
  ];

  static OsceStation? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }
}
