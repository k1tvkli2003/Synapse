import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../state/srs_provider.dart';

/// One review surface for the mixed due queue across origins (prompt 22).
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});
  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late List<SrsCard> _queue;
  int _index = 0;
  bool _revealed = false;
  int _done = 0;

  @override
  void initState() {
    super.initState();
    _queue = ref.read(srsProvider.notifier).dueQueue;
  }

  void _grade(ReviewGrade grade) {
    final card = _queue[_index];
    ref.read(srsProvider.notifier).grade(card.id, grade);
    setState(() {
      _done++;
      _revealed = false;
      if (_index < _queue.length - 1) {
        _index++;
      } else {
        _index = _queue.length; // finished
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Daily Review')),
        body: EmptyState(
          icon: Icons.check_circle_rounded,
          title: 'All caught up!',
          message: 'No reviews are due right now. Come back later or study ahead in Cards.',
          actionLabel: 'Done',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    if (_index >= _queue.length) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                EmptyState(
                  icon: Icons.emoji_events_rounded,
                  title: 'Review complete!',
                  message: 'You reviewed $_done item(s). Spaced repetition keeps them sticky.',
                  actionLabel: 'Finish',
                  onAction: () => Navigator.of(context).maybePop(),
                ),
                const Positioned.fill(child: ConfettiOverlay(play: true)),
              ],
            ),
          ),
        ),
      );
    }

    final card = _queue[_index];
    return DrillShell(
      progress: _done / _queue.length,
      onClose: () => Navigator.of(context).maybePop(),
      headerTrailing: Text('${_index + 1}/${_queue.length}',
          style: TextStyle(color: t.textMuted, fontWeight: FontWeight.w600)),
      continueLabel: _revealed ? 'Hide' : 'Show answer',
      onContinue: () => setState(() => _revealed = !_revealed),
      feedback: _revealed ? _GradeBar(onGrade: _grade) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(child: AppBadge(label: _originLabel(card.origin), subtle: true)),
          const SizedBox(height: 24),
          AppCard(
            feature: true,
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Text('Front', style: TextStyle(color: t.textFaint, fontSize: 12, letterSpacing: 1)),
                const SizedBox(height: 12),
                Text(card.front,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                if (_revealed) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Divider(color: t.border),
                  ),
                  Text('Back', style: TextStyle(color: t.textFaint, fontSize: 12, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Text(card.back,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: t.success)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _originLabel(SrsOrigin o) => switch (o) {
        SrsOrigin.terms => 'Terms',
        SrsOrigin.cards => 'Cards',
        SrsOrigin.mnemonics => 'Mnemonics',
      };
}

class _GradeBar extends StatelessWidget {
  const _GradeBar({required this.onGrade});
  final void Function(ReviewGrade) onGrade;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final grades = [
      (ReviewGrade.again, t.danger, 'Again'),
      (ReviewGrade.hard, t.warning, 'Hard'),
      (ReviewGrade.good, t.success, 'Good'),
      (ReviewGrade.easy, t.info, 'Easy'),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: t.surfaceHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: grades
            .map((g) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => onGrade(g.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: g.$2.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: g.$2.withValues(alpha: 0.5)),
                        ),
                        child: Center(
                          child: Text(g.$3,
                              style: TextStyle(color: g.$2, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
