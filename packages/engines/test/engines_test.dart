import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_engines/synapse_engines.dart';
import 'package:test/test.dart';

void main() {
  group('XpCurve', () {
    test('level rises with total XP and progress is consistent', () {
      final s0 = XpCurve.levelFromTotal(0);
      expect(s0.level, 1);
      expect(s0.intoLevel, 0);

      final big = XpCurve.levelFromTotal(10000);
      expect(big.level, greaterThan(1));
      // intoLevel never exceeds the cost of the current level.
      expect(big.intoLevel, lessThan(big.toNext));
    });

    test('totalToReach is monotonic', () {
      expect(XpCurve.totalToReach(3), greaterThan(XpCurve.totalToReach(2)));
    });
  });

  group('GamificationEngine', () {
    test('awards XP and rolls the streak on first activity', () {
      const engine = GamificationEngine();
      final result = engine.award(
        const GamificationState(),
        RewardEvent(source: ModuleKey.ecg, kind: RewardKind.correct, xp: 10),
        now: DateTime(2026, 1, 1, 9),
      );
      expect(result.state.xp.total, greaterThanOrEqualTo(10));
      expect(result.state.streak.current, 1);
      expect(result.intents.any((i) => i is StreakUpIntent), isTrue);
    });

    test('streak does not double-count the same day', () {
      const engine = GamificationEngine();
      var state = const GamificationState();
      state = engine.award(state, RewardEvent(source: ModuleKey.ecg, kind: RewardKind.correct, xp: 5), now: DateTime(2026, 1, 1, 9)).state;
      state = engine.award(state, RewardEvent(source: ModuleKey.terms, kind: RewardKind.correct, xp: 5), now: DateTime(2026, 1, 1, 20)).state;
      expect(state.streak.current, 1);
    });

    test('consecutive days extend the streak', () {
      const engine = GamificationEngine();
      var state = const GamificationState();
      state = engine.award(state, RewardEvent(source: ModuleKey.ecg, kind: RewardKind.correct, xp: 5), now: DateTime(2026, 1, 1, 9)).state;
      state = engine.award(state, RewardEvent(source: ModuleKey.ecg, kind: RewardKind.correct, xp: 5), now: DateTime(2026, 1, 2, 9)).state;
      expect(state.streak.current, 2);
    });

    test('hearts decrement and refill with gems', () {
      const engine = GamificationEngine();
      var state = const GamificationState(wallet: Wallet(gems: 100));
      state = engine.loseHeart(state);
      expect(state.hearts.current, 4);
      state = engine.refillHeartsWithGems(state);
      expect(state.hearts.current, 5);
      expect(state.wallet.gems, 50);
    });
  });

  group('SrsEngine', () {
    test('again resets interval and increments lapses', () {
      final card = SrsCard(id: 'c', ownerId: 'u', origin: SrsOrigin.cards, front: 'f', back: 'b', intervalDays: 10, reps: 3);
      final graded = SrsEngine.grade(card, ReviewGrade.again, now: DateTime(2026, 1, 1));
      expect(graded.lapses, 1);
      expect(graded.intervalDays, 0);
    });

    test('good grading grows the interval', () {
      var card = SrsCard(id: 'c', ownerId: 'u', origin: SrsOrigin.cards, front: 'f', back: 'b');
      card = SrsEngine.grade(card, ReviewGrade.good, now: DateTime(2026, 1, 1));
      expect(card.intervalDays, greaterThanOrEqualTo(1));
      final first = card.intervalDays;
      card = SrsEngine.grade(card, ReviewGrade.good, now: DateTime(2026, 1, 2));
      expect(card.intervalDays, greaterThan(first));
    });

    test('due queue only returns due cards, oldest first', () {
      final now = DateTime(2026, 1, 10);
      final cards = [
        SrsCard(id: 'a', ownerId: 'u', origin: SrsOrigin.cards, front: '', back: '', dueAt: now.subtract(const Duration(days: 2))),
        SrsCard(id: 'b', ownerId: 'u', origin: SrsOrigin.cards, front: '', back: '', dueAt: now.add(const Duration(days: 2))),
        SrsCard(id: 'c', ownerId: 'u', origin: SrsOrigin.cards, front: '', back: '', dueAt: now.subtract(const Duration(days: 5))),
      ];
      final q = SrsEngine.dueQueue(cards, now: now);
      expect(q.map((c) => c.id).toList(), ['c', 'a']);
    });
  });

  group('LabRuleEngine', () {
    test('detects severe hyperkalemia as critical', () {
      final r = LabRuleEngine.evaluate(LabPanelType.bmp, {'k': 7.1, 'na': 138, 'cl': 100, 'hco3': 24});
      expect(r.hasCritical, isTrue);
      expect(r.interpretations.any((i) => i.title.toLowerCase().contains('hyperkalemia')), isTrue);
      expect(r.flags['k'], LabFlag.criticalHigh);
    });

    test('computes the anion gap and flags HAGMA', () {
      final r = LabRuleEngine.evaluate(LabPanelType.bmp, {'na': 140, 'cl': 100, 'hco3': 12});
      expect(r.derivedIndices['Anion gap'], 28);
      expect(r.interpretations.any((i) => i.firedRuleId == 'bmp.hagma'), isTrue);
    });

    test('classifies microcytic anemia from CBC', () {
      final r = LabRuleEngine.evaluate(LabPanelType.cbc, {'hgb': 9.0, 'mcv': 70, 'wbc': 7, 'plt': 250});
      expect(r.interpretations.any((i) => i.title == 'Microcytic anemia'), isTrue);
    });

    test('normal panel reports no abnormal pattern', () {
      // Anion gap = 140 - (105 + 25) = 10 (normal), all values in range.
      final r = LabRuleEngine.evaluate(LabPanelType.bmp, {'na': 140, 'k': 4.0, 'cl': 105, 'hco3': 25, 'bun': 12, 'cr': 1.0, 'glu': 90, 'ca': 9.5});
      expect(r.interpretations.length, 1);
      expect(r.interpretations.first.firedRuleId, 'baseline');
    });
  });

  group('QuestEngine + LeagueEngine', () {
    test('quest goal advances and completes on matching events', () {
      const quest = Quest(
        id: 'q',
        title: 'Test',
        period: QuestPeriod.daily,
        goals: [QuestGoal(label: 'Read 2 ECGs', kind: RewardKind.correct, target: 2, module: ModuleKey.ecg)],
      );
      var update = QuestEngine.apply([quest], RewardEvent(source: ModuleKey.ecg, kind: RewardKind.correct, xp: 1));
      expect(update.quests.first.goals.first.progress, 1);
      update = QuestEngine.apply(update.quests, RewardEvent(source: ModuleKey.ecg, kind: RewardKind.correct, xp: 1));
      expect(update.quests.first.isComplete, isTrue);
      expect(update.newlyComplete, contains('q'));
    });

    test('league promotes above threshold', () {
      final out = LeagueEngine.evaluateWeek(League.bronze, 700);
      expect(out.move, LeagueMove.promoted);
      expect(out.league, League.silver);
    });
  });

  group('ConceptMastery', () {
    test('correct outcomes raise mastery, wrong ones lower it', () {
      var m = ConceptMastery(conceptId: 'c');
      for (var i = 0; i < 6; i++) {
        m = m.applyOutcome(wasCorrect: true, source: ModuleKey.terms);
      }
      expect(m.mastery, greaterThan(0.6));
      final dropped = m.applyOutcome(wasCorrect: false, source: ModuleKey.ecg);
      expect(dropped.mastery, lessThan(m.mastery));
    });
  });

  group('EcgGenerator', () {
    test('produces the requested number of samples and asystole is near-flat', () {
      final sinus = EcgGenerator.generate(const EcgGenParams(), sampleCount: 300);
      expect(sinus.length, 300);
      final flat = EcgGenerator.generate(const EcgGenParams(rhythm: EcgRhythm.asystole), sampleCount: 100);
      expect(flat.every((v) => v.abs() < 0.1), isTrue);
    });
  });
}
