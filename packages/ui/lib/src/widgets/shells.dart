import 'package:flutter/material.dart';

import '../responsive/adaptive.dart';
import '../theme/tokens.dart';
import 'atoms.dart';

/// The disclaimer required on every clinical surface (golden rule #4).
class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key, this.compact = false});
  final bool compact;

  static const text =
      'For educational training only — not for real clinical decision making.';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 7 : 10),
      decoration: BoxDecoration(
        color: t.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 15, color: t.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: t.warning,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The standard screen frame every module is built on (prompt 30 §2). Accent
/// app bar, optional Copilot FAB, optional disclaimer, centred max-width body.
class ModuleScaffold extends StatelessWidget {
  const ModuleScaffold({
    super.key,
    required this.title,
    required this.body,
    this.accent,
    this.subtitle,
    this.actions,
    this.showDisclaimer = false,
    this.onCopilot,
    this.floatingActionButton,
    this.bottom,
    this.leading,
    this.scrollable = false,
    this.padded = true,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final Color? accent;
  final List<Widget>? actions;
  final bool showDisclaimer;
  final VoidCallback? onCopilot;
  final Widget? floatingActionButton;
  final Widget? bottom;
  final Widget? leading;
  final bool scrollable;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = accent ?? t.primary;

    Widget content = body;
    if (padded) {
      content = Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.isCompactPad ? 16 : 24,
        ),
        child: content,
      );
    }
    if (scrollable) {
      content = SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: content,
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(subtitle != null ? 70 : 58),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [a.withValues(alpha: 0.14), t.bg.withValues(alpha: 0)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  leading ?? const _AdaptiveBack(),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  ...?actions,
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (showDisclaimer)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: DisclaimerBanner(compact: true),
            ),
          Expanded(child: ContentBounds(child: content)),
          ?bottom,
        ],
      ),
      floatingActionButton:
          floatingActionButton ??
          (onCopilot != null
              ? FloatingCopilotButton(onPressed: onCopilot!)
              : null),
    );
  }
}

class _AdaptiveBack extends StatelessWidget {
  const _AdaptiveBack();

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    if (!canPop) return const SizedBox(width: 8);
    return AppIconButton(
      icon: Icons.arrow_back_rounded,
      onPressed: () => Navigator.of(context).maybePop(),
      tooltip: 'Back',
    );
  }
}

extension on BuildContext {
  bool get isCompactPad => MediaQuery.sizeOf(this).width < 600;
}

/// The global, omnipresent Copilot action (prompt 07 §2 / 32).
class FloatingCopilotButton extends StatelessWidget {
  const FloatingCopilotButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFB794F6);
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: accent,
      foregroundColor: const Color(0xFF080B1C),
      tooltip: 'Ask Copilot',
      child: const Icon(Icons.auto_awesome_rounded),
    );
  }
}

/// The single quiz/drill scaffold (prompt 30 §2): progress on top → content →
/// feedback banner → one Continue button. Identical rhythm across ECG, Terms,
/// Sounds, Labs and the OR simulator.
class DrillShell extends StatelessWidget {
  const DrillShell({
    super.key,
    required this.progress,
    required this.child,
    required this.onContinue,
    this.continueLabel = 'Continue',
    this.feedback,
    this.accent,
    this.onClose,
    this.headerTrailing,
    this.continueEnabled = true,
  });

  final double progress; // 0..1
  final Widget child;
  final VoidCallback? onContinue;
  final String continueLabel;
  final Widget? feedback;
  final Color? accent;
  final VoidCallback? onClose;
  final Widget? headerTrailing;
  final bool continueEnabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = accent ?? t.primary;
    return Scaffold(
      body: SafeArea(
        child: ContentBounds(
          maxWidth: 760,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                child: Row(
                  children: [
                    AppIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Close',
                      onPressed:
                          onClose ?? () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 12,
                          backgroundColor: t.surfaceHigh,
                          valueColor: AlwaysStoppedAnimation(a),
                        ),
                      ),
                    ),
                    if (headerTrailing != null) ...[
                      const SizedBox(width: 12),
                      headerTrailing!,
                    ],
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: child,
                ),
              ),
              ?feedback,
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: AppButton(
                  label: continueLabel,
                  expand: true,
                  accent: a,
                  onPressed: continueEnabled ? onContinue : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shared feedback banner shown after answering in any drill (prompt 30 §2).
class QuizFeedbackBanner extends StatelessWidget {
  const QuizFeedbackBanner({
    super.key,
    required this.correct,
    this.title,
    this.explanation,
    this.onSeeConcept,
  });

  final bool correct;
  final String? title;
  final String? explanation;
  final VoidCallback? onSeeConcept;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = correct ? t.success : t.danger;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: c,
              ),
              const SizedBox(width: 8),
              Text(
                title ?? (correct ? 'Correct!' : 'Not quite'),
                style: TextStyle(
                  color: c,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (onSeeConcept != null)
                TextButton(
                  onPressed: onSeeConcept,
                  child: Text(
                    'See concept',
                    style: TextStyle(color: c, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          if (explanation != null) ...[
            const SizedBox(height: 6),
            Text(explanation!, style: TextStyle(color: t.text, height: 1.45)),
          ],
        ],
      ),
    );
  }
}
