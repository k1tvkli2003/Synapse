import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';
import '../../state/audio_provider.dart';
import '../../state/game_provider.dart';

final _accent = Color(ModuleKey.sounds.accentHex);

class SoundsHomeScreen extends ConsumerWidget {
  const SoundsHomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sounds = ref.watch(repositoryProvider).sounds;
    final heart = sounds.where((s) => s.kind == SoundKind.heart).toList();
    final lung = sounds.where((s) => s.kind == SoundKind.lung).toList();
    return ModuleScaffold(
      title: 'Sounds',
      subtitle: ModuleKey.sounds.tagline,
      accent: _accent,
      showDisclaimer: true,
      onCopilot: () => context.push(Routes.copilot),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          AppButton(label: 'Start quiz', icon: Icons.quiz_rounded, expand: true, accent: _accent, onPressed: () => context.push(Routes.soundsQuiz)),
          const SizedBox(height: 20),
          SectionHeader(title: 'Heart', icon: Icons.favorite_rounded),
          ...heart.map((s) => _SoundRow(sound: s)),
          const SizedBox(height: 20),
          SectionHeader(title: 'Lung', icon: Icons.air_rounded),
          ...lung.map((s) => _SoundRow(sound: s)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SoundRow extends StatelessWidget {
  const _SoundRow({required this.sound});
  final BodySound sound;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListRow(
        title: sound.name,
        subtitle: sound.location,
        accent: _accent,
        leadingIcon: Icons.graphic_eq_rounded,
        trailing: const Icon(Icons.chevron_right_rounded, size: 18),
        onTap: () => context.push(Routes.sound(sound.id)),
      ),
    );
  }
}

class SoundDetailScreen extends ConsumerWidget {
  const SoundDetailScreen({super.key, required this.soundId});
  final String soundId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    final s = repo.sounds.firstWhere((x) => x.id == soundId, orElse: () => repo.sounds.first);
    final audio = ref.watch(audioProvider);
    final playing = audio.sourceId == s.id;

    return ModuleScaffold(
      title: s.name,
      subtitle: s.kind == SoundKind.heart ? 'Heart sound' : 'Lung sound',
      accent: _accent,
      showDisclaimer: true,
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          AppCard(
            feature: true,
            accent: _accent,
            child: Column(
              children: [
                Waveform(seed: s.id.hashCode, progress: playing ? (audio.duration.inMilliseconds == 0 ? 0 : audio.position.inMilliseconds / audio.duration.inMilliseconds) : 0, color: _accent, height: 72),
                const SizedBox(height: 16),
                AppButton(
                  label: playing && audio.isPlaying ? 'Pause' : 'Play sound',
                  icon: playing && audio.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  accent: _accent,
                  onPressed: () {
                    if (playing) {
                      ref.read(audioProvider.notifier).toggle();
                    } else {
                      ref.read(audioProvider.notifier).load(
                            sourceId: s.id,
                            title: s.name,
                            subtitle: s.location,
                            duration: const Duration(seconds: 8),
                            accentHex: _accent.toARGB32(),
                          );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (s.description != null) AppCard(child: Text(s.description!, style: TextStyle(color: t.text, height: 1.5))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (s.location != null) AppChip(label: s.location!, icon: Icons.place_rounded, accent: _accent),
              if (s.timingHint != null) AppChip(label: s.timingHint!, icon: Icons.schedule_rounded, accent: _accent),
              if (s.conceptId != null) AppChip(label: 'See concept', icon: Icons.hub_rounded, onTap: () => context.push(Routes.concept(s.conceptId!))),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class SoundsQuizScreen extends ConsumerStatefulWidget {
  const SoundsQuizScreen({super.key});
  @override
  ConsumerState<SoundsQuizScreen> createState() => _SoundsQuizScreenState();
}

class _SoundsQuizScreenState extends ConsumerState<SoundsQuizScreen> {
  late List<BodySound> _items;
  int _index = 0;
  int? _selected;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _items = [...ref.read(repositoryProvider).sounds]..shuffle();
  }

  void _check() {
    if (_answered) {
      _next();
      return;
    }
    if (_selected == null) return;
    final s = _items[_index];
    final correct = _selected == s.correctIndex;
    setState(() => _answered = true);
    ref.read(gameProvider.notifier).report(
          source: ModuleKey.sounds,
          kind: RewardKind.correct,
          correct: correct,
          concepts: [if (s.conceptId != null) s.conceptId!],
          xp: correct ? 8 : 0,
          firstTry: correct,
          hearted: true,
          achievementMetric: correct ? 'sounds.correct' : '',
        );
  }

  void _next() {
    if (_index < _items.length - 1) {
      setState(() {
        _index++;
        _selected = null;
        _answered = false;
      });
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = _items[_index];
    return DrillShell(
      accent: _accent,
      progress: _index / _items.length,
      headerTrailing: HeartsRow(hearts: ref.watch(heartsProvider), size: 16),
      continueEnabled: _selected != null,
      continueLabel: _answered ? (_index < _items.length - 1 ? 'Next' : 'Finish') : 'Check',
      onContinue: _check,
      feedback: _answered
          ? QuizFeedbackBanner(
              correct: _selected == s.correctIndex,
              title: _selected == s.correctIndex ? 'Correct' : 'It was ${s.options[s.correctIndex]}',
              explanation: s.description,
              onSeeConcept: s.conceptId != null ? () => context.push(Routes.concept(s.conceptId!)) : null,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text('Identify this ${s.kind == SoundKind.heart ? 'heart' : 'lung'} sound', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          AppCard(
            accent: _accent,
            child: Column(
              children: [
                Waveform(seed: s.id.hashCode, color: _accent, height: 64),
                const SizedBox(height: 8),
                Text('▶ Tap to imagine the auscultation', style: TextStyle(color: t.textFaint, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(s.options.length, (i) {
            final selected = _selected == i;
            final isAnswer = i == s.correctIndex;
            Color border = t.border;
            Color? fill;
            if (_answered && isAnswer) {
              border = t.success;
              fill = t.success.withValues(alpha: 0.12);
            } else if (_answered && selected && !isAnswer) {
              border = t.danger;
              fill = t.danger.withValues(alpha: 0.12);
            } else if (selected) {
              border = _accent;
              fill = _accent.withValues(alpha: 0.12);
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: _answered ? null : () => setState(() => _selected = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: fill ?? t.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border, width: selected || (_answered && isAnswer) ? 2 : 1),
                  ),
                  child: Text(s.options[i], style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
