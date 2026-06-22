import 'package:synapse_core/synapse_core.dart';

/// The seed knowledge graph (prompt 33). Every learnable item across modules
/// anchors to one of these concepts, which is what powers cross-module
/// "see also" and weak-concept propagation. Lab-engine concept ids are included
/// so its interpretations resolve.
class ConceptsSeed {
  const ConceptsSeed._();

  static const List<Concept> all = [
    // Cardiology
    Concept(id: 'c_hyperkalemia', name: 'Hyperkalemia', aliases: ['high potassium', 'high K'], domain: ConceptDomain.lab, summary: 'Serum potassium > 5.0 mmol/L; causes peaked T waves and can progress to a sine-wave rhythm and arrest.', links: [ConceptLink(to: 'c_ecg_hyperk', relation: ConceptRelation.causes), ConceptLink(to: 'c_potassium', relation: ConceptRelation.related)]),
    Concept(id: 'c_ecg_hyperk', name: 'Peaked T waves', aliases: ['hyperkalemia ECG'], domain: ConceptDomain.cardiology, summary: 'Tall, narrow, symmetric T waves — the earliest ECG sign of hyperkalemia.', links: [ConceptLink(to: 'c_hyperkalemia', relation: ConceptRelation.related)]),
    Concept(id: 'c_potassium', name: 'Potassium', aliases: ['K+'], domain: ConceptDomain.lab, summary: 'The major intracellular cation; tightly regulated because of its effect on cardiac membrane potential.'),
    Concept(id: 'c_hypokalemia', name: 'Hypokalemia', aliases: ['low potassium'], domain: ConceptDomain.lab, summary: 'Serum potassium < 3.5 mmol/L; causes U waves, weakness and arrhythmia.'),
    Concept(id: 'c_stemi', name: 'STEMI', aliases: ['ST elevation MI', 'heart attack'], domain: ConceptDomain.cardiology, summary: 'ST-segment elevation myocardial infarction — acute coronary occlusion; time-critical reperfusion.', links: [ConceptLink(to: 'c_chest_pain', relation: ConceptRelation.causes)]),
    Concept(id: 'c_afib', name: 'Atrial fibrillation', aliases: ['AF', 'a-fib'], domain: ConceptDomain.cardiology, summary: 'Irregularly irregular rhythm with no discernible P waves; stroke and rate-control implications.'),
    Concept(id: 'c_vtach', name: 'Ventricular tachycardia', aliases: ['VT', 'V-tach'], domain: ConceptDomain.cardiology, summary: 'Wide-complex tachycardia originating below the AV node; may be pulseless.'),
    Concept(id: 'c_bradycardia', name: 'Bradycardia', aliases: ['slow heart rate'], domain: ConceptDomain.cardiology, summary: 'Heart rate < 60 bpm; symptomatic bradycardia needs atropine or pacing.'),
    Concept(id: 'c_chest_pain', name: 'Chest pain', aliases: ['angina'], domain: ConceptDomain.clinical, summary: 'A cardinal symptom whose differential spans cardiac, pulmonary, GI and musculoskeletal causes.'),

    // Labs / metabolic
    Concept(id: 'c_anemia', name: 'Anemia', aliases: ['low hemoglobin'], domain: ConceptDomain.lab, summary: 'Reduced hemoglobin; classified by MCV into micro-, normo- and macrocytic.', links: [ConceptLink(to: 'c_micro_anemia', relation: ConceptRelation.isA), ConceptLink(to: 'c_macro_anemia', relation: ConceptRelation.isA)]),
    Concept(id: 'c_micro_anemia', name: 'Microcytic anemia', aliases: ['MCV < 80'], domain: ConceptDomain.lab, summary: 'Iron deficiency, thalassemia, chronic disease, sideroblastic.'),
    Concept(id: 'c_macro_anemia', name: 'Macrocytic anemia', aliases: ['MCV > 100'], domain: ConceptDomain.lab, summary: 'B12/folate deficiency, alcohol, hypothyroidism, MDS.'),
    Concept(id: 'c_wbc', name: 'White blood cells', aliases: ['WBC', 'leukocytes'], domain: ConceptDomain.lab, summary: 'Immune effector cells; elevation suggests infection/inflammation.'),
    Concept(id: 'c_infection', name: 'Infection', domain: ConceptDomain.clinical, summary: 'Host invasion by pathogens; leukocytosis with a left shift is a classic clue.'),
    Concept(id: 'c_thrombocytopenia', name: 'Thrombocytopenia', aliases: ['low platelets'], domain: ConceptDomain.lab, summary: 'Platelets < 150; bleeding risk rises sharply below 20.'),
    Concept(id: 'c_acidosis', name: 'Metabolic acidosis', domain: ConceptDomain.lab, summary: 'Low bicarbonate; classified by the anion gap.', links: [ConceptLink(to: 'c_anion_gap', relation: ConceptRelation.related)]),
    Concept(id: 'c_anion_gap', name: 'Anion gap', aliases: ['AG'], domain: ConceptDomain.lab, summary: 'Na − (Cl + HCO3); >12 suggests added acid (MUDPILES).'),
    Concept(id: 'c_hyponatremia', name: 'Hyponatremia', aliases: ['low sodium'], domain: ConceptDomain.lab, summary: 'Sodium < 135; correct slowly to avoid osmotic demyelination.'),
    Concept(id: 'c_hypernatremia', name: 'Hypernatremia', aliases: ['high sodium'], domain: ConceptDomain.lab, summary: 'Sodium > 145; usually a free-water deficit.'),
    Concept(id: 'c_aki', name: 'Acute kidney injury', aliases: ['AKI', 'renal failure'], domain: ConceptDomain.clinical, summary: 'Abrupt rise in creatinine; pre-renal, intrinsic or post-renal.'),
    Concept(id: 'c_hyperglycemia', name: 'Hyperglycemia', aliases: ['high glucose'], domain: ConceptDomain.lab, summary: 'Elevated blood glucose; if marked, evaluate for DKA/HHS.', links: [ConceptLink(to: 'c_dka', relation: ConceptRelation.causes)]),
    Concept(id: 'c_dka', name: 'Diabetic ketoacidosis', aliases: ['DKA'], domain: ConceptDomain.clinical, summary: 'Hyperglycemia + ketosis + high-anion-gap acidosis.'),
    Concept(id: 'c_calcium', name: 'Calcium', domain: ConceptDomain.lab, summary: 'Regulated by PTH and vitamin D; abnormalities affect neuromuscular excitability.'),
    Concept(id: 'c_electrolytes', name: 'Electrolytes', domain: ConceptDomain.lab, summary: 'Na, K, Cl, HCO3 — the BMP backbone.'),
    Concept(id: 'c_hepatocellular', name: 'Hepatocellular injury', domain: ConceptDomain.lab, summary: 'AST/ALT-predominant LFT rise from hepatocyte damage.'),
    Concept(id: 'c_cholestasis', name: 'Cholestasis', domain: ConceptDomain.lab, summary: 'ALP-predominant pattern from impaired bile flow.'),
    Concept(id: 'c_jaundice', name: 'Jaundice', aliases: ['hyperbilirubinemia'], domain: ConceptDomain.clinical, summary: 'Yellowing from bilirubin > ~2.5–3 mg/dL.'),
    Concept(id: 'c_alcoholic_hep', name: 'Alcoholic hepatitis', domain: ConceptDomain.clinical, summary: 'AST/ALT ratio ≥ 2 is the classic clue.'),
    Concept(id: 'c_synthetic_liver', name: 'Hepatic synthetic function', domain: ConceptDomain.lab, summary: 'Albumin and INR reflect the liver\'s synthetic capacity.'),

    // Pharmacology / micro (Arena)
    Concept(id: 'c_beta_lactam', name: 'Beta-lactams', aliases: ['penicillins', 'cephalosporins'], domain: ConceptDomain.pharmacology, summary: 'Inhibit cell-wall synthesis by binding penicillin-binding proteins.'),
    Concept(id: 'c_mrsa', name: 'MRSA', aliases: ['methicillin-resistant S. aureus'], domain: ConceptDomain.microbiology, summary: 'Gram-positive resistant to beta-lactams; treat with vancomycin/linezolid.'),
    Concept(id: 'c_pseudomonas', name: 'Pseudomonas aeruginosa', domain: ConceptDomain.microbiology, summary: 'Gram-negative; needs anti-pseudomonal coverage (pip-tazo, cefepime).'),
    Concept(id: 'c_gram_stain', name: 'Gram stain', domain: ConceptDomain.microbiology, summary: 'Separates bacteria into gram-positive (purple) and gram-negative (pink).'),

    // Anatomy / roots
    Concept(id: 'c_cardio_root', name: 'Cardi/o', aliases: ['heart root'], domain: ConceptDomain.roots, summary: 'Greek root meaning heart (e.g. cardiology, myocarditis).'),
    Concept(id: 'c_hepato_root', name: 'Hepat/o', aliases: ['liver root'], domain: ConceptDomain.roots, summary: 'Greek root meaning liver (e.g. hepatitis, hepatomegaly).'),
    Concept(id: 'c_nephro_root', name: 'Nephr/o', aliases: ['kidney root'], domain: ConceptDomain.roots, summary: 'Greek root meaning kidney (e.g. nephropathy, nephrology).'),

    // Auscultation
    Concept(id: 'c_s3', name: 'S3 gallop', domain: ConceptDomain.sound, summary: 'Low-pitched early-diastolic sound; volume overload / heart failure.'),
    Concept(id: 'c_systolic_murmur', name: 'Systolic murmur', domain: ConceptDomain.sound, summary: 'Murmur between S1 and S2; AS, MR, VSD, flow.'),
    Concept(id: 'c_wheeze', name: 'Wheeze', domain: ConceptDomain.sound, summary: 'High-pitched expiratory sound of airway narrowing (asthma/COPD).'),
    Concept(id: 'c_crackles', name: 'Crackles', aliases: ['rales'], domain: ConceptDomain.sound, summary: 'Discontinuous popping sounds; pulmonary edema or fibrosis.'),

    // Cross-cutting
    Concept(id: 'c_anaphylaxis', name: 'Anaphylaxis', domain: ConceptDomain.clinical, summary: 'Life-threatening type-I hypersensitivity; IM epinephrine is first-line.'),
    Concept(id: 'c_sepsis', name: 'Sepsis', domain: ConceptDomain.clinical, summary: 'Life-threatening organ dysfunction from a dysregulated host response to infection.'),
  ];

  static Concept? byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }
}
