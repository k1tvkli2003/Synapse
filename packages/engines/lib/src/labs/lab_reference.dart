import 'package:synapse_core/synapse_core.dart';

/// Reference intervals for the supported panels (adult, conventional units).
/// Concept ids anchor each analyte into the knowledge graph (prompt 33).
class LabReference {
  const LabReference._();

  static List<LabAnalyte> analytes(LabPanelType panel) => switch (panel) {
        LabPanelType.cbc => _cbc,
        LabPanelType.bmp => _bmp,
        LabPanelType.lft => _lft,
      };

  static LabAnalyte? byId(String id) {
    for (final p in LabPanelType.values) {
      for (final a in analytes(p)) {
        if (a.id == id) return a;
      }
    }
    return null;
  }

  static const _cbc = <LabAnalyte>[
    LabAnalyte(id: 'wbc', name: 'WBC', unit: '×10⁹/L', refLow: 4.0, refHigh: 11.0, criticalLow: 1.0, criticalHigh: 50.0, conceptId: 'c_wbc'),
    LabAnalyte(id: 'hgb', name: 'Hemoglobin', unit: 'g/dL', refLow: 12.0, refHigh: 17.0, criticalLow: 7.0, conceptId: 'c_anemia'),
    LabAnalyte(id: 'hct', name: 'Hematocrit', unit: '%', refLow: 36.0, refHigh: 50.0, conceptId: 'c_anemia'),
    LabAnalyte(id: 'plt', name: 'Platelets', unit: '×10⁹/L', refLow: 150, refHigh: 400, criticalLow: 20, criticalHigh: 1000, conceptId: 'c_thrombocytopenia'),
    LabAnalyte(id: 'mcv', name: 'MCV', unit: 'fL', refLow: 80, refHigh: 100, conceptId: 'c_anemia'),
  ];

  static const _bmp = <LabAnalyte>[
    LabAnalyte(id: 'na', name: 'Sodium', unit: 'mmol/L', refLow: 135, refHigh: 145, criticalLow: 120, criticalHigh: 160, conceptId: 'c_hyponatremia'),
    LabAnalyte(id: 'k', name: 'Potassium', unit: 'mmol/L', refLow: 3.5, refHigh: 5.0, criticalLow: 2.5, criticalHigh: 6.5, conceptId: 'c_hyperkalemia'),
    LabAnalyte(id: 'cl', name: 'Chloride', unit: 'mmol/L', refLow: 98, refHigh: 107, conceptId: 'c_electrolytes'),
    LabAnalyte(id: 'hco3', name: 'Bicarbonate', unit: 'mmol/L', refLow: 22, refHigh: 29, criticalLow: 10, conceptId: 'c_acidosis'),
    LabAnalyte(id: 'bun', name: 'BUN', unit: 'mg/dL', refLow: 7, refHigh: 20, conceptId: 'c_aki'),
    LabAnalyte(id: 'cr', name: 'Creatinine', unit: 'mg/dL', refLow: 0.6, refHigh: 1.3, criticalHigh: 4.0, conceptId: 'c_aki'),
    LabAnalyte(id: 'glu', name: 'Glucose', unit: 'mg/dL', refLow: 70, refHigh: 110, criticalLow: 40, criticalHigh: 500, conceptId: 'c_hyperglycemia'),
    LabAnalyte(id: 'ca', name: 'Calcium', unit: 'mg/dL', refLow: 8.5, refHigh: 10.5, criticalLow: 6.0, criticalHigh: 13.0, conceptId: 'c_calcium'),
  ];

  static const _lft = <LabAnalyte>[
    LabAnalyte(id: 'ast', name: 'AST', unit: 'U/L', refLow: 10, refHigh: 40, conceptId: 'c_hepatocellular'),
    LabAnalyte(id: 'alt', name: 'ALT', unit: 'U/L', refLow: 7, refHigh: 56, conceptId: 'c_hepatocellular'),
    LabAnalyte(id: 'alp', name: 'ALP', unit: 'U/L', refLow: 44, refHigh: 147, conceptId: 'c_cholestasis'),
    LabAnalyte(id: 'tbili', name: 'Total Bilirubin', unit: 'mg/dL', refLow: 0.1, refHigh: 1.2, criticalHigh: 15, conceptId: 'c_jaundice'),
    LabAnalyte(id: 'alb', name: 'Albumin', unit: 'g/dL', refLow: 3.5, refHigh: 5.0, conceptId: 'c_synthetic_liver'),
  ];
}
