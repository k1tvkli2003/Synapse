import 'package:synapse_core/synapse_core.dart';

/// The seed clinical calculators & scores (prompt 47). Defined as data: additive
/// scores use `formulaKey: 'sum'`; formulas dispatch on a named key in the
/// calculator engine. All offline + deterministic + unit-tested.
class ToolsSeed {
  const ToolsSeed._();

  static const _green = 0xFF7BE0A3;
  static const _yellow = 0xFFFFC773;
  static const _orange = 0xFFFFB07A;
  static const _red = 0xFFFF8A8A;

  static const List<ClinicalTool> all = [
    ClinicalTool(
      id: 'tool_bmi', name: 'Body Mass Index (BMI)', category: ToolCategory.formula, formulaKey: 'bmi',
      description: 'Weight-for-height index screening for under/overweight.', specialty: 'General', outputUnit: 'kg/m²',
      inputs: [
        ToolInput(key: 'weight', label: 'Weight', unit: 'kg', min: 1, max: 400),
        ToolInput(key: 'height', label: 'Height', unit: 'cm', min: 30, max: 250),
      ],
      bands: [
        OutputBand(min: 0, max: 18.49, label: 'Underweight', interpretation: 'BMI below 18.5', colorHex: _yellow),
        OutputBand(min: 18.5, max: 24.99, label: 'Normal', interpretation: 'Healthy weight range', colorHex: _green),
        OutputBand(min: 25, max: 29.99, label: 'Overweight', interpretation: 'BMI 25–29.9', colorHex: _orange),
        OutputBand(min: 30, max: 100, label: 'Obese', interpretation: 'BMI ≥ 30', colorHex: _red),
      ],
    ),
    ClinicalTool(
      id: 'tool_bsa', name: 'Body Surface Area (Mosteller)', category: ToolCategory.formula, formulaKey: 'bsa',
      description: 'BSA for drug and fluid dosing.', specialty: 'General', outputUnit: 'm²',
      inputs: [
        ToolInput(key: 'weight', label: 'Weight', unit: 'kg', min: 1, max: 400),
        ToolInput(key: 'height', label: 'Height', unit: 'cm', min: 30, max: 250),
      ],
    ),
    ClinicalTool(
      id: 'tool_gfr', name: 'eGFR (CKD-EPI 2021)', category: ToolCategory.formula, formulaKey: 'gfr_ckdepi',
      conceptIds: ['c_aki'], relatedDiseaseIds: ['d_aki'], description: 'Estimated GFR (race-free) for CKD staging.', specialty: 'Nephrology', outputUnit: 'mL/min/1.73m²',
      inputs: [
        ToolInput(key: 'creatinine', label: 'Serum creatinine', unit: 'mg/dL', min: 0.1, max: 20),
        ToolInput(key: 'age', label: 'Age', unit: 'years', min: 18, max: 120),
        ToolInput(key: 'sex', label: 'Sex', type: ToolInputType.select, options: [ToolOption(label: 'Male', value: 0), ToolOption(label: 'Female', value: 1)]),
      ],
      bands: [
        OutputBand(min: 90, max: 1000, label: 'G1 — Normal', interpretation: '≥90', colorHex: _green),
        OutputBand(min: 60, max: 89.99, label: 'G2 — Mild', interpretation: '60–89', colorHex: _green),
        OutputBand(min: 45, max: 59.99, label: 'G3a — Mild–moderate', interpretation: '45–59', colorHex: _yellow),
        OutputBand(min: 30, max: 44.99, label: 'G3b — Moderate–severe', interpretation: '30–44', colorHex: _orange),
        OutputBand(min: 15, max: 29.99, label: 'G4 — Severe', interpretation: '15–29', colorHex: _red),
        OutputBand(min: 0, max: 14.99, label: 'G5 — Kidney failure', interpretation: '<15', colorHex: _red),
      ],
    ),
    ClinicalTool(
      id: 'tool_map', name: 'Mean Arterial Pressure', category: ToolCategory.formula, formulaKey: 'map',
      description: 'Average perfusion pressure; target ≥65 in shock.', specialty: 'Critical care', outputUnit: 'mmHg',
      inputs: [
        ToolInput(key: 'sbp', label: 'Systolic BP', unit: 'mmHg', min: 40, max: 300),
        ToolInput(key: 'dbp', label: 'Diastolic BP', unit: 'mmHg', min: 20, max: 200),
      ],
      bands: [
        OutputBand(min: 0, max: 64.99, label: 'Low', interpretation: 'Below the usual ≥65 perfusion target', colorHex: _red),
        OutputBand(min: 65, max: 110, label: 'Adequate', interpretation: 'Typical perfusion range', colorHex: _green),
        OutputBand(min: 110.01, max: 400, label: 'High', interpretation: 'Elevated', colorHex: _orange),
      ],
    ),
    ClinicalTool(
      id: 'tool_anion_gap', name: 'Anion Gap', category: ToolCategory.formula, formulaKey: 'anion_gap',
      conceptIds: ['c_anion_gap', 'c_acidosis'], description: 'Na − (Cl + HCO₃); >12 suggests added acid.', specialty: 'Nephrology', outputUnit: 'mmol/L',
      inputs: [
        ToolInput(key: 'na', label: 'Sodium', unit: 'mmol/L', min: 100, max: 180),
        ToolInput(key: 'cl', label: 'Chloride', unit: 'mmol/L', min: 70, max: 130),
        ToolInput(key: 'hco3', label: 'Bicarbonate', unit: 'mmol/L', min: 2, max: 50),
      ],
      bands: [
        OutputBand(min: -50, max: 12, label: 'Normal', interpretation: 'Anion gap ≤ 12', colorHex: _green),
        OutputBand(min: 12.01, max: 100, label: 'High anion gap', interpretation: 'Consider MUDPILES', colorHex: _red),
      ],
    ),
    ClinicalTool(
      id: 'tool_corr_ca', name: 'Corrected Calcium', category: ToolCategory.formula, formulaKey: 'corrected_ca',
      conceptIds: ['c_calcium'], description: 'Adjusts total calcium for albumin.', specialty: 'General', outputUnit: 'mg/dL',
      inputs: [
        ToolInput(key: 'ca', label: 'Measured calcium', unit: 'mg/dL', min: 4, max: 18),
        ToolInput(key: 'albumin', label: 'Albumin', unit: 'g/dL', min: 1, max: 6, defaultValue: 4),
      ],
      bands: [
        OutputBand(min: 0, max: 8.49, label: 'Low', interpretation: 'Hypocalcemia', colorHex: _orange),
        OutputBand(min: 8.5, max: 10.5, label: 'Normal', interpretation: 'Normal range', colorHex: _green),
        OutputBand(min: 10.51, max: 30, label: 'High', interpretation: 'Hypercalcemia', colorHex: _red),
      ],
    ),
    ClinicalTool(
      id: 'tool_corr_na', name: 'Corrected Sodium (hyperglycemia)', category: ToolCategory.formula, formulaKey: 'corrected_na',
      conceptIds: ['c_hyponatremia', 'c_hyperglycemia'], description: 'Corrects sodium for glucose.', specialty: 'Endocrine', outputUnit: 'mmol/L',
      inputs: [
        ToolInput(key: 'na', label: 'Measured sodium', unit: 'mmol/L', min: 100, max: 180),
        ToolInput(key: 'glucose', label: 'Glucose', unit: 'mg/dL', min: 40, max: 1500),
      ],
    ),
    ClinicalTool(
      id: 'tool_meld', name: 'MELD Score', category: ToolCategory.formula, formulaKey: 'meld',
      conceptIds: ['c_cirrhosis'], relatedDiseaseIds: ['d_cirrhosis'], description: 'Predicts mortality in liver disease.', specialty: 'Hepatology',
      inputs: [
        ToolInput(key: 'creatinine', label: 'Creatinine', unit: 'mg/dL', min: 0.1, max: 20),
        ToolInput(key: 'bilirubin', label: 'Bilirubin', unit: 'mg/dL', min: 0.1, max: 60),
        ToolInput(key: 'inr', label: 'INR', min: 0.5, max: 20),
      ],
      bands: [
        OutputBand(min: 0, max: 9.99, label: 'Low', interpretation: '~2% 3-month mortality', colorHex: _green),
        OutputBand(min: 10, max: 19.99, label: 'Moderate', interpretation: 'Rising mortality', colorHex: _yellow),
        OutputBand(min: 20, max: 29.99, label: 'High', interpretation: 'Significant mortality', colorHex: _orange),
        OutputBand(min: 30, max: 100, label: 'Very high', interpretation: '>50% 3-month mortality', colorHex: _red),
      ],
    ),
    ClinicalTool(
      id: 'tool_chadsvasc', name: 'CHA₂DS₂-VASc', category: ToolCategory.score, formulaKey: 'sum',
      conceptIds: ['c_afib'], relatedDiseaseIds: ['d_afib'], relatedDrugIds: ['drug_apixaban', 'drug_warfarin'],
      description: 'Stroke risk in atrial fibrillation → guides anticoagulation.', specialty: 'Cardiology',
      inputs: [
        ToolInput(key: 'chf', label: 'Congestive heart failure', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'htn', label: 'Hypertension', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'age', label: 'Age', type: ToolInputType.select, options: [ToolOption(label: '< 65', value: 0, points: 0), ToolOption(label: '65–74', value: 1, points: 1), ToolOption(label: '≥ 75', value: 2, points: 2)]),
        ToolInput(key: 'dm', label: 'Diabetes', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'stroke', label: 'Prior stroke / TIA / thromboembolism', type: ToolInputType.boolean, points: 2),
        ToolInput(key: 'vascular', label: 'Vascular disease', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'sex', label: 'Sex', type: ToolInputType.select, options: [ToolOption(label: 'Male', value: 0, points: 0), ToolOption(label: 'Female', value: 1, points: 1)]),
      ],
      bands: [
        OutputBand(min: 0, max: 0, label: 'Low', interpretation: 'No anticoagulation generally needed', colorHex: _green),
        OutputBand(min: 1, max: 1, label: 'Intermediate', interpretation: 'Consider anticoagulation', colorHex: _yellow),
        OutputBand(min: 2, max: 9, label: 'High', interpretation: 'Anticoagulation recommended', colorHex: _red),
      ],
    ),
    ClinicalTool(
      id: 'tool_hasbled', name: 'HAS-BLED', category: ToolCategory.score, formulaKey: 'sum',
      conceptIds: ['c_afib'], description: 'Bleeding risk on anticoagulation.', specialty: 'Cardiology',
      inputs: [
        ToolInput(key: 'htn', label: 'Uncontrolled hypertension', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'renal', label: 'Abnormal renal function', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'liver', label: 'Abnormal liver function', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'stroke', label: 'Prior stroke', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'bleeding', label: 'Bleeding history/predisposition', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'inr', label: 'Labile INR', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'elderly', label: 'Age > 65', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'drugs', label: 'Drugs (antiplatelet/NSAID)', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'alcohol', label: 'Alcohol ≥ 8/week', type: ToolInputType.boolean, points: 1),
      ],
      bands: [
        OutputBand(min: 0, max: 2, label: 'Low risk', interpretation: 'Bleeding risk relatively low', colorHex: _green),
        OutputBand(min: 3, max: 9, label: 'High risk', interpretation: 'Caution; address modifiable factors', colorHex: _red),
      ],
    ),
    ClinicalTool(
      id: 'tool_wells_pe', name: 'Wells Score (PE)', category: ToolCategory.score, formulaKey: 'sum',
      conceptIds: ['c_pe'], relatedDiseaseIds: ['d_pe'], description: 'Pretest probability of pulmonary embolism.', specialty: 'Emergency',
      inputs: [
        ToolInput(key: 'dvt', label: 'Clinical signs of DVT', type: ToolInputType.boolean, points: 3),
        ToolInput(key: 'alt', label: 'PE is #1 diagnosis', type: ToolInputType.boolean, points: 3),
        ToolInput(key: 'hr', label: 'Heart rate > 100', type: ToolInputType.boolean, points: 1.5),
        ToolInput(key: 'immob', label: 'Immobilization / surgery (4w)', type: ToolInputType.boolean, points: 1.5),
        ToolInput(key: 'prior', label: 'Previous PE/DVT', type: ToolInputType.boolean, points: 1.5),
        ToolInput(key: 'hemoptysis', label: 'Hemoptysis', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'malignancy', label: 'Malignancy', type: ToolInputType.boolean, points: 1),
      ],
      bands: [
        OutputBand(min: 0, max: 1.99, label: 'Low', interpretation: 'Consider PERC / D-dimer', colorHex: _green),
        OutputBand(min: 2, max: 6, label: 'Moderate', interpretation: 'D-dimer or imaging', colorHex: _yellow),
        OutputBand(min: 6.01, max: 20, label: 'High', interpretation: 'Proceed to CT angiography', colorHex: _red),
      ],
    ),
    ClinicalTool(
      id: 'tool_curb65', name: 'CURB-65', category: ToolCategory.score, formulaKey: 'sum',
      conceptIds: ['c_cap'], relatedDiseaseIds: ['d_cap'], description: 'Pneumonia severity → site-of-care decision.', specialty: 'Pulmonology',
      inputs: [
        ToolInput(key: 'confusion', label: 'Confusion', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'urea', label: 'Urea > 7 mmol/L (BUN > 19)', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'rr', label: 'Respiratory rate ≥ 30', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'bp', label: 'SBP < 90 or DBP ≤ 60', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'age', label: 'Age ≥ 65', type: ToolInputType.boolean, points: 1),
      ],
      bands: [
        OutputBand(min: 0, max: 1, label: 'Low', interpretation: 'Outpatient likely appropriate', colorHex: _green),
        OutputBand(min: 2, max: 2, label: 'Moderate', interpretation: 'Consider short admission', colorHex: _yellow),
        OutputBand(min: 3, max: 5, label: 'Severe', interpretation: 'Admit; assess for ICU', colorHex: _red),
      ],
    ),
    ClinicalTool(
      id: 'tool_qsofa', name: 'qSOFA', category: ToolCategory.score, formulaKey: 'sum',
      conceptIds: ['c_sepsis'], relatedDiseaseIds: ['d_sepsis'], description: 'Rapid bedside sepsis risk screen.', specialty: 'Critical care',
      inputs: [
        ToolInput(key: 'rr', label: 'Respiratory rate ≥ 22', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'mentation', label: 'Altered mentation (GCS < 15)', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'sbp', label: 'Systolic BP ≤ 100', type: ToolInputType.boolean, points: 1),
      ],
      bands: [
        OutputBand(min: 0, max: 1, label: 'Lower risk', interpretation: 'Continue monitoring', colorHex: _green),
        OutputBand(min: 2, max: 3, label: 'High risk', interpretation: 'Evaluate for sepsis / organ dysfunction', colorHex: _red),
      ],
    ),
    ClinicalTool(
      id: 'tool_gcs', name: 'Glasgow Coma Scale', category: ToolCategory.score, formulaKey: 'sum',
      conceptIds: ['c_stroke'], description: 'Quantifies level of consciousness (3–15).', specialty: 'Neurology',
      inputs: [
        ToolInput(key: 'eye', label: 'Eye opening', type: ToolInputType.select, defaultValue: 4, options: [
          ToolOption(label: 'None', value: 1, points: 1), ToolOption(label: 'To pain', value: 2, points: 2),
          ToolOption(label: 'To voice', value: 3, points: 3), ToolOption(label: 'Spontaneous', value: 4, points: 4),
        ]),
        ToolInput(key: 'verbal', label: 'Verbal response', type: ToolInputType.select, defaultValue: 5, options: [
          ToolOption(label: 'None', value: 1, points: 1), ToolOption(label: 'Incomprehensible', value: 2, points: 2),
          ToolOption(label: 'Inappropriate words', value: 3, points: 3), ToolOption(label: 'Confused', value: 4, points: 4),
          ToolOption(label: 'Oriented', value: 5, points: 5),
        ]),
        ToolInput(key: 'motor', label: 'Motor response', type: ToolInputType.select, defaultValue: 6, options: [
          ToolOption(label: 'None', value: 1, points: 1), ToolOption(label: 'Extension', value: 2, points: 2),
          ToolOption(label: 'Abnormal flexion', value: 3, points: 3), ToolOption(label: 'Withdraws', value: 4, points: 4),
          ToolOption(label: 'Localizes', value: 5, points: 5), ToolOption(label: 'Obeys commands', value: 6, points: 6),
        ]),
      ],
      bands: [
        OutputBand(min: 3, max: 8, label: 'Severe', interpretation: 'Consider airway protection', colorHex: _red),
        OutputBand(min: 9, max: 12, label: 'Moderate', interpretation: 'Moderate impairment', colorHex: _orange),
        OutputBand(min: 13, max: 15, label: 'Mild', interpretation: 'Minor or no impairment', colorHex: _green),
      ],
    ),
    ClinicalTool(
      id: 'tool_centor', name: 'Centor Criteria (Strep)', category: ToolCategory.score, formulaKey: 'sum',
      description: 'Likelihood of strep pharyngitis.', specialty: 'Primary care',
      inputs: [
        ToolInput(key: 'exudate', label: 'Tonsillar exudate', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'nodes', label: 'Tender anterior cervical nodes', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'fever', label: 'Fever > 38°C', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'cough', label: 'Absence of cough', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'age', label: 'Age', type: ToolInputType.select, defaultValue: 0, options: [
          ToolOption(label: '3–14', value: 1, points: 1), ToolOption(label: '15–44', value: 0, points: 0), ToolOption(label: '≥ 45', value: -1, points: -1),
        ]),
      ],
      bands: [
        OutputBand(min: -1, max: 1, label: 'Low', interpretation: 'No testing/antibiotics', colorHex: _green),
        OutputBand(min: 2, max: 3, label: 'Moderate', interpretation: 'Rapid strep test', colorHex: _yellow),
        OutputBand(min: 4, max: 5, label: 'High', interpretation: 'Test ± empiric treatment', colorHex: _orange),
      ],
    ),
    ClinicalTool(
      id: 'tool_glucose_conv', name: 'Glucose Converter', category: ToolCategory.converter, formulaKey: 'glucose_conv',
      description: 'Convert glucose mg/dL → mmol/L.', specialty: 'General', outputUnit: 'mmol/L',
      inputs: [ToolInput(key: 'glucose', label: 'Glucose', unit: 'mg/dL', min: 10, max: 1500)],
    ),
  ];

  static ClinicalTool? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }
}
