import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/game_provider.dart';

final _accent = Color(ModuleKey.arena.accentHex);

class ArenaHubScreen extends ConsumerWidget {
  const ArenaHubScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return ModuleScaffold(
      title: 'Arena',
      subtitle: ModuleKey.arena.tagline,
      accent: _accent,
      onCopilot: () => context.push(Routes.copilot),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          AppCard(
            feature: true,
            accent: _accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.coronavirus_rounded, color: _accent, size: 28),
                    const SizedBox(width: 10),
                    Text('Antibiotic Arena', style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Deploy the right antibiotic against each pathogen. Broad-spectrum is flexible; '
                    'narrow agents hit their target gram type harder. Match the bug to win.',
                    style: TextStyle(color: t.textMuted, height: 1.4)),
                const SizedBox(height: 16),
                AppButton(label: 'Battle', icon: Icons.sports_esports_rounded, expand: true, accent: _accent, onPressed: () => context.push(Routes.arenaBattle)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Your collection'),
          ...ArenaSeed.cards.take(6).map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CardRow(card: c),
              )),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.card});
  final UnitCard card;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      onTap: card.conceptId != null ? () => context.push(Routes.concept(card.conceptId!)) : null,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: _spectrumColor(card.spectrum).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.medication_rounded, color: _spectrumColor(card.spectrum), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.name, style: Theme.of(context).textTheme.titleSmall),
                Text(card.drugClass, style: TextStyle(color: t.textMuted, fontSize: 12)),
              ],
            ),
          ),
          _stat(Icons.bolt_rounded, '${card.cost}', t.info),
          const SizedBox(width: 10),
          _stat(Icons.local_fire_department_rounded, '${card.damage}', t.danger),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String v, Color c) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: c), const SizedBox(width: 2), Text(v, style: TextStyle(color: c, fontWeight: FontWeight.w700))]);
}

Color _spectrumColor(Spectrum s) => switch (s) {
      Spectrum.gramPositive => const Color(0xFF8E9BFF),
      Spectrum.gramNegative => const Color(0xFFFF8A8A),
      Spectrum.broad => const Color(0xFF7BE0A3),
    };

String _spectrumLabel(Spectrum s) => switch (s) {
      Spectrum.gramPositive => 'Gram +',
      Spectrum.gramNegative => 'Gram −',
      Spectrum.broad => 'Broad',
    };

class ArenaBattleScreen extends ConsumerStatefulWidget {
  const ArenaBattleScreen({super.key});
  @override
  ConsumerState<ArenaBattleScreen> createState() => _ArenaBattleScreenState();
}

class _ArenaBattleScreenState extends ConsumerState<ArenaBattleScreen> {
  Timer? _timer;
  late List<BacteriaUnit> _wave;
  late List<UnitCard> _hand;
  int _waveIndex = 0;
  int _enemyHp = 0;
  double _approach = 0; // 0..1 (reaches base at 1)
  double _mana = 5;
  int _baseHp = 5;
  String? _result; // 'win' | 'lose'
  String _flash = '';

  @override
  void initState() {
    super.initState();
    _wave = [...ArenaSeed.bacteria]..shuffle();
    _wave = _wave.take(4).toList();
    _hand = [...ArenaSeed.cards]..shuffle();
    _hand = _hand.take(5).toList();
    _enemyHp = _wave.first.hp;
    _start();
  }

