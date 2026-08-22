import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_motion/synapse_motion.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../brand/synapse_identity.dart';
import '../state/presentation_provider.dart';

class PresentationHost extends ConsumerStatefulWidget {
  const PresentationHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PresentationHost> createState() => _PresentationHostState();
}

class _PresentationHostState extends ConsumerState<PresentationHost>
    with WidgetsBindingObserver {
  PresentationSelection? _active;
  Timer? _settleTimer;
  bool _selectionScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = _active;
    if (active != null &&
        active.record.receipt.celebratory &&
        context.motionEnvironment.surface != MotionSurface.study) {
      _interruptActive();
      return;
    }
    _scheduleSelection();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _interruptActive();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settleTimer?.cancel();
    super.dispose();
  }

  void _scheduleSelection() {
    if (_active != null || _selectionScheduled) return;
    _selectionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectionScheduled = false;
      if (!mounted || _active != null) return;
      final controller = ref.read(presentationQueueProvider.notifier);
      final selection = controller.nextFor(context.motionEnvironment);
      if (selection == null) return;
      controller.start(selection.record.receipt.receiptId);
      setState(() => _active = selection);
      _settleTimer = Timer(_visibleDuration(selection), _finishActive);
    });
  }

  Duration _visibleDuration(PresentationSelection selection) {
    if (selection.decision.disposition == MotionDisposition.still) {
      return const Duration(milliseconds: 2200);
    }
    return switch (selection.record.receipt.tier) {
      MotionTier.micro => const Duration(milliseconds: 1500),
      MotionTier.standard => const Duration(milliseconds: 2600),
      MotionTier.milestone => const Duration(milliseconds: 3400),
      MotionTier.showpiece => const Duration(milliseconds: 4600),
      MotionTier.functional => const Duration(milliseconds: 1800),
    };
  }

  void _finishActive() {
    final active = _active;
    if (!mounted || active == null) return;
    _settleTimer?.cancel();
    ref.read(presentationQueueProvider.notifier).acknowledgeSelection(active);
    setState(() => _active = null);
    _scheduleSelection();
  }

  void _skipActive() {
    final active = _active;
    if (active == null) return;
    _settleTimer?.cancel();
    ref
        .read(presentationQueueProvider.notifier)
        .acknowledge(
          active.record.receipt.receiptId,
          PresentationStatus.skipped,
        );
    setState(() => _active = null);
    _scheduleSelection();
  }

  void _interruptActive() {
    final active = _active;
    if (active == null) return;
    _settleTimer?.cancel();
    ref
        .read(presentationQueueProvider.notifier)
        .acknowledge(
          active.record.receipt.receiptId,
          PresentationStatus.interrupted,
        );
    if (mounted) setState(() => _active = null);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(presentationQueueProvider);
    _scheduleSelection();
    final active = _active;
    return Stack(
      children: [
        widget.child,
        if (active != null) ...[
          Positioned.fill(
            child: SignalBurstOverlay(
              key: ValueKey(active.record.receipt.receiptId),
              receiptId: active.record.receipt.receiptId,
              play: true,
              tier: active.record.receipt.tier,
              color: const Color(0xFF20BDF2),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 16,
            left: 16,
            right: 16,
            child: Align(
              alignment: Alignment.topCenter,
              child: MotionReveal(
                key: ValueKey('card-${active.record.receipt.receiptId}'),
                tier: active.record.receipt.tier,
                celebratory: active.record.receipt.celebratory,
                offset: const Offset(0, -20),
                scaleFrom: 0.94,
                child: _PresentationReceiptCard(
                  receipt: active.record.receipt,
                  onSkip: _skipActive,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PresentationReceiptCard extends StatelessWidget {
  const _PresentationReceiptCard({required this.receipt, required this.onSkip});

  final PresentationReceipt receipt;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final xp = (receipt.payload['xpDelta'] as num?)?.toInt() ?? 0;
    final detail = _receiptDetail(receipt);
    return Semantics(
      liveRegion: true,
      container: true,
      excludeSemantics: true,
      label: [
        _receiptReason(receipt),
        _receiptTitle(receipt),
        ?detail,
      ].join('. '),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                t.primary.withValues(alpha: 0.08),
                t.surfaceHigh,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: t.primary.withValues(alpha: 0.48)),
              boxShadow: t.glow(t.primary, opacity: 0.24, blur: 32),
            ),
            child: Row(
              children: [
                const SynapseCompanion(
                  pose: SynapseCompanionPose.encouraging,
                  size: 66,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _receiptReason(receipt),
                        style: TextStyle(
                          color: t.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _receiptTitle(receipt),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (detail != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          '$detail${xp > 0 ? ' · saved to progress' : ''}',
                          style: TextStyle(color: t.textMuted, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onSkip,
                  tooltip: 'Dismiss reward presentation',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _receiptTitle(PresentationReceipt receipt) {
  final level = (receipt.payload['newLevel'] as num?)?.toInt();
  final achievements = _achievementPayloads(receipt);
  if (level != null && achievements.isNotEmpty) {
    return 'Level $level · ${achievements.first['title']} unlocked';
  }
  if (achievements.length == 1) {
    return 'Achievement unlocked: ${achievements.first['title']}';
  }
  if (achievements.length > 1) {
    return '${achievements.length} achievements unlocked';
  }
  if (level != null) return 'Level $level reached';
  final completedQuests = receipt.payload['completedQuestIds'];
  if (completedQuests is List && completedQuests.isNotEmpty) {
    return completedQuests.length == 1
        ? 'Quest complete'
        : '${completedQuests.length} quests complete';
  }
  final days = (receipt.payload['streakDays'] as num?)?.toInt();
  if (days != null) return '$days-day continuity';
  final xp = (receipt.payload['xpDelta'] as num?)?.toInt() ?? 0;
  final gems = (receipt.payload['gemsDelta'] as num?)?.toInt() ?? 0;
  if (xp > 0 && gems > 0) return '+$xp mastery XP · +$gems gems';
  if (xp > 0) return '+$xp mastery XP';
  return 'Progress saved';
}

String _receiptReason(PresentationReceipt receipt) =>
    switch (receipt.payload['reasonKey']) {
      'reward.achievement' => 'Achievement criteria met',
      'reward.quest-complete' => 'Quest goal completed',
      'reward.lesson' => 'Lesson evidence accepted',
      'reward.review' => 'Review evidence accepted',
      'reward.contribution' => 'Contribution accepted',
      'reward.correct' => 'Correct response recorded',
      'reward.win' => 'Challenge result accepted',
      'reward.streak' => 'Continuity evidence accepted',
      _ => 'Why this changed',
    };

String? _receiptDetail(PresentationReceipt receipt) {
  final achievements = _achievementPayloads(receipt);
  if (achievements.length == 1) {
    final description = achievements.first['description'];
    if (description != null && description.isNotEmpty) return description;
  }
  final total = (receipt.payload['totalXp'] as num?)?.toInt();
  return total == null ? null : '$total total XP';
}

List<Map<String, String>> _achievementPayloads(PresentationReceipt receipt) {
  final raw = receipt.payload['achievements'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) {
        final title = item['title']?.toString().trim();
        final description = item['description']?.toString().trim();
        return <String, String>{
          if (title != null && title.isNotEmpty) 'title': title,
          if (description != null && description.isNotEmpty)
            'description': description,
        };
      })
      .where((item) => item.containsKey('title'))
      .toList(growable: false);
}
