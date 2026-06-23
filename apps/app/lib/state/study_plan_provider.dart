import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_engines/synapse_engines.dart';
import 'package:synapse_services/synapse_services.dart';

import '../router/routes.dart';
import 'app_providers.dart';
import 'game_provider.dart';
import 'srs_provider.dart';
import 'user_provider.dart';

enum StudyTaskKind { review, remediate, learn, caseSim, motivation, reference }

/// One time-boxed task in the daily plan, deep-linking into its module (35).
class StudyTask {
  const StudyTask({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.route,
    required this.minutes,
    required this.kind,
    this.conceptIds = const [],
    this.reason,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String route;
  final int minutes;
  final StudyTaskKind kind;
  final List<ConceptId> conceptIds;

  /// Explainable "why" surfaced from the learner model (prompt 49 §5).
  final String? reason;
}

class StudyPlan {
  const StudyPlan({required this.tasks, required this.completed, required this.dateKey});
  final List<StudyTask> tasks;
  final Set<String> completed;
  final String dateKey;

  int get total => tasks.length;
  int get doneCount => tasks.where((t) => completed.contains(t.id)).length;
  double get progress => total == 0 ? 1 : doneCount / total;
  int get minutesLeft => tasks.where((t) => !completed.contains(t.id)).fold(0, (s, t) => s + t.minutes);
  bool isDone(String id) => completed.contains(id);
  List<StudyTask> get remaining => tasks.where((t) => !completed.contains(t.id)).toList();
}

/// The adaptive Study Plan engine + state (prompt 35). Composes an ordered,
/// time-boxed list of mixed tasks from SRS due, weak concepts (learner model),
/// goals and motivation — re-planning live as the game state changes.
class StudyPlanNotifier extends Notifier<StudyPlan> {
  static const _key = 'study_plan_done';
  static const _lm = LearnerModel();

  @override
  StudyPlan build() {
    final store = ref.watch(sharedPreferencesProvider);
    final repo = ref.watch(repositoryProvider);
    final due = ref.watch(dueCountProvider);
    final game = ref.watch(gameProvider);
    final goalXp = ref.watch(userProvider).prefs.dailyGoalXp;

    final today = _todayKey();
    final raw = store.readJson(_key);
    var completed = <String>{};
    if (raw != null && raw['date'] == today && raw['ids'] is List) {
      completed = (raw['ids'] as List).map((e) => e.toString()).toSet();
    }

    final tasks = _composePlan(repo, due, game, goalXp);
    return StudyPlan(tasks: tasks, completed: completed, dateKey: today);
  }

  List<StudyTask> _composePlan(ContentRepository repo, int due, GameState game, int goalXp) {
    final tasks = <StudyTask>[];

    // 1) Due reviews first (retention is the highest priority).
    if (due > 0) {
      tasks.add(StudyTask(
        id: 'review',
        title: 'Daily Review',
        subtitle: '$due item${due == 1 ? '' : 's'} due across Terms, Cards & Mnemonics',
        icon: Icons.replay_rounded,
        accent: const Color(0xFF8E9BFF),
        route: Routes.review,
        minutes: (due * 0.5).ceil().clamp(2, 20),
        kind: StudyTaskKind.review,
        reason: 'Spaced reviews are due — clearing them protects your retention',
      ));
    }

    // 2) Weak-area remediation from the learner model (top 2 at-risk concepts).
    final preds = _lm.prioritize(game.mastery.values, limit: 12)
        .where((p) => p.atRisk || p.pKnown < 0.55)
        .toList();
    var added = 0;
    for (final p in preds) {
      if (added >= 2) break;
      final items = repo.itemsForConcept(p.conceptId);
      if (items.isEmpty) continue;
      final concept = repo.concept(p.conceptId);
      final item = items.first;
      tasks.add(StudyTask(
        id: 'remediate_${p.conceptId}',
        title: 'Fix: ${concept?.name ?? 'weak concept'}',
        subtitle: '${item.module.title} · ${item.title}',
        icon: Icons.healing_rounded,
        accent: Color(item.module.accentHex),
        route: item.route,
        minutes: 4,
        kind: StudyTaskKind.remediate,
        conceptIds: [p.conceptId],
        reason: p.reason,
      ));
      added++;
    }

    // 3) Learn something new toward goal coverage (a fresh lesson / ECG case).
    final newItem = _pickNew(repo, game);
    if (newItem != null) {
      tasks.add(StudyTask(
        id: 'learn_${newItem.id}',
        title: 'Learn: ${newItem.title}',
        subtitle: '${newItem.module.title} · new material',
        icon: Icons.school_rounded,
        accent: Color(newItem.module.accentHex),
        route: newItem.route,
        minutes: 5,
        kind: StudyTaskKind.learn,
        conceptIds: newItem.conceptIds,
        reason: 'New content keeps you progressing toward your goal',
      ));
    }

    // 4) One Virtual Patient case (multi-module synthesis).
    final cases = repo.cases;
    if (cases.isNotEmpty) {
      final c = cases.first;
      tasks.add(StudyTask(
        id: 'case_${c.id}',
        title: 'Case: ${c.title}',
        subtitle: 'Virtual patient · weaves several modules',
        icon: Icons.local_hospital_rounded,
        accent: const Color(0xFFB794F6),
        route: Routes.caseDetail(c.id),
        minutes: 8,
        kind: StudyTaskKind.caseSim,
        conceptIds: c.conceptIds,
        reason: 'Cases integrate everything you have learned',
      ));
    }

    // 5) Reference moment — learn a high-yield disease or drug.
    final diseases = repo.diseases;
    if (diseases.isNotEmpty) {
      final d = diseases[(DateTime.now().day) % diseases.length];
      tasks.add(StudyTask(
        id: 'ref_${d.id}',
        title: 'Read up: ${d.name}',
        subtitle: 'Disease of the day · ${d.system.label}',
        icon: Icons.menu_book_rounded,
        accent: const Color(0xFF7DD3FC),
        route: Routes.disease(d.id),
        minutes: 4,
        kind: StudyTaskKind.reference,
        conceptIds: [d.conceptId],
        reason: 'Daily reference reading builds your clinical knowledge base',
      ));
    }

    // 6) Motivation — one Arena match to unlock today's reward.
    tasks.add(const StudyTask(
      id: 'arena',
      title: 'Win 1 Arena match',
      subtitle: 'Antibiotics vs. bacteria — unlock today\'s bonus',
      icon: Icons.sports_esports_rounded,
      accent: Color(0xFFFFB07A),
      route: Routes.arenaBattle,
      minutes: 3,
      kind: StudyTaskKind.motivation,
      reason: 'A quick game keeps the streak fun and rewarding',
    ));

    // ignore: unused_local_variable
    final _ = goalXp;
    return tasks;
  }

  LearnItem? _pickNew(ContentRepository repo, GameState game) {
    final items = repo.learnItems;
    for (final item in items) {
      if (item.conceptIds.isEmpty) continue;
      final allKnown = item.conceptIds.every((c) {
        final m = game.mastery[c];
        return m != null && m.attempts > 0;
      });
      if (!allKnown) return item;
    }
    return items.isNotEmpty ? items.first : null;
  }

  /// Mark a task complete (manual check or auto from activity).
  void markDone(String id) {
    if (state.completed.contains(id)) return;
    final next = {...state.completed, id};
    state = StudyPlan(tasks: state.tasks, completed: next, dateKey: state.dateKey);
    _persist();
  }

  void toggle(String id) {
    final next = {...state.completed};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = StudyPlan(tasks: state.tasks, completed: next, dateKey: state.dateKey);
    _persist();
  }

  /// "Swap task" — move a task to the end so a different one surfaces (35 §4).
  void swap(String id) {
    final idx = state.tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final list = [...state.tasks];
    final t = list.removeAt(idx);
    list.add(t);
    state = StudyPlan(tasks: list, completed: state.completed, dateKey: state.dateKey);
  }

  void _persist() {
    ref.read(sharedPreferencesProvider).writeJson(_key, {
      'date': state.dateKey,
      'ids': state.completed.toList(),
    });
  }

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }
}

final studyPlanProvider =
    NotifierProvider<StudyPlanNotifier, StudyPlan>(StudyPlanNotifier.new);

/// The single learner-model instance, exposed for Insights/Copilot (prompt 49).
final learnerModelProvider = Provider<LearnerModel>((ref) => const LearnerModel());

/// Per-concept predictions across the whole graph (used by Insights/heatmap).
final conceptPredictionsProvider = Provider<List<ConceptPrediction>>((ref) {
  final lm = ref.watch(learnerModelProvider);
  final mastery = ref.watch(masteryMapProvider);
  return lm.prioritize(mastery.values, limit: 1000);
});
