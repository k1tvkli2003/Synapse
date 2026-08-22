import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'atoms.dart';

/// The one empty-state treatment (prompt 30 §3): centred icon + headline + body
/// + a single CTA. Never a blank area.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = accent ?? t.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: a.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: a),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: t.textMuted),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                accent: a,
                size: AppButtonSize.medium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The one error treatment (prompt 30 §3): banner + retry.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.danger.withValues(alpha: 0.12),
        borderRadius: t.radii.cardR,
        border: Border.all(color: t.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: t.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: TextStyle(color: t.text)),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: TextStyle(color: t.danger, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

/// A slim offline banner (prompt 30 §3 offline pattern).
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      color: t.warning.withValues(alpha: 0.16),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 15, color: t.warning),
          const SizedBox(width: 8),
          Text(
            'Offline — your progress will sync later',
            style: TextStyle(
              color: t.warning,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A column of shimmer rows — the standard list loading state.
class LoadingList extends StatelessWidget {
  const LoadingList({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const Row(
        children: [
          Shimmer(width: 42, height: 42, radius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shimmer(height: 14, width: 180),
                SizedBox(height: 8),
                Shimmer(height: 12, width: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
