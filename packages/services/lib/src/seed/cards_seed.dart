import 'package:synapse_core/synapse_core.dart';

/// Seed flashcard decks (prompt 12). Cards reuse [SrsCard] so they schedule
/// through the shared SRS engine and mix into the Daily Review.
class CardsSeed {
  const CardsSeed._();

  static const List<Deck> decks = [
    Deck(id: 'd_cardio', title: 'Cardiology Essentials', description: 'High-yield heart facts', colorHex: 0xFF6FD3E8, conceptIds: ['c_afib', 'c_stemi', 'c_hyperkalemia'], cardIds: ['cd1', 'cd2', 'cd3', 'cd4']),
    Deck(id: 'd_labs', title: 'Lab Interpretation', description: 'Patterns & pitfalls', colorHex: 0xFFC3E88D, conceptIds: ['c_anemia', 'c_anion_gap'], cardIds: ['cd5', 'cd6', 'cd7']),
    Deck(id: 'd_pharm', title: 'Antibiotics', description: 'Classes & coverage', colorHex: 0xFFFFB07A, conceptIds: ['c_beta_lactam', 'c_mrsa'], cardIds: ['cd8', 'cd9']),
  ];

  /// Cards keyed by id (built fresh so dueAt is "now" on first run).
  static List<SrsCard> cards(String ownerId) => [
        SrsCard(id: 'cd1', ownerId: ownerId, origin: SrsOrigin.cards, conceptId: 'c_afib', front: 'ECG hallmark of atrial fibrillation?', back: 'Irregularly irregular rhythm with absent P waves and a fibrillatory baseline.'),
        SrsCard(id: 'cd2', ownerId: ownerId, origin: SrsOrigin.cards, conceptId: 'c_stemi', front: 'First step when ECG shows ST elevation in a patient with chest pain?', back: 'Activate the cath lab for primary PCI; give aspirin. Time is muscle.'),
        SrsCard(id: 'cd3', ownerId: ownerId, origin: SrsOrigin.cards, conceptId: 'c_hyperkalemia', front: 'Earliest ECG change in hyperkalemia?', back: 'Tall, peaked, symmetric T waves.'),
        SrsCard(id: 'cd4', ownerId: ownerId, origin: SrsOrigin.cards, conceptId: 'c_bradycardia', front: 'First-line drug for symptomatic bradycardia?', back: 'Atropine 1 mg IV (repeat to 3 mg); then pacing/chronotropes.'),
        SrsCard(id: 'cd5', ownerId: ownerId, origin: SrsOrigin.cards, conceptId: 'c_anion_gap', front: 'How do you calculate the anion gap?', back: 'Na − (Cl + HCO₃). Normal ≈ 8–12 mmol/L.'),
        SrsCard(id: 'cd6', ownerId: ownerId, origin: SrsOrigin.cards, conceptId: 'c_micro_anemia', front: 'Microcytic anemia differential?', back: 'Iron deficiency, thalassemia, chronic disease, sideroblastic.'),
        SrsCard(id: 'cd7', ownerId: ownerId, origin: SrsOrigin.cards, conceptId: 'c_aki', front: 'BUN/Cr ratio suggesting a prerenal cause?', back: 'A ratio > 20:1.'),
        SrsCard(id: 'cd8', ownerId: ownerId, origin: SrsOrigin.cards, conceptId: 'c_mrsa', front: 'First-line antibiotic for MRSA?', back: 'Vancomycin (or linezolid/daptomycin).'),
        SrsCard(id: 'cd9', ownerId: ownerId, origin: SrsOrigin.cards, conceptId: 'c_beta_lactam', front: 'Mechanism of beta-lactam antibiotics?', back: 'Inhibit cell-wall synthesis by binding penicillin-binding proteins.'),
      ];

  static Deck? deckById(String id) {
    for (final d in decks) {
      if (d.id == id) return d;
    }
    return null;
  }
}
