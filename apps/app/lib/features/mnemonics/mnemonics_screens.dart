import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/mnemonics_provider.dart';

final _accent = Color(ModuleKey.mnemonics.accentHex);

class MnemonicsListScreen extends ConsumerWidget {
  const MnemonicsListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(mnemonicsProvider);
    return ModuleScaffold(
      title: 'Mnemonics',
      subtitle: ModuleKey.mnemonics.tagline,
      accent: _accent,
      onCopilot: () => context.push(Routes.copilot),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNew(context, ref),
        backgroundColor: _accent,
        foregroundColor: const Color(0xFF080B1C),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Contribute'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _MnemonicCard(mnemonic: items[i]),
      ),
    );
  }

  void _showNew(BuildContext context, WidgetRef ref) {
    final titleC = TextEditingController();
    final bodyC = TextEditingController();
    final expC = TextEditingController();
    showAppSheet(
      context,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New mnemonic', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            AppTextField(controller: titleC, label: 'What it helps remember', hint: 'e.g. Cranial nerves', accent: _accent),
            const SizedBox(height: 12),
            AppTextField(controller: bodyC, label: 'The mnemonic', hint: 'e.g. OOOTTAFAGVAH', accent: _accent),
            const SizedBox(height: 12),
            AppTextField(controller: expC, label: 'Expansion', hint: 'What each letter means', maxLines: 3, accent: _accent),
            const SizedBox(height: 16),
            AppButton(
              label: 'Publish',
              expand: true,
              accent: _accent,
              onPressed: () {
                if (titleC.text.trim().isEmpty || bodyC.text.trim().isEmpty) return;
                ref.read(mnemonicsProvider.notifier).add(Mnemonic(
                      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
                      title: titleC.text.trim(),
                      body: bodyC.text.trim(),
                      expansion: expC.text.trim().isEmpty ? null : expC.text.trim(),
                      authorName: 'You',
                      createdAt: DateTime.now(),
                    ));
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MnemonicCard extends ConsumerWidget {
  const _MnemonicCard({required this.mnemonic});
  final Mnemonic mnemonic;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final m = mnemonic;
    return AppCard(
      onTap: () => context.push(Routes.mnemonic(m.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              _VoteButton(icon: Icons.keyboard_arrow_up_rounded, active: m.myVote == 1, accent: _accent,
                  onTap: () => ref.read(mnemonicsProvider.notifier).vote(m.id, 1)),
              Text('${m.score}', style: const TextStyle(fontWeight: FontWeight.w800)),
              _VoteButton(icon: Icons.keyboard_arrow_down_rounded, active: m.myVote == -1, accent: t.danger,
                  onTap: () => ref.read(mnemonicsProvider.notifier).vote(m.id, -1)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(m.body, style: TextStyle(color: _accent, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 1)),
                if (m.expansion != null) ...[
                  const SizedBox(height: 6),
                  Text(m.expansion!, style: TextStyle(color: t.textMuted, fontSize: 13, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('by ${m.authorName}', style: TextStyle(color: t.textFaint, fontSize: 11)),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(m.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          size: 18, color: m.saved ? _accent : t.textFaint),
                      onPressed: () => ref.read(mnemonicsProvider.notifier).toggleSave(m.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({required this.icon, required this.active, required this.onTap, required this.accent});
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Icon(icon, color: active ? accent : t.textFaint, size: 26),
    );
  }
}

class MnemonicDetailScreen extends ConsumerWidget {
  const MnemonicDetailScreen({super.key, required this.mnemonicId});
  final String mnemonicId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final m = ref.watch(mnemonicsProvider.notifier).byId(mnemonicId);
    if (m == null) {
      return const ModuleScaffold(title: 'Mnemonic', body: EmptyState(icon: Icons.search_off_rounded, title: 'Not found'));
    }
    return ModuleScaffold(
      title: m.title,
      accent: _accent,
      onCopilot: () => context.push(Routes.copilot),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          AppCard(
            feature: true,
            accent: _accent,
            child: Center(
              child: Text(m.body,
                  style: TextStyle(color: _accent, fontWeight: FontWeight.w800, fontSize: 32, letterSpacing: 2)),
            ),
          ),
          if (m.expansion != null) ...[
            const SizedBox(height: 16),
            AppCard(child: Text(m.expansion!, style: TextStyle(color: t.text, height: 1.6))),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              AppButton(
                label: '${m.score}',
                icon: Icons.thumb_up_rounded,
                variant: m.myVote == 1 ? AppButtonVariant.primary : AppButtonVariant.secondary,
                accent: _accent,
                size: AppButtonSize.small,
                onPressed: () => ref.read(mnemonicsProvider.notifier).vote(m.id, 1),
              ),
              const SizedBox(width: 10),
              AppButton(
                label: m.saved ? 'Saved' : 'Save',
                icon: m.saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                variant: AppButtonVariant.ghost,
                accent: _accent,
                size: AppButtonSize.small,
                onPressed: () => ref.read(mnemonicsProvider.notifier).toggleSave(m.id),
              ),
            ],
          ),
          if (m.conceptIds.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionHeader(title: 'See also'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: m.conceptIds
                  .map((c) => AppChip(label: 'Concept', icon: Icons.hub_rounded, onTap: () => context.push(Routes.concept(c))))
                  .toList(),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
