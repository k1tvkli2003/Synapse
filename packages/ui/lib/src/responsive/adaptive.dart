import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'breakpoints.dart';

/// Builds different widget trees per breakpoint.
class AdaptiveLayout extends StatelessWidget {
  const AdaptiveLayout({super.key, required this.builder});

  final Widget Function(BuildContext context, Breakpoint bp) builder;

  @override
  Widget build(BuildContext context) => builder(context, context.bp);
}

/// Centres content with a comfortable max width on large screens (style §7).
class ContentBounds extends StatelessWidget {
  const ContentBounds({super.key, required this.child, this.maxWidth = 1100});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Master–detail scaffold (prompt 03 §3 / 30 §7). On `large`+ it shows the list
/// and detail side by side; on smaller screens it shows only the master and the
/// caller pushes the detail as a route.
class TwoPaneScaffold extends StatelessWidget {
  const TwoPaneScaffold({
    super.key,
    required this.master,
    this.detail,
    this.masterWidth = 380,
    this.placeholder,
  });

  final Widget master;
  final Widget? detail;
  final double masterWidth;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (!context.bp.isWide) return master;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: masterWidth, child: master),
        VerticalDivider(width: 1, color: t.border),
        Expanded(
          child: detail ??
              placeholder ??
              Center(
                child: Text(
                  'Select an item',
                  style: TextStyle(color: t.textFaint),
                ),
              ),
        ),
      ],
    );
  }
}
