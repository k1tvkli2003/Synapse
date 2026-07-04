import 'package:flutter/material.dart';
import 'package:synapse_ui/synapse_ui.dart';

/// Rendered for feature-flagged routes that aren't enabled yet — the path still
/// resolves (prompt 31 §G).
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, this.accent});
  final String title;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return ModuleScaffold(
      title: title,
      accent: accent,
      body: EmptyState(
        icon: Icons.rocket_launch_rounded,
        title: 'Coming soon',
        message: 'This surface is on the roadmap. The route resolves so deep links keep working.',
        accent: accent,
      ),
    );
  }
}
