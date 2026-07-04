import 'package:flutter/material.dart';
import 'package:synapse_core/synapse_core.dart';

import '../theme/tokens.dart';
import 'atoms.dart';
import 'containers.dart';

/// A small badge for a content item's [ReviewStatus] (prompt 50 §1/§4). Makes
/// "established fact" vs "community / unverified" visible at a glance.
class ReviewBadge extends StatelessWidget {
  const ReviewBadge({super.key, required this.review, this.evidence});
  final ReviewState review;
  final Evidence? evidence;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (color, icon, label) = switch (review.status) {
      ReviewStatus.approved => (t.success, Icons.verified_rounded, 'Reviewed'),
      ReviewStatus.inReview => (t.info, Icons.hourglass_top_rounded, 'In review'),
      ReviewStatus.draft => (t.textMuted, Icons.edit_note_rounded, 'Draft'),
      ReviewStatus.needsUpdate => (t.warning, Icons.update_rounded, 'Update due'),
      ReviewStatus.deprecated => (t.danger, Icons.block_rounded, 'Deprecated'),
    };
    final unverified = evidence != null && evidence!.isUnverified;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _pill(t, color, icon, review.communityContributed ? 'Community' : label),
        if (unverified) _pill(t, t.warning, Icons.report_problem_rounded, 'Unverified'),
        if (evidence?.levelOfEvidence != null)
          _pill(t, t.info, Icons.school_rounded, evidence!.levelOfEvidence!.label),
      ],
    );
  }

  Widget _pill(SynapseTokens t, Color c, IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: c.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// The user-facing trust footer on every reference page (prompt 50 §4):
/// sources, last-reviewed date, evidence level + a "Report an error" action.
class SourcesFooter extends StatelessWidget {
  const SourcesFooter({super.key, required this.evidence, required this.review, this.onReport});
  final Evidence evidence;
  final ReviewState review;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      color: t.surfaceAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.menu_book_rounded, size: 16, color: t.textMuted),
            const SizedBox(width: 8),
            Text('Sources & evidence', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            ReviewBadge(review: review, evidence: evidence),
          ]),
          const SizedBox(height: 12),
          if (evidence.citations.isEmpty)
            Text('No citations attached — treat as unverified.',
                style: TextStyle(color: t.warning, fontSize: 12.5))
          else
            ...evidence.citations.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.circle, size: 6, color: t.textFaint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: c.title, style: TextStyle(color: t.text, fontWeight: FontWeight.w600, fontSize: 12.5)),
                        TextSpan(text: '  ${c.short} · ${c.type.label}', style: TextStyle(color: t.textMuted, fontSize: 12)),
                      ])),
                    ),
                  ]),
                )),
          if (evidence.lastReviewed != null) ...[
            const SizedBox(height: 4),
            Text('Last reviewed ${_date(evidence.lastReviewed!)}', style: TextStyle(color: t.textFaint, fontSize: 11.5)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            TextButton.icon(
              onPressed: onReport,
              icon: Icon(Icons.flag_outlined, size: 16, color: t.textMuted),
              label: Text('Report an error', style: TextStyle(color: t.textMuted, fontWeight: FontWeight.w600)),
            ),
          ]),
        ],
      ),
    );
  }

  String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

/// A horizontal rail of tappable "related" chips for cross-linking reference
/// pages to drugs, diseases, cases, ECGs, etc. (prompt 45/46 §3).
class RelatedRail extends StatelessWidget {
  const RelatedRail({super.key, required this.title, required this.chips, this.icon});
  final String title;
  final List<RelatedChip> chips;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          if (icon != null) ...[Icon(icon, size: 15, color: t.textMuted), const SizedBox(width: 6)],
          Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: t.textMuted)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in chips)
            AppChip(label: c.label, icon: c.icon, accent: c.accent, onTap: c.onTap),
        ]),
      ],
    );
  }
}

class RelatedChip {
  const RelatedChip({required this.label, this.icon, this.accent, this.onTap});
  final String label;
  final IconData? icon;
  final Color? accent;
  final VoidCallback? onTap;
}
