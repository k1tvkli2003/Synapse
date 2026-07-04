import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';
import '../../state/game_provider.dart';

final _accent = Color(ModuleKey.terms.accentHex);

class TermsHomeScreen extends ConsumerWidget {
  const TermsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(repositoryProvider).termsPaths;
    return ModuleScaffold(
      title: 'Terms',
      subtitle: ModuleKey.terms.tagline,
      accent: _accent,
      onCopilot: () => context.push(Routes.copilot),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(children: [HeartsRow(hearts: ref.watch(heartsProvider)), const Spacer()]),
          const SizedBox(height: 12),
          for (final p in paths) ...[
            _PathCard(path: p),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({required this.path});
  final CoursePath path;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      accent: _accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: _accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.school_rounded, color: _accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(path.title, style: Theme.of(context).textTheme.titleLarge),
                    if (path.description != null)
                      Text(path.description!, style: TextStyle(color: t.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final u in path.units) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 6),
              child: Text(u.title.toUpperCase(),
                  style: TextStyle(color: t.textFaint, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            ),
            for (final l in u.lessons)
              ListRow(
                title: l.title,
                subtitle: '${l.exercises.length} exercises · +${l.xpReward} XP',
                accent: _accent,
                leadingIcon: Icons.play_circle_fill_rounded,
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: () => context.push(Routes.termsLesson(l.id)),
              ),
          ],
        ],
      ),
    );
  }
}

