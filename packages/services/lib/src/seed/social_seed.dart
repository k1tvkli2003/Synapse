import 'package:synapse_core/synapse_core.dart';

/// Seed for Rounds (audio feed), Study Buddies and OR Lab.
class SocialSeed {
  const SocialSeed._();

  static List<Round> rounds = [
    Round(id: 'r1', title: 'A pearl on reading ST elevation', authorName: 'Dr. Amaro', authorHandle: 'amaro', durationSec: 48, tags: ['cardiology', 'ecg'], conceptIds: const ['c_stemi'], likes: 124, commentCount: 9, transcript: 'Quick pearl: always look for reciprocal changes to confirm a true STEMI…', createdAt: DateTime(2026, 1, 12)),
    Round(id: 'r2', title: 'How I memorise the brachial plexus', authorName: 'Maya', authorHandle: 'maya_m2', durationSec: 72, tags: ['anatomy'], likes: 89, commentCount: 5, transcript: 'Randy Travis Drinks Cold Beer — Roots, Trunks, Divisions, Cords, Branches…', createdAt: DateTime(2026, 1, 18)),
    Round(id: 'r3', title: 'Hyperkalemia at 3am', authorName: 'ICU Nurse', authorHandle: 'night_rn', durationSec: 95, tags: ['emergency', 'electrolytes'], conceptIds: const ['c_hyperkalemia'], likes: 203, commentCount: 14, transcript: 'When the monitor shows peaked Ts, reach for calcium first…', createdAt: DateTime(2026, 2, 2)),
    Round(id: 'r4', title: 'My approach to the anion gap', authorName: 'Sara N.', authorHandle: 'saran', durationSec: 60, tags: ['nephrology'], conceptIds: const ['c_anion_gap'], likes: 67, commentCount: 3, transcript: 'MUDPILES is the classic, but start by confirming the gap is real…', createdAt: DateTime(2026, 2, 9)),
    Round(id: 'r5', title: 'Auscultation that changed my Dx', authorName: 'Dev', authorHandle: 'dev_resident', durationSec: 80, tags: ['cardiology', 'sounds'], conceptIds: const ['c_systolic_murmur'], likes: 142, commentCount: 8, transcript: 'A new holosystolic murmur post-MI made me think papillary rupture…', createdAt: DateTime(2026, 2, 15)),
  ];

  static const List<BuddyProfile> buddies = [
    BuddyProfile(userId: 'u_maya', name: 'Maya R.', role: UserRole.student, specialty: 'Pre-clinical', year: 2, goals: ['USMLE Step 1', 'Anatomy'], availability: ['Mon eve', 'Wed eve', 'Weekends'], bio: 'M2 grinding for Step 1. Love flashcards and quizzing partners.', matchScore: 92),
    BuddyProfile(userId: 'u_dev', name: 'Dev P.', role: UserRole.resident, specialty: 'Internal Medicine', year: 1, goals: ['ECG mastery', 'Cases'], availability: ['Tue eve', 'Thu eve'], bio: 'IM intern. Happy to teach ECGs in exchange for pharmacology drilling.', matchScore: 84),
    BuddyProfile(userId: 'u_sara', name: 'Sara N.', role: UserRole.nurse, specialty: 'Critical Care', goals: ['Lab interpretation', 'Sounds'], availability: ['Weekends'], bio: 'ICU RN. Strong on electrolytes and acid-base.', matchScore: 78),
    BuddyProfile(userId: 'u_leo', name: 'Leo K.', role: UserRole.student, specialty: 'Clinical', year: 3, goals: ['OSCE', 'Cases'], availability: ['Mon eve', 'Fri eve'], bio: 'MS3 prepping for OSCEs. Looking for case-discussion partners.', matchScore: 71),
    BuddyProfile(userId: 'u_amara', name: 'Amara O.', role: UserRole.clinician, specialty: 'Family Medicine', goals: ['Guidelines', 'Calculators'], availability: ['Wed eve'], bio: 'FM attending brushing up on the latest guidelines.', matchScore: 64),
  ];

  static const List<AudioDrama> dramas = [
    AudioDrama(
      id: 'or_appy',
      title: 'Laparoscopic Appendectomy',
      surgery: 'General Surgery',
      durationSec: 240,
      conceptIds: ['c_infection'],
      transcript: 'Scrubbed in. We begin with port placement at the umbilicus…',
      cues: [
        TimelineCue(atSec: 8, kind: CueKind.step, label: 'Time-out', detail: 'Confirm patient, procedure, site.'),
        TimelineCue(atSec: 30, kind: CueKind.instrument, label: 'Veress needle', detail: 'Establish pneumoperitoneum.'),
        TimelineCue(atSec: 60, kind: CueKind.keyTerm, label: 'Pneumoperitoneum', detail: 'CO₂ insufflation of the abdomen.'),
        TimelineCue(atSec: 110, kind: CueKind.instrument, label: 'Harmonic scalpel', detail: 'Divide the mesoappendix.'),
        TimelineCue(atSec: 160, kind: CueKind.step, label: 'Ligate the base', detail: 'Endoloop the appendiceal base.'),
        TimelineCue(atSec: 210, kind: CueKind.keyTerm, label: 'Specimen retrieval', detail: 'Remove in an endobag to avoid contamination.'),
      ],
    ),
    AudioDrama(
      id: 'or_chole',
      title: 'Laparoscopic Cholecystectomy',
      surgery: 'General Surgery',
      durationSec: 300,
      transcript: 'We aim for the critical view of safety before clipping anything…',
      cues: [
        TimelineCue(atSec: 20, kind: CueKind.keyTerm, label: 'Calot\'s triangle', detail: 'Cystic duct, common hepatic duct, inferior liver edge.'),
        TimelineCue(atSec: 75, kind: CueKind.keyTerm, label: 'Critical view of safety', detail: 'Two structures entering the gallbladder, cleared hepatocystic triangle.'),
        TimelineCue(atSec: 140, kind: CueKind.instrument, label: 'Clip applier', detail: 'Clip and divide the cystic artery and duct.'),
        TimelineCue(atSec: 220, kind: CueKind.step, label: 'Dissect off the liver bed', detail: 'Stay in the right plane to avoid bleeding.'),
      ],
    ),
  ];
}
