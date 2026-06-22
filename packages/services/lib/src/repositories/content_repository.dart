import 'package:synapse_core/synapse_core.dart';

import '../seed/algorithms_seed.dart';
import '../seed/arena_seed.dart';
import '../seed/cards_seed.dart';
import '../seed/cases_seed.dart';
import '../seed/concepts_seed.dart';
import '../seed/ecg_seed.dart';
import '../seed/mnemonics_seed.dart';
import '../seed/social_seed.dart';
import '../seed/sounds_seed.dart';
import '../seed/terms_seed.dart';

/// The offline-first content repository (prompt 05/23). Serves all seed content
/// and, crucially, builds the unified [LearnItem] index that powers global
/// search (prompt 36) and the concept hub (prompt 30) — the integration payoff.
class ContentRepository {
  ContentRepository() {
    _buildIndex();
  }

  final List<LearnItem> _items = [];
  final Map<ConceptId, List<LearnItem>> _byConcept = {};

  // ---- Concepts ----
  List<Concept> get concepts => ConceptsSeed.all;
  Concept? concept(ConceptId id) => ConceptsSeed.byId(id);

  // ---- Module content passthrough ----
  List<CoursePath> get termsPaths => TermsSeed.paths;
  List<Deck> get decks => CardsSeed.decks;
  List<SrsCard> seedCards(String ownerId) => CardsSeed.cards(ownerId);
  List<Mnemonic> get mnemonics => MnemonicsSeed.all;
  List<EcgCase> get ecgCases => EcgSeed.all;
  List<BodySound> get sounds => SoundsSeed.all;
  List<DiagnosticAlgorithm> get algorithms => AlgorithmsSeed.all;
  List<UnitCard> get arenaCards => ArenaSeed.cards;
  List<BacteriaUnit> get bacteria => ArenaSeed.bacteria;
  List<Round> get rounds => SocialSeed.rounds;
  List<BuddyProfile> get buddies => SocialSeed.buddies;
  List<AudioDrama> get dramas => SocialSeed.dramas;
  List<VirtualPatientCase> get cases => CasesSeed.all;

  // ---- Unified index ----
  List<LearnItem> get learnItems => List.unmodifiable(_items);

  /// Every learn item that anchors to [conceptId] (cross-module "see also").
  List<LearnItem> itemsForConcept(ConceptId conceptId) =>
      _byConcept[conceptId] ?? const [];

  /// Concepts whose name/alias match [query].
  List<Concept> searchConcepts(String query) =>
      concepts.where((c) => c.matches(query)).toList();

  /// Unified search across concepts + every learn item (prompt 36).
  SearchResults search(String query) {
    final q = query.trim();
    if (q.isEmpty) return const SearchResults(concepts: [], items: []);
    return SearchResults(
      concepts: concepts.where((c) => c.matches(q)).take(8).toList(),
      items: _items.where((i) => i.matches(q)).take(30).toList(),
    );
  }

  void _add(LearnItem item) {
    _items.add(item);
    for (final cid in item.conceptIds) {
      _byConcept.putIfAbsent(cid, () => []).add(item);
    }
  }

  void _buildIndex() {
    for (final c in ecgCases) {
      _add(LearnItem(
        id: 'ecg_${c.id}',
        module: ModuleKey.ecg,
        title: c.diagnosis,
        subtitle: c.title,
        route: '/clinical/ecg/case/${c.id}',
        conceptIds: [if (c.conceptId != null) c.conceptId!],
        keywords: [...c.findings, c.rhythm.name],
        difficulty: c.difficulty,
      ));
    }
    for (final m in mnemonics) {
      _add(LearnItem(
        id: 'mnem_${m.id}',
        module: ModuleKey.mnemonics,
        title: m.title,
        subtitle: m.body,
        route: '/learn/mnemonics/${m.id}',
        conceptIds: m.conceptIds,
        keywords: [m.body, ...m.tags],
      ));
    }
    for (final s in sounds) {
      _add(LearnItem(
        id: 'snd_${s.id}',
        module: ModuleKey.sounds,
        title: s.name,
        subtitle: s.kind == SoundKind.heart ? 'Heart sound' : 'Lung sound',
        route: '/clinical/sounds/${s.id}',
        conceptIds: [if (s.conceptId != null) s.conceptId!],
        keywords: [if (s.location != null) s.location!, if (s.timingHint != null) s.timingHint!],
      ));
    }
    for (final a in algorithms) {
      _add(LearnItem(
        id: 'algo_${a.id}',
        module: ModuleKey.algorithms,
        title: a.title,
        subtitle: a.specialty,
        route: '/clinical/algorithms/${a.id}',
        conceptIds: a.conceptIds,
        keywords: [if (a.description != null) a.description!],
      ));
    }
    for (final p in termsPaths) {
      for (final u in p.units) {
        for (final l in u.lessons) {
          _add(LearnItem(
            id: 'terms_${l.id}',
            module: ModuleKey.terms,
            title: l.title,
            subtitle: '${p.title} · ${u.title}',
            route: '/learn/terms/lesson/${l.id}',
            conceptIds: l.conceptIds,
          ));
        }
      }
    }
    for (final d in decks) {
      _add(LearnItem(
        id: 'deck_${d.id}',
        module: ModuleKey.cards,
        title: d.title,
        subtitle: '${d.size} cards',
        route: '/learn/cards/deck/${d.id}',
        conceptIds: d.conceptIds,
      ));
    }
    for (final dr in dramas) {
      _add(LearnItem(
        id: 'or_${dr.id}',
        module: ModuleKey.orLab,
        title: dr.title,
        subtitle: dr.surgery,
        route: '/clinical/or-lab/${dr.id}',
        conceptIds: dr.conceptIds,
      ));
    }
    for (final r in rounds) {
      _add(LearnItem(
        id: 'round_${r.id}',
        module: ModuleKey.rounds,
        title: r.title,
        subtitle: 'by ${r.authorName}',
        route: '/social/rounds/${r.id}',
        conceptIds: r.conceptIds,
        keywords: r.tags,
      ));
    }
    for (final c in cases) {
      _add(LearnItem(
        id: 'case_${c.id}',
        module: ModuleKey.copilot,
        title: c.title,
        subtitle: 'Virtual patient',
        route: '/cases/${c.id}',
        conceptIds: c.conceptIds,
        keywords: [if (c.finalDiagnosis != null) c.finalDiagnosis!],
        difficulty: c.difficulty,
      ));
    }
  }
}

class SearchResults {
  const SearchResults({required this.concepts, required this.items});
  final List<Concept> concepts;
  final List<LearnItem> items;

  bool get isEmpty => concepts.isEmpty && items.isEmpty;
  int get total => concepts.length + items.length;
}
