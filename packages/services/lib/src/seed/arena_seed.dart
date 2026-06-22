import 'package:synapse_core/synapse_core.dart';

/// Arena content (prompt 21): antibiotic units + bacteria. Stats teach real
/// spectrum coverage — broad agents are flexible but costly; narrow agents hit
/// hard against their target gram type.
class ArenaSeed {
  const ArenaSeed._();

  static const List<UnitCard> cards = [
    UnitCard(id: 'ab_pcn', name: 'Penicillin G', drugClass: 'Penicillin', cost: 2, damage: 3, hp: 4, spectrum: Spectrum.gramPositive, rarity: CardRarity.common, conceptId: 'c_beta_lactam', mechanism: 'Inhibits cell-wall synthesis (PBP).'),
    UnitCard(id: 'ab_amox', name: 'Amoxicillin', drugClass: 'Aminopenicillin', cost: 3, damage: 4, hp: 5, spectrum: Spectrum.broad, rarity: CardRarity.common, conceptId: 'c_beta_lactam', mechanism: 'Broader gram-negative reach than penicillin G.'),
    UnitCard(id: 'ab_ceftriaxone', name: 'Ceftriaxone', drugClass: '3rd-gen cephalosporin', cost: 4, damage: 5, hp: 5, spectrum: Spectrum.broad, rarity: CardRarity.rare, conceptId: 'c_beta_lactam', mechanism: 'Workhorse broad-spectrum cephalosporin.'),
    UnitCard(id: 'ab_vanc', name: 'Vancomycin', drugClass: 'Glycopeptide', cost: 5, damage: 7, hp: 6, spectrum: Spectrum.gramPositive, rarity: CardRarity.epic, conceptId: 'c_mrsa', mechanism: 'Binds D-Ala-D-Ala; covers MRSA.'),
    UnitCard(id: 'ab_piptazo', name: 'Pip-Tazo', drugClass: 'Penicillin + BLI', cost: 6, damage: 6, hp: 7, spectrum: Spectrum.broad, rarity: CardRarity.epic, conceptId: 'c_pseudomonas', mechanism: 'Anti-pseudomonal broad coverage.'),
    UnitCard(id: 'ab_cipro', name: 'Ciprofloxacin', drugClass: 'Fluoroquinolone', cost: 4, damage: 6, hp: 4, spectrum: Spectrum.gramNegative, rarity: CardRarity.rare, mechanism: 'Inhibits DNA gyrase; strong gram-negative.'),
    UnitCard(id: 'ab_gent', name: 'Gentamicin', drugClass: 'Aminoglycoside', cost: 4, damage: 7, hp: 3, spectrum: Spectrum.gramNegative, rarity: CardRarity.rare, mechanism: '30S inhibitor; synergy with cell-wall agents.'),
    UnitCard(id: 'ab_azithro', name: 'Azithromycin', drugClass: 'Macrolide', cost: 3, damage: 4, hp: 4, spectrum: Spectrum.broad, rarity: CardRarity.common, mechanism: '50S inhibitor; atypicals.'),
    UnitCard(id: 'ab_metro', name: 'Metronidazole', drugClass: 'Nitroimidazole', cost: 3, damage: 5, hp: 4, spectrum: Spectrum.gramNegative, rarity: CardRarity.common, mechanism: 'Anaerobe and protozoa coverage.'),
    UnitCard(id: 'ab_linezolid', name: 'Linezolid', drugClass: 'Oxazolidinone', cost: 5, damage: 7, hp: 5, spectrum: Spectrum.gramPositive, rarity: CardRarity.epic, conceptId: 'c_mrsa', mechanism: 'Covers MRSA & VRE.'),
    UnitCard(id: 'ab_meropenem', name: 'Meropenem', drugClass: 'Carbapenem', cost: 7, damage: 8, hp: 8, spectrum: Spectrum.broad, rarity: CardRarity.legendary, conceptId: 'c_beta_lactam', mechanism: 'Last-line broad spectrum; reserve it.'),
    UnitCard(id: 'ab_doxy', name: 'Doxycycline', drugClass: 'Tetracycline', cost: 3, damage: 4, hp: 4, spectrum: Spectrum.broad, rarity: CardRarity.common, mechanism: '30S inhibitor; atypicals & tick-borne.'),
  ];

  static const List<BacteriaUnit> bacteria = [
    BacteriaUnit(id: 'bac_strep', name: 'S. pyogenes', hp: 8, damage: 2, spectrum: Spectrum.gramPositive, speed: 1.0, conceptId: 'c_gram_stain'),
    BacteriaUnit(id: 'bac_mrsa', name: 'MRSA', hp: 14, damage: 4, spectrum: Spectrum.gramPositive, speed: 0.8, conceptId: 'c_mrsa', resistsClasses: ['Penicillin', 'Aminopenicillin', '3rd-gen cephalosporin']),
    BacteriaUnit(id: 'bac_ecoli', name: 'E. coli', hp: 10, damage: 3, spectrum: Spectrum.gramNegative, speed: 1.1, conceptId: 'c_gram_stain'),
    BacteriaUnit(id: 'bac_pseudo', name: 'P. aeruginosa', hp: 16, damage: 5, spectrum: Spectrum.gramNegative, speed: 0.9, conceptId: 'c_pseudomonas', resistsClasses: ['Penicillin', 'Macrolide', '3rd-gen cephalosporin']),
    BacteriaUnit(id: 'bac_anaerobe', name: 'B. fragilis', hp: 12, damage: 3, spectrum: Spectrum.gramNegative, speed: 0.7),
    BacteriaUnit(id: 'bac_kleb', name: 'K. pneumoniae', hp: 13, damage: 4, spectrum: Spectrum.gramNegative, speed: 1.0),
  ];

  static UnitCard? cardById(String id) {
    for (final c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// The default starter deck of 8 cards.
  static const ArenaDeck starterDeck = ArenaDeck(
    cardIds: ['ab_pcn', 'ab_amox', 'ab_ceftriaxone', 'ab_vanc', 'ab_cipro', 'ab_azithro', 'ab_metro', 'ab_doxy'],
  );
}
