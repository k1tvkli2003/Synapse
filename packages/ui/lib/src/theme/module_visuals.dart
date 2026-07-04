import 'package:flutter/material.dart';
import 'package:synapse_core/synapse_core.dart';

/// Visual identity for each module: its icon (Material Symbols rounded as the
/// lucide fallback per style §9) and a convenience accent getter. Colour lives
/// in [ModuleKey.accentHex] / `tokens.accentOf` — this only owns the glyph.
class ModuleVisuals {
  const ModuleVisuals._();

  static IconData icon(ModuleKey m) => switch (m) {
        ModuleKey.copilot => Icons.auto_awesome_rounded,
        ModuleKey.terms => Icons.translate_rounded,
        ModuleKey.cards => Icons.style_rounded,
        ModuleKey.mnemonics => Icons.lightbulb_rounded,
        ModuleKey.ecg => Icons.monitor_heart_rounded,
        ModuleKey.sounds => Icons.graphic_eq_rounded,
        ModuleKey.labs => Icons.science_rounded,
        ModuleKey.algorithms => Icons.account_tree_rounded,
        ModuleKey.orLab => Icons.medical_services_rounded,
        ModuleKey.rounds => Icons.podcasts_rounded,
        ModuleKey.buddies => Icons.groups_rounded,
        ModuleKey.arena => Icons.sports_esports_rounded,
      };

  static Color accent(ModuleKey m) => Color(m.accentHex);

  static IconData branchIcon(ShellBranch b) => switch (b) {
        ShellBranch.home => Icons.home_rounded,
        ShellBranch.learn => Icons.school_rounded,
        ShellBranch.clinical => Icons.health_and_safety_rounded,
        ShellBranch.social => Icons.forum_rounded,
        ShellBranch.profile => Icons.person_rounded,
      };
}

/// Resolves the string icon keys stored on achievements/notifications to glyphs.
IconData iconForKey(String key) => switch (key) {
      'flame' => Icons.local_fire_department_rounded,
      'bolt' => Icons.bolt_rounded,
      'star' => Icons.star_rounded,
      'trophy' => Icons.emoji_events_rounded,
      'gem' => Icons.diamond_rounded,
      'heart' => Icons.favorite_rounded,
      'bell' => Icons.notifications_rounded,
      'check' => Icons.check_circle_rounded,
      'book' => Icons.menu_book_rounded,
      'brain' => Icons.psychology_rounded,
      'medal' => Icons.military_tech_rounded,
      'target' => Icons.track_changes_rounded,
      'crown' => Icons.workspace_premium_rounded,
      _ => Icons.auto_awesome_rounded,
    };
