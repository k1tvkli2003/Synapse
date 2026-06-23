import 'package:flutter/material.dart';
import 'package:synapse_ui/synapse_ui.dart';

/// A small mastery ring used on reference pages to tie a concept to its score.
class ConceptMasteryRing extends StatelessWidget {
  const ConceptMasteryRing({super.key, required this.value, this.accent});
  final double value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ProgressRing(
      value: value,
      size: 52,
      stroke: 5,
      color: accent ?? t.primary,
      child: Text('${(value * 100).round()}%',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: t.text)),
    );
  }
}

/// A collapsible reference section (prompt 45 §3): a titled, expandable block.
class RefSection extends StatefulWidget {
  const RefSection({super.key, required this.title, required this.body}) : child = null;
  const RefSection.custom({super.key, required this.title, required this.child}) : body = null;

  final String title;
  final String? body;
  final Widget? child;

  @override
  State<RefSection> createState() => _RefSectionState();
}

class _RefSectionState extends State<RefSection> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleSmall)),
                Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: t.textMuted),
              ]),
            ),
          ),
          AnimatedCrossFade(
            duration: t.motion.base,
            crossFadeState: _open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: widget.body != null
                  ? Text(widget.body!, style: TextStyle(color: t.text, height: 1.5))
                  : widget.child!,
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ]),
      ),
    );
  }
}

/// A bullet-list reference section.
class RefBulletSection extends StatelessWidget {
  const RefBulletSection({super.key, required this.title, required this.items});
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return RefSection.custom(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final i in items) _Bullet(i)],
      ),
    );
  }
}

/// A small labelled sub-list inside a custom section.
class RefMiniList extends StatelessWidget {
  const RefMiniList({super.key, required this.label, required this.items});
  final String label;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: t.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        for (final i in items) _Bullet(i),
      ]),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 7, right: 8),
          child: Icon(Icons.circle, size: 5, color: t.textFaint),
        ),
        Expanded(child: Text(text, style: TextStyle(color: t.text, height: 1.4))),
      ]),
    );
  }
}

/// A prominent red-flags card (prompt 45 §1 redFlags).
class RedFlagsCard extends StatelessWidget {
  const RedFlagsCard({super.key, required this.flags});
  final List<String> flags;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      color: t.danger.withValues(alpha: 0.08),
      accent: t.danger,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded, color: t.danger, size: 18),
          const SizedBox(width: 8),
          Text('Red flags', style: TextStyle(color: t.danger, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        for (final f in flags)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: Icon(Icons.circle, size: 5, color: t.danger)),
              Expanded(child: Text(f, style: TextStyle(color: t.text, height: 1.4))),
            ]),
          ),
      ]),
    );
  }
}

/// A high-yield "pearls" card.
class HighYieldCard extends StatelessWidget {
  const HighYieldCard({super.key, required this.points, this.accent});
  final List<String> points;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = accent ?? t.warning;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: AppCard(
        color: a.withValues(alpha: 0.08),
        accent: a,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.lightbulb_rounded, color: a, size: 18),
            const SizedBox(width: 8),
            Text('High-yield', style: TextStyle(color: a, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          for (final p in points)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: Icon(Icons.star_rounded, size: 11, color: a)),
                Expanded(child: Text(p, style: TextStyle(color: t.text, height: 1.4))),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// The "Report an error" triage sheet (prompt 50 §4).
void showReportSheet(BuildContext context, String subject) {
  showAppSheet<void>(
    context,
    builder: (context) {
      final t = context.tokens;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Report an error', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Flag a problem with "$subject" for clinical review.', style: TextStyle(color: t.textMuted)),
          const SizedBox(height: 14),
          const AppTextField(label: 'What looks wrong?', hint: 'e.g. outdated dose, missing contraindication', maxLines: 3),
          const SizedBox(height: 16),
          AppButton(
            label: 'Submit to review queue', expand: true,
            onPressed: () {
              Navigator.of(context).maybePop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thanks — sent to the clinical review queue'), behavior: SnackBarBehavior.floating),
              );
            },
          ),
        ]),
      );
    },
  );
}
