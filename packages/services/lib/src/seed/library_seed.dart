import 'package:synapse_core/synapse_core.dart';

/// The seed Reference Library (prompt 48): Anatomy Atlas, Imaging, Procedures,
/// Guidelines and Journal Club — all Concept-anchored. Educational content.
class LibrarySeed {
  const LibrarySeed._();

  static const List<LibraryEntry> all = [
    // ---- Anatomy & Histology Atlas ----
    LibraryEntry(
      id: 'atlas_heart', kind: LibraryKind.atlas, title: 'The Heart — Chambers & Valves',
      conceptIds: ['c_cardio_root', 'c_chf'], system: BodySystem.cardiovascular,
      subtitle: 'Gross cardiac anatomy', summary: 'Four chambers, four valves, and the coronary circulation — the structural basis of every cardiac sound and lesion.',
      reveals: [
        RevealPoint(label: 'Right atrium', detail: 'Receives deoxygenated blood from the vena cavae and coronary sinus.'),
        RevealPoint(label: 'Mitral valve', detail: 'Bicuspid valve between the left atrium and ventricle; site of MR/MS murmurs.'),
        RevealPoint(label: 'Aortic valve', detail: 'Tricuspid semilunar valve; stenosis causes a crescendo-decrescendo systolic murmur.'),
        RevealPoint(label: 'LAD artery', detail: 'Supplies the anterior wall and septum; occlusion → anterior STEMI (V1–V4).'),
      ],
      bullets: ['Auscultation areas map to valves', 'Coronary territories explain ECG localization'],
    ),
    LibraryEntry(
      id: 'atlas_nephron', kind: LibraryKind.atlas, title: 'The Nephron',
      conceptIds: ['c_nephro_root', 'c_aki'], system: BodySystem.renal,
      subtitle: 'Functional unit of the kidney', summary: 'From glomerulus to collecting duct — where every diuretic and electrolyte disturbance acts.',
      reveals: [
        RevealPoint(label: 'Glomerulus', detail: 'Filtration barrier; damage causes proteinuria/hematuria.'),
        RevealPoint(label: 'Proximal tubule', detail: 'Reabsorbs most filtered Na, glucose, bicarbonate; site of Fanconi syndrome.'),
        RevealPoint(label: 'Thick ascending limb', detail: 'Na-K-2Cl cotransporter — the target of loop diuretics.'),
        RevealPoint(label: 'Distal convoluted tubule', detail: 'Na-Cl cotransporter — the target of thiazides.'),
      ],
      bullets: ['Diuretic sites map to nephron segments'],
    ),
    LibraryEntry(
      id: 'atlas_lung', kind: LibraryKind.atlas, title: 'Bronchial Tree & Lobes',
      conceptIds: ['c_cap'], system: BodySystem.respiratory,
      subtitle: 'Airway and lobar anatomy', summary: 'Lobar anatomy underlies the location of consolidation, effusions and breath sounds.',
      reveals: [
        RevealPoint(label: 'Right middle lobe', detail: 'Common site of aspiration in upright patients is actually the RLL; RML syndrome causes recurrent infection.'),
        RevealPoint(label: 'Carina', detail: 'Bifurcation at ~T4–5; sensitive cough reflex; ETT should sit above it.'),
      ],
    ),

    // ---- Imaging & Radiology ----
    LibraryEntry(
      id: 'img_cxr_pna', kind: LibraryKind.imaging, title: 'Chest X-ray — Lobar Pneumonia',
      conceptIds: ['c_cap'], relatedDiseaseIds: ['d_cap'], system: BodySystem.respiratory,
      subtitle: 'PA chest radiograph', summary: 'A reveal-on-tap teaching film of right-lower-lobe consolidation with air bronchograms.',
      reveals: [
        RevealPoint(label: 'Consolidation', detail: 'Homogeneous opacity confined to a lobe; suggests bacterial pneumonia.'),
        RevealPoint(label: 'Air bronchogram', detail: 'Air-filled bronchi outlined by surrounding alveolar fluid — confirms airspace disease.'),
        RevealPoint(label: 'Silhouette sign', detail: 'Loss of a normal border localizes the lobe involved.'),
      ],
      bullets: ['Compare with normal vs abnormal', 'Correlate with crackles on exam'],
    ),
    LibraryEntry(
      id: 'img_ct_stroke', kind: LibraryKind.imaging, title: 'CT Head — Early Ischemic Stroke',
      conceptIds: ['c_stroke'], relatedDiseaseIds: ['d_stroke'], system: BodySystem.neurology,
      subtitle: 'Non-contrast CT', summary: 'Why we image first: distinguishing ischemia from hemorrhage before thrombolysis.',
      reveals: [
        RevealPoint(label: 'Hyperdense MCA sign', detail: 'Bright clot within the middle cerebral artery — early occlusion marker.'),
        RevealPoint(label: 'Loss of grey-white differentiation', detail: 'Early ischemic change; subtle in the first hours.'),
        RevealPoint(label: 'No hemorrhage', detail: 'Absence of blood is what permits thrombolysis.'),
      ],
      bullets: ['CT excludes bleed before tPA'],
    ),
    LibraryEntry(
      id: 'img_cxr_chf', kind: LibraryKind.imaging, title: 'Chest X-ray — Heart Failure',
      conceptIds: ['c_chf'], relatedDiseaseIds: ['d_chf'], system: BodySystem.cardiovascular,
      subtitle: 'Findings of pulmonary congestion', summary: 'The ABCDE of cardiogenic pulmonary edema on plain film.',
      reveals: [
        RevealPoint(label: 'Cardiomegaly', detail: 'Cardiothoracic ratio > 0.5 on a PA film.'),
        RevealPoint(label: 'Kerley B lines', detail: 'Short horizontal peripheral lines of interstitial edema.'),
        RevealPoint(label: 'Cephalization', detail: 'Upper-lobe vascular redistribution from raised venous pressure.'),
        RevealPoint(label: 'Pleural effusions', detail: 'Often bilateral; blunt the costophrenic angles.'),
      ],
    ),

    // ---- Procedures & Clinical Skills ----
    LibraryEntry(
      id: 'proc_lp', kind: LibraryKind.procedure, title: 'Lumbar Puncture',
      conceptIds: ['c_stroke'], system: BodySystem.neurology,
      subtitle: 'CSF sampling', summary: 'Step-by-step LP with safety checks; analyze opening pressure, cell count, glucose and protein.',
      indications: ['Suspected meningitis', 'Subarachnoid hemorrhage (CT-negative)', 'Therapeutic CSF removal'],
      contraindications: ['↑ICP with mass effect', 'Coagulopathy', 'Infection at the site'],
      steps: [
        LibraryStep(title: 'Position & consent', detail: 'Lateral decubitus or sitting; obtain informed consent.'),
        LibraryStep(title: 'Identify L3–L4/L4–L5', detail: 'At or below the iliac crest line to avoid the conus.', caution: 'Never above L2 in adults.'),
        LibraryStep(title: 'Sterile prep & local anesthetic', detail: 'Full aseptic technique.'),
        LibraryStep(title: 'Insert spinal needle, bevel up', detail: 'Advance to a "give" through ligamentum flavum/dura.'),
        LibraryStep(title: 'Measure opening pressure', detail: 'Use a manometer before collecting tubes.'),
        LibraryStep(title: 'Collect & send', detail: 'Cell count, glucose, protein, Gram stain/culture.'),
      ],
      bullets: ['Always image first if ↑ICP suspected'],
    ),
    LibraryEntry(
      id: 'proc_intubation', kind: LibraryKind.procedure, title: 'Endotracheal Intubation',
      conceptIds: ['c_copd', 'c_sepsis'], system: BodySystem.respiratory,
      subtitle: 'Airway management', summary: 'Rapid-sequence intubation checklist; confirm with capnography and bilateral breath sounds.',
      indications: ['Airway protection', 'Respiratory failure', 'Anticipated deterioration'],
      contraindications: ['Relative: difficult-airway predictors — prepare adjuncts'],
      steps: [
        LibraryStep(title: 'Prepare (SOAP-ME)', detail: 'Suction, oxygen, airways, pharmacology, monitoring, ETT/equipment.'),
        LibraryStep(title: 'Pre-oxygenate', detail: '3 minutes of 100% O₂ or 8 vital-capacity breaths.'),
        LibraryStep(title: 'Induction + paralysis', detail: 'Sedative (e.g. etomidate) then paralytic (e.g. rocuronium).'),
        LibraryStep(title: 'Laryngoscopy & tube', detail: 'Visualize cords, pass the tube, inflate the cuff.'),
        LibraryStep(title: 'Confirm placement', detail: 'End-tidal CO₂, bilateral breath sounds, chest rise.', caution: 'No EtCO₂ = assume esophageal.'),
      ],
      bullets: ['Capnography is the gold standard for confirmation'],
    ),
    LibraryEntry(
      id: 'proc_abg', kind: LibraryKind.procedure, title: 'Arterial Blood Gas',
      conceptIds: ['c_acidosis', 'c_copd'], system: BodySystem.respiratory,
      subtitle: 'Radial artery sampling', summary: 'Sample technique and a stepwise approach to interpreting acid-base status.',
      indications: ['Respiratory failure', 'Acid-base disturbance', 'Shock'],
      contraindications: ['Abnormal Allen test', 'Local infection', 'AV fistula in the limb'],
      steps: [
        LibraryStep(title: 'Allen test', detail: 'Confirm collateral ulnar flow before radial puncture.'),
        LibraryStep(title: 'Puncture at 45°', detail: 'Pulsatile bright-red flashback confirms arterial sampling.'),
        LibraryStep(title: 'Hold pressure 5 min', detail: 'Longer if anticoagulated.'),
        LibraryStep(title: 'Interpret', detail: 'pH → primary disorder → compensation → anion gap.'),
      ],
    ),

    // ---- Guidelines & Protocols ----
    LibraryEntry(
      id: 'guide_acs', kind: LibraryKind.guideline, title: 'Acute Coronary Syndrome — Management',
      conceptIds: ['c_stemi', 'c_chest_pain'], relatedDiseaseIds: ['d_stemi'], relatedDrugIds: ['drug_aspirin', 'drug_atorvastatin'],
      system: BodySystem.cardiovascular, year: 2023,
      subtitle: 'ESC 2023 summary', summary: 'A versioned, citable summary of reperfusion timing and antithrombotic therapy in ACS.',
      body: [
        'STEMI: primary PCI within 90 minutes of first medical contact is preferred; fibrinolysis if PCI is not available within 120 minutes.',
        'All patients: dual antiplatelet therapy, anticoagulation, and high-intensity statin.',
        'NSTE-ACS: risk-stratify (GRACE) to determine invasive timing.',
      ],
      bullets: ['Door-to-balloon < 90 min', 'High-intensity statin for all', 'Time is muscle'],
      evidence: Evidence(citations: [Citation(title: '2023 ESC Guidelines for ACS', source: 'European Heart Journal', year: 2023, type: CitationType.guideline)], levelOfEvidence: LevelOfEvidence.a),
      review: ReviewState(status: ReviewStatus.approved, reviewerName: 'Cardiology board'),
    ),
    LibraryEntry(
      id: 'guide_sepsis', kind: LibraryKind.guideline, title: 'Surviving Sepsis — Hour-1 Bundle',
      conceptIds: ['c_sepsis'], relatedDiseaseIds: ['d_sepsis'], system: BodySystem.infectious, year: 2021,
      subtitle: 'SSC 2021 summary', summary: 'The time-critical first-hour interventions in sepsis and septic shock.',
      body: [
        'Measure lactate; remeasure if initially elevated.',
        'Obtain blood cultures before antibiotics.',
        'Administer broad-spectrum antibiotics.',
        'Begin 30 mL/kg crystalloid for hypotension or lactate ≥ 4.',
        'Start vasopressors if hypotensive during/after fluids to keep MAP ≥ 65.',
      ],
      bullets: ['Antibiotics within 1 hour', 'Norepinephrine first-line pressor'],
      evidence: Evidence(citations: [Citation(title: 'Surviving Sepsis Campaign 2021', source: 'Critical Care Medicine', year: 2021, type: CitationType.guideline)], levelOfEvidence: LevelOfEvidence.a),
    ),

    // ---- Journal Club ----
    LibraryEntry(
      id: 'jc_isis2', kind: LibraryKind.journal, title: 'ISIS-2 — Aspirin in Acute MI',
      conceptIds: ['c_stemi', 'c_antiplatelet'], relatedDrugIds: ['drug_aspirin'], system: BodySystem.cardiovascular, year: 1988,
      subtitle: 'Landmark RCT', summary: 'Aspirin and streptokinase each independently reduced vascular mortality after MI — and together more so.',
      body: [
        'Design: 2×2 factorial RCT of >17,000 patients with suspected acute MI.',
        'Result: aspirin reduced 5-week vascular mortality by ~23%; the combination with streptokinase was additive.',
        'Impact: established aspirin as a cornerstone of acute MI therapy.',
      ],
      bullets: ['Foundational evidence for aspirin in ACS'],
      evidence: Evidence(citations: [Citation(title: 'ISIS-2', source: 'The Lancet', year: 1988, type: CitationType.rct)], levelOfEvidence: LevelOfEvidence.a),
    ),
    LibraryEntry(
      id: 'jc_ninds', kind: LibraryKind.journal, title: 'NINDS — tPA for Ischemic Stroke',
      conceptIds: ['c_stroke'], relatedDiseaseIds: ['d_stroke'], system: BodySystem.neurology, year: 1995,
      subtitle: 'Landmark RCT', summary: 'IV alteplase within 3 hours improved functional outcome at 90 days despite increased early hemorrhage.',
      body: [
        'Design: RCT of IV tPA vs placebo within 3 hours of ischemic stroke onset.',
        'Result: more patients achieved minimal/no disability at 3 months; symptomatic ICH increased but mortality was unchanged.',
        'Impact: launched thrombolysis as standard stroke care and the "time is brain" era.',
      ],
      bullets: ['Basis for the thrombolysis time window'],
      evidence: Evidence(citations: [Citation(title: 'NINDS rt-PA Stroke Study', source: 'NEJM', year: 1995, type: CitationType.rct)], levelOfEvidence: LevelOfEvidence.a),
    ),
  ];

  static LibraryEntry? byId(String id) {
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  static List<LibraryEntry> ofKind(LibraryKind kind) =>
      all.where((e) => e.kind == kind).toList();
}
