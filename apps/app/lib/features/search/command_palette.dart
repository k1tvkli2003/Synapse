import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/app_providers.dart';
import '../../state/settings_provider.dart';

/// A single command in the palette (prompt 36 §2).
class _Command {
  const _Command(this.label, this.icon, this.run, {this.group = 'Navigate', this.keywords = const []});
  final String label;
  final IconData icon;
  final void Function(BuildContext, WidgetRef) run;
  final String group;
  final List<String> keywords;
}

/// Shows the keyboard-first command palette (⌘K / Ctrl-K), first-class on
/// desktop/web (prompt 36 §2). Navigate anywhere, run an action, or jump to
/// any content — all from the keyboard.
Future<void> showCommandPalette(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (_) => const Dialog(
      alignment: Alignment.topCenter,
      insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      backgroundColor: Colors.transparent,
      child: _CommandPalette(),
    ),
  );
}

class _CommandPalette extends ConsumerStatefulWidget {
  const _CommandPalette();
  @override
  ConsumerState<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<_CommandPalette> {
  String _q = '';

  List<_Command> get _all => [
        _Command('Go to Home', Icons.home_rounded, (c, r) => c.go(Routes.home)),
        _Command("Today's plan", Icons.checklist_rounded, (c, r) => c.push(Routes.plan), keywords: ['study', 'plan']),
        _Command('Daily Review', Icons.replay_rounded, (c, r) => c.push(Routes.review), keywords: ['srs', 'cards']),
        _Command('Library', Icons.menu_book_rounded, (c, r) => c.push(Routes.library), keywords: ['reference', 'disease', 'drug']),
        _Command('Calculators', Icons.calculate_rounded, (c, r) => c.push(Routes.tools), keywords: ['score', 'mdcalc']),
        _Command('Insights', Icons.insights_rounded, (c, r) => c.push(Routes.insights), keywords: ['stats', 'dashboard']),
        _Command('Ask Copilot', Icons.auto_awesome_rounded, (c, r) => c.push(Routes.copilot), keywords: ['ai', 'tutor']),
        _Command('OSCE Simulator', Icons.record_voice_over_rounded, (c, r) => c.push(Routes.osce)),
        _Command('Virtual Patient Cases', Icons.local_hospital_rounded, (c, r) => c.push(Routes.cases)),
        _Command('Play Arena', Icons.sports_esports_rounded, (c, r) => c.push(Routes.arenaBattle), keywords: ['game']),
        _Command('Community', Icons.groups_rounded, (c, r) => c.push(Routes.community)),
        _Command('Leaderboard', Icons.leaderboard_rounded, (c, r) => c.push(Routes.leaderboard)),
        _Command('Shop', Icons.storefront_rounded, (c, r) => c.push(Routes.shop)),
        _Command('Settings', Icons.settings_rounded, (c, r) => c.push(Routes.settings)),
        _Command('Drug interaction checker', Icons.warning_amber_rounded, (c, r) => c.push(Routes.drugInteractions)),
        // Actions
        _Command('Toggle theme', Icons.brightness_6_rounded, (c, r) {
          final s = r.read(settingsProvider);
          r.read(settingsProvider.notifier).setTheme(s.theme == ThemeModePref.dark ? ThemeModePref.light : ThemeModePref.dark);
        }, group: 'Actions', keywords: ['dark', 'light']),
        _Command('New mnemonic', Icons.add_rounded, (c, r) => c.push(Routes.mnemonicNew), group: 'Actions', keywords: ['create']),
        _Command('Author content', Icons.edit_rounded, (c, r) => c.push(Routes.create), group: 'Actions'),
      ];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final repo = ref.watch(repositoryProvider);
    final q = _q.trim().toLowerCase();

    final commands = q.isEmpty
        ? _all
        : _all.where((c) => c.label.toLowerCase().contains(q) || c.keywords.any((k) => k.contains(q))).toList();
    final content = q.length >= 2 ? repo.search(_q).items.take(6).toList() : <LearnItem>[];

    return Container(
      constraints: const BoxConstraints(maxWidth: 620, maxHeight: 480),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 40, offset: const Offset(0, 18))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _q = v),
            style: Theme.of(context).textTheme.titleMedium,
            decoration: InputDecoration(
              hintText: 'Type a command or search…',
              prefixIcon: const Icon(Icons.bolt_rounded),
              border: InputBorder.none,
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Align(alignment: Alignment.centerRight, widthFactor: 1, child: Text('esc', style: TextStyle(color: t.textFaint, fontSize: 12))),
              ),
            ),
            onSubmitted: (_) {
              if (commands.isNotEmpty) {
                _run(commands.first);
              } else if (content.isNotEmpty) {
                _open(content.first);
              }
            },
          ),
        ),
        Divider(height: 1, color: t.border),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 6),
            children: [
              for (final group in ['Navigate', 'Actions'])
                if (commands.any((c) => c.group == group)) ...[
                  _header(t, group),
                  for (final c in commands.where((x) => x.group == group))
                    _tile(t, c.icon, c.label, () => _run(c)),
                ],
              if (content.isNotEmpty) ...[
                _header(t, 'Content'),
                for (final item in content)
                  _tile(t, Icons.article_rounded, item.title, () => _open(item), trailing: item.module.title),
              ],
              if (commands.isEmpty && content.isEmpty)
                Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('No matches', style: TextStyle(color: t.textMuted)))),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _header(SynapseTokens t, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Text(label.toUpperCase(), style: TextStyle(color: t.textFaint, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
      );

  Widget _tile(SynapseTokens t, IconData icon, String label, VoidCallback onTap, {String? trailing}) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(children: [
            Icon(icon, size: 18, color: t.textMuted),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(color: t.text, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (trailing != null) Text(trailing, style: TextStyle(color: t.textFaint, fontSize: 12)),
          ]),
        ),
      );

  void _run(_Command c) {
    Navigator.of(context).pop();
    c.run(context, ref);
  }

  void _open(LearnItem item) {
    Navigator.of(context).pop();
    context.push(item.route);
  }
}