/// The Duolingo-style lesson player, handling all eight exercise kinds.
class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({super.key, required this.lessonId});
  final String lessonId;
  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  Lesson? _lesson;
  int _index = 0;
  int _correct = 0;
  bool? _answeredCorrect;

  // Per-exercise transient input.
  int? _selected;
  final _textController = TextEditingController();
  final List<String> _assembled = [];
  final Map<String, String> _matched = {};
  String? _matchPending;

  @override
  void initState() {
    super.initState();
    _lesson = ref.read(repositoryProvider).termsPaths.expand((p) => p.units).expand((u) => u.lessons).firstWhere(
          (l) => l.id == widget.lessonId,
          orElse: () => const Lesson(id: 'x', title: 'Lesson', exercises: []),
        );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Exercise get _ex => _lesson!.exercises[_index];

  bool get _canCheck {
    if (_answeredCorrect != null) return true;
    switch (_ex.kind) {
      case ExerciseKind.multipleChoice:
      case ExerciseKind.reverseChoice:
      case ExerciseKind.listen:
      case ExerciseKind.trueFalse:
        return _selected != null;
      case ExerciseKind.typeAnswer:
      case ExerciseKind.fillBlank:
        return _textController.text.trim().isNotEmpty;
      case ExerciseKind.wordBank:
        return _assembled.isNotEmpty;
      case ExerciseKind.matchPairs:
        return _matched.length == _ex.pairs.length;
    }
  }

  void _check() {
    if (_answeredCorrect != null) {
      _advance();
      return;
    }
    bool correct;
    switch (_ex.kind) {
      case ExerciseKind.multipleChoice:
      case ExerciseKind.reverseChoice:
      case ExerciseKind.listen:
      case ExerciseKind.trueFalse:
        correct = _ex.isCorrect('${_selected ?? -1}');
      case ExerciseKind.typeAnswer:
      case ExerciseKind.fillBlank:
        correct = _ex.isCorrect(_textController.text);
      case ExerciseKind.wordBank:
        correct = _ex.isCorrect(_assembled.join(' '));
      case ExerciseKind.matchPairs:
        correct = _matched.entries.every((e) => _ex.pairs[e.key] == e.value);
    }
    setState(() => _answeredCorrect = correct);
    // Report the per-exercise outcome so concept mastery updates and a wrong
    // answer costs a heart + propagates a struggle across the app.
    ref.read(gameProvider.notifier).report(
          source: ModuleKey.terms,
          kind: RewardKind.correct,
          correct: correct,
          concepts: [if (_ex.conceptId != null) _ex.conceptId!],
          xp: correct ? 2 : 0,
          hearted: true,
        );
  }

  void _advance() {
    if (_answeredCorrect == true) _correct++;
    if (_index < _lesson!.exercises.length - 1) {
      setState(() {
        _index++;
        _answeredCorrect = null;
        _selected = null;
        _textController.clear();
        _assembled.clear();
        _matched.clear();
        _matchPending = null;
      });
    } else {
      _finish();
    }
  }

  void _finish() {
    final total = _lesson!.exercises.length;
    ref.read(gameProvider.notifier).completeLesson(
          source: ModuleKey.terms,
          correct: _correct,
          total: total,
          concepts: _lesson!.conceptIds,
          xp: _lesson!.xpReward,
        );
    ref.read(gameProvider.notifier).report(
          source: ModuleKey.terms,
          kind: RewardKind.lesson,
          correct: true,
          xp: 0,
          achievementMetric: 'terms.lesson',
        );
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResultDialog(correct: _correct, total: total, xp: _lesson!.xpReward),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_lesson == null || _lesson!.exercises.isEmpty) {
      return Scaffold(body: Center(child: Text('Lesson not found', style: TextStyle(color: t.textMuted))));
    }
    final ex = _ex;
    return DrillShell(
      accent: _accent,
      progress: _index / _lesson!.exercises.length,
      headerTrailing: HeartsRow(hearts: ref.watch(heartsProvider), size: 16),
      continueEnabled: _canCheck,
      continueLabel: _answeredCorrect == null ? 'Check' : 'Continue',
      onContinue: _check,
      feedback: _answeredCorrect == null
          ? null
          : QuizFeedbackBanner(
              correct: _answeredCorrect!,
              explanation: ex.explanation,
              onSeeConcept: ex.conceptId != null ? () => context.push(Routes.concept(ex.conceptId!)) : null,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          AppBadge(label: ex.kind.label, color: _accent, subtle: true),
          const SizedBox(height: 16),
          Text(ex.prompt, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          _buildBody(ex),
        ],
      ),
    );
  }

  Widget _buildBody(Exercise ex) {
    switch (ex.kind) {
      case ExerciseKind.multipleChoice:
      case ExerciseKind.reverseChoice:
      case ExerciseKind.listen:
      case ExerciseKind.trueFalse:
        return _choices(ex);
      case ExerciseKind.typeAnswer:
      case ExerciseKind.fillBlank:
        return _textInput(ex);
      case ExerciseKind.wordBank:
        return _wordBank(ex);
      case ExerciseKind.matchPairs:
        return _matchPairs(ex);
    }
  }

  Widget _choices(Exercise ex) {
    final t = context.tokens;
    final locked = _answeredCorrect != null;
    return Column(
      children: List.generate(ex.options.length, (i) {
        final selected = _selected == i;
        final isAnswer = i == ex.correctIndex;
        Color border = t.border;
        Color? fill;
        if (locked && isAnswer) {
          border = t.success;
          fill = t.success.withValues(alpha: 0.12);
        } else if (locked && selected && !isAnswer) {
          border = t.danger;
          fill = t.danger.withValues(alpha: 0.12);
        } else if (selected) {
          border = _accent;
          fill = _accent.withValues(alpha: 0.12);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: locked ? null : () => setState(() => _selected = i),
            child: AnimatedContainer(
              duration: t.motion.fast,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: fill ?? t.surface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: border, width: selected || (locked && isAnswer) ? 2 : 1),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(ex.options[i], style: Theme.of(context).textTheme.titleMedium)),
                  if (locked && isAnswer) Icon(Icons.check_circle_rounded, color: t.success, size: 20),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _textInput(Exercise ex) {
    return AppTextField(
      controller: _textController,
      autofocus: true,
      accent: _accent,
      hint: 'Type your answer',
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _canCheck ? _check() : null,
    );
  }

  Widget _wordBank(Exercise ex) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.surfaceAlt,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: t.border),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _assembled
                .asMap()
                .entries
                .map((e) => AppChip(
                      label: e.value,
                      selected: true,
                      accent: _accent,
                      onTap: _answeredCorrect != null ? null : () => setState(() => _assembled.removeAt(e.key)),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ex.tokens.map((tok) {
            final usedCount = _assembled.where((a) => a == tok).length;
            final availCount = ex.tokens.where((a) => a == tok).length;
            final disabled = usedCount >= availCount || _answeredCorrect != null;
            return Opacity(
              opacity: disabled ? 0.3 : 1,
              child: AppChip(
                label: tok,
                onTap: disabled ? null : () => setState(() => _assembled.add(tok)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _matchPairs(Exercise ex) {
    final terms = ex.pairs.keys.toList();
    final meanings = ex.pairs.values.toList()..sort();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: terms.map((term) {
              final done = _matched.containsKey(term);
              final pending = _matchPending == term;
              return _matchTile(term, done, pending, () {
                if (done || _answeredCorrect != null) return;
                setState(() => _matchPending = term);
              });
            }).toList(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: meanings.map((meaning) {
              final done = _matched.containsValue(meaning);
              return _matchTile(meaning, done, false, () {
                if (done || _matchPending == null || _answeredCorrect != null) return;
                setState(() {
                  _matched[_matchPending!] = meaning;
                  _matchPending = null;
                });
              });
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _matchTile(String label, bool done, bool pending, VoidCallback onTap) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: done ? t.success.withValues(alpha: 0.12) : (pending ? _accent.withValues(alpha: 0.16) : t.surface),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: done ? t.success : (pending ? _accent : t.border)),
          ),
          child: Text(label, style: TextStyle(color: done ? t.textMuted : t.text, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({required this.correct, required this.total, required this.xp});
  final int correct;
  final int total;
  final int xp;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pct = total == 0 ? 0 : (correct / total * 100).round();
    return Dialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events_rounded, size: 56, color: _accent),
                const SizedBox(height: 12),
                Text('Lesson complete!', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('$correct / $total correct ($pct%)', style: TextStyle(color: t.textMuted)),
                const SizedBox(height: 4),
                Text('+$xp XP', style: TextStyle(color: t.success, fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 20),
                AppButton(
                  label: 'Done',
                  expand: true,
                  accent: _accent,
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).maybePop();
                  },
                ),
              ],
            ),
          ),
          const Positioned.fill(child: IgnorePointer(child: ConfettiOverlay(play: true))),
        ],
      ),
    );
  }
}
