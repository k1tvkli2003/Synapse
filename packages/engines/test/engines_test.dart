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
      var m = const ConceptMastery(conceptId: 'c');
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

  group('CalculatorEngine', () {
    const bmi = ClinicalTool(
      id: 't', name: 'BMI', formulaKey: 'bmi', category: ToolCategory.formula,
      inputs: [ToolInput(key: 'weight', label: 'W'), ToolInput(key: 'height', label: 'H')],
      bands: [
        OutputBand(min: 18.5, max: 24.99, label: 'Normal', interpretation: '', colorHex: 0),
        OutputBand(min: 25, max: 100, label: 'Overweight', interpretation: '', colorHex: 0),
      ],
    );
    const ag = ClinicalTool(
      id: 't2', name: 'AG', formulaKey: 'anion_gap', category: ToolCategory.formula,
      inputs: [ToolInput(key: 'na', label: ''), ToolInput(key: 'cl', label: ''), ToolInput(key: 'hco3', label: '')],
      bands: [
        OutputBand(min: -50, max: 12, label: 'Normal', interpretation: '', colorHex: 0),
        OutputBand(min: 12.01, max: 100, label: 'High', interpretation: '', colorHex: 0),
      ],
    );
    const score = ClinicalTool(
      id: 't3', name: 'Score', formulaKey: 'sum', category: ToolCategory.score,
      inputs: [
        ToolInput(key: 'a', label: '', type: ToolInputType.boolean, points: 1),
        ToolInput(key: 'b', label: '', type: ToolInputType.boolean, points: 2),
        ToolInput(key: 'age', label: '', type: ToolInputType.select, options: [
          ToolOption(label: 'old', value: 2, points: 2),
        ]),
      ],
      bands: [OutputBand(min: 2, max: 9, label: 'High', interpretation: '', colorHex: 0)],
    );

    test('BMI computes and bands correctly', () {
      final r = CalculatorEngine.evaluate(bmi, {'weight': 70, 'height': 175});
      expect(r.value, closeTo(22.86, 0.05));
      expect(r.band?.label, 'Normal');
    });

    test('additive score sums boolean + select points and bands high', () {
      final r = CalculatorEngine.evaluate(score, {'a': true, 'b': true, 'age': 2.0});
      expect(r.value, 5); // 1 + 2 + 2
      expect(r.band?.label, 'High');
    });

    test('anion gap flags a high gap', () {
      final r = CalculatorEngine.evaluate(ag, {'na': 140, 'cl': 100, 'hco3': 12});
      expect(r.value, 28);
      expect(r.band?.label, 'High');
    });

    test('missing inputs report an error, not a crash', () {
      final r = CalculatorEngine.evaluate(bmi, {'weight': 70});
      expect(r.hasError, isTrue);
    });
  });

  group('InteractionEngine', () {
    const warfarin = Drug(
      id: 'warfarin', conceptId: 'c', genericName: 'Warfarin', mechanism: '', classIds: ['vka'],
      interactions: [DrugInteraction(withDrugId: 'aspirin', severity: InteractionSeverity.major, effect: 'bleeding')],
    );
    const aspirin = Drug(id: 'aspirin', conceptId: 'c', genericName: 'Aspirin', mechanism: '', classIds: ['antiplatelet']);
    const statin = Drug(
      id: 'statin', conceptId: 'c', genericName: 'Atorvastatin', mechanism: '', classIds: ['statin'],
      interactions: [DrugInteraction(withClassId: 'macrolide', severity: InteractionSeverity.moderate, effect: 'myopathy')],
    );
    const macrolide = Drug(id: 'azithro', conceptId: 'c', genericName: 'Azithromycin', mechanism: '', classIds: ['macrolide']);
    const metformin = Drug(id: 'metformin', conceptId: 'c', genericName: 'Metformin', mechanism: '', classIds: ['biguanide']);

    test('detects a major warfarin + aspirin interaction', () {
      final found = InteractionEngine.check([warfarin, aspirin]);
      expect(found, isNotEmpty);
      expect(found.first.severity, InteractionSeverity.major);
    });

    test('detects class-level statin + macrolide interaction', () {
      final found = InteractionEngine.check([statin, macrolide]);
      expect(found.any((f) => f.severity == InteractionSeverity.moderate), isTrue);
    });

    test('no interaction for an unrelated pair', () {
      final found = InteractionEngine.check([metformin, aspirin]);
      expect(found, isEmpty);
    });
  });

  group('LearnerModel', () {
    test('pKnown rises with correct reps and difficulty scales with it', () {
      const lm = LearnerModel();
      var m = const ConceptMastery(conceptId: 'c');
      for (var i = 0; i < 8; i++) {
        m = m.applyOutcome(wasCorrect: true, source: ModuleKey.cards);
      }
      expect(lm.pKnown(m), greaterThan(0.6));
      expect(lm.nextDifficulty(m), greaterThanOrEqualTo(3));
    });

    test('retention decays and a stale weak concept is at risk', () {
      const lm = LearnerModel();
      final old = DateTime.now().subtract(const Duration(days: 30));
      final m = ConceptMastery(conceptId: 'c', mastery: 0.4, attempts: 3, correct: 1, lastStudied: old);
      final pred = lm.predict(m);
      expect(pred.retention, lessThan(0.6));
      expect(pred.atRisk, isTrue);
    });
  });
}