  void _start() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_result != null) return;
      setState(() {
        _mana = (_mana + 0.05).clamp(0, 10);
        _approach += 0.0025 * _wave[_waveIndex].speed;
        if (_approach >= 1) {
          _baseHp--;
          _approach = 0;
          _flash = 'The ${_wave[_waveIndex].name} breached your defenses!';
          if (_baseHp <= 0) _end('lose');
        }
      });
    });
  }

  void _deploy(UnitCard card) {
    if (_result != null || _mana < card.cost) return;
    final enemy = _wave[_waveIndex];
    final dmg = (card.damage * card.effectivenessVs(enemy.spectrum)).round();
    final resisted = enemy.resistsClasses.contains(card.drugClass);
    final realDmg = resisted ? 1 : dmg;
    setState(() {
      _mana -= card.cost;
      _enemyHp -= realDmg;
      _flash = resisted
          ? '${enemy.name} resists ${card.drugClass}!'
          : (card.effectivenessVs(enemy.spectrum) >= 1.5 ? 'Super effective! −$realDmg' : '−$realDmg');
      if (_enemyHp <= 0) _nextEnemy();
    });
  }

  void _nextEnemy() {
    if (_waveIndex < _wave.length - 1) {
      _waveIndex++;
      _enemyHp = _wave[_waveIndex].hp;
      _approach = 0;
      _mana = (_mana + 2).clamp(0, 10);
    } else {
      _end('win');
    }
  }

  void _end(String result) {
    _timer?.cancel();
    setState(() => _result = result);
    if (result == 'win') {
      ref.read(gameProvider.notifier).report(
            source: ModuleKey.arena,
            kind: RewardKind.win,
            correct: true,
            xp: 30,
            gems: 8,
            concepts: const ['c_beta_lactam', 'c_gram_stain'],
            achievementMetric: 'arena.win',
          );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (_result != null) {
      final win = _result == 'win';
      return Scaffold(
        body: SafeArea(
          child: Stack(
            alignment: Alignment.center,
            children: [
              EmptyState(
                icon: win ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                title: win ? 'Victory!' : 'Defeated',
                message: win
                    ? 'You cleared the ward of pathogens. +30 XP, +8 gems.'
                    : 'The pathogens broke through. Match spectrum to bug and try again.',
                accent: win ? t.success : t.danger,
                actionLabel: 'Back to Arena',
                onAction: () => Navigator.of(context).maybePop(),
              ),
              if (win) const Positioned.fill(child: ConfettiOverlay(play: true)),
            ],
          ),
        ),
      );
    }

    final enemy = _wave[_waveIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text('Wave ${_waveIndex + 1}/${_wave.length}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(children: [
              for (var i = 0; i < 5; i++)
                Icon(i < _baseHp ? Icons.shield_rounded : Icons.shield_outlined, size: 18, color: i < _baseHp ? t.success : t.textFaint),
            ]),
          ),
        ],
      ),
      body: SafeArea(
        child: ContentBounds(
          maxWidth: 720,
          child: Column(
            children: [
              const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: DisclaimerBanner(compact: true)),
              Expanded(
                child: Stack(
                  children: [
                    // Base on the left.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.local_hospital_rounded, color: t.success, size: 40),
                          Text('Patient', style: TextStyle(color: t.textMuted, fontSize: 11)),
                        ]),
                      ),
                    ),
                    // Enemy approaching.
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 100),
                      alignment: Alignment(1 - _approach * 1.8, 0),
                      child: _EnemyChip(enemy: enemy, hp: _enemyHp),
                    ),
                    if (_flash.isNotEmpty)
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: AppBadge(label: _flash, color: _accent, subtle: true),
                        ),
                      ),
                  ],
                ),
              ),
              // Mana bar.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: t.info),
                    const SizedBox(width: 8),
                    Expanded(child: AppProgressBar(value: _mana / 10, color: t.info, height: 10)),
                    const SizedBox(width: 8),
                    Text('${_mana.floor()}', style: TextStyle(color: t.info, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              // Hand.
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _hand.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _HandCard(card: _hand[i], mana: _mana, onTap: () => _deploy(_hand[i])),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnemyChip extends StatelessWidget {
  const _EnemyChip({required this.enemy, required this.hp});
  final BacteriaUnit enemy;
  final int hp;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = _spectrumColor(enemy.spectrum);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.18), shape: BoxShape.circle, border: Border.all(color: c)),
          child: Icon(Icons.coronavirus_rounded, color: c, size: 34),
        ),
        const SizedBox(height: 4),
        Text(enemy.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        Text('${_spectrumLabel(enemy.spectrum)} · HP $hp', style: TextStyle(color: t.textMuted, fontSize: 11)),
      ],
    );
  }
}

class _HandCard extends StatelessWidget {
  const _HandCard({required this.card, required this.mana, required this.onTap});
  final UnitCard card;
  final double mana;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final affordable = mana >= card.cost;
    final c = _spectrumColor(card.spectrum);
    return Opacity(
      opacity: affordable ? 1 : 0.45,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 104,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 13, color: t.info),
                  Text('${card.cost}', style: TextStyle(color: t.info, fontWeight: FontWeight.w800, fontSize: 12)),
                  const Spacer(),
                  Icon(Icons.local_fire_department_rounded, size: 13, color: t.danger),
                  Text('${card.damage}', style: TextStyle(color: t.danger, fontWeight: FontWeight.w800, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              Icon(Icons.medication_rounded, color: c, size: 22),
              const SizedBox(height: 4),
              Text(card.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(_spectrumLabel(card.spectrum), style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
