import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:synapse_ui/synapse_ui.dart';

import '../../router/routes.dart';
import '../../state/entitlement_provider.dart';
import '../../state/game_provider.dart';

const _accent = Color(0xFFFFC773);

/// The cosmetic shop — a gem sink that never gates clinical content (prompt 39).
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final wallet = ref.watch(walletProvider);
    final p = ref.watch(personalizationProvider);

    return ModuleScaffold(
      title: 'Shop',
      subtitle: 'Cosmetics only — never pay-to-learn',
      accent: _accent,
      scrollable: true,
      actions: [
        Padding(padding: const EdgeInsets.only(right: 8), child: Center(child: GemCounter(gems: wallet.gems))),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          AppCard(
            accent: const Color(0xFFB794F6),
            onTap: () => context.push(Routes.pro),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFB794F6), Color(0xFF8C9EFF)]), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.workspace_premium_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.isPro ? 'Synapse Pro — active' : 'Synapse Pro', style: Theme.of(context).textTheme.titleMedium),
                Text(p.isPro ? 'Thanks for supporting Synapse' : 'Unlimited hearts, Copilot, simulators & more', style: TextStyle(color: t.textMuted, fontSize: 12.5)),
              ])),
              const Icon(Icons.chevron_right_rounded),
            ]),
          ),
          const SizedBox(height: 20),
          Text('Cosmetics', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Spend gems you earn from studying. Strictly cosmetic.', style: TextStyle(color: t.textMuted, fontSize: 13)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.95),
            itemCount: kCosmetics.length,
            itemBuilder: (context, i) {
              final c = kCosmetics[i];
              final owned = p.owns(c.id);
              final equipped = p.equippedAccent == c.id || p.equippedFlame == c.id || p.equippedAvatar == c.id;
              return AppCard(
                accent: equipped ? c.color : null,
                padding: const EdgeInsets.all(14),
                onTap: () => _onTap(context, ref, c, owned),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(color: c.color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                    child: Icon(c.icon, color: c.color),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.name, style: Theme.of(context).textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    if (equipped)
                      AppBadge(label: 'Equipped', color: c.color, subtle: true)
                    else if (owned)
                      AppBadge(label: 'Tap to equip', color: t.success, subtle: true)
                    else
                      Row(children: [Icon(Icons.diamond_rounded, size: 14, color: _accent), const SizedBox(width: 4), Text('${c.price}', style: TextStyle(color: t.text, fontWeight: FontWeight.w700))]),
                  ]),
                ]),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _onTap(BuildContext context, WidgetRef ref, Cosmetic c, bool owned) {
    final notifier = ref.read(personalizationProvider.notifier);
    if (owned) {
      notifier.equip(c);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${c.name} equipped'), behavior: SnackBarBehavior.floating));
      return;
    }
    final ok = ref.read(gameProvider.notifier).spendGems(c.price);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not enough gems — earn more by studying'), behavior: SnackBarBehavior.floating));
      return;
    }
    notifier.addOwned(c.id);
    notifier.equip(c);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unlocked & equipped ${c.name}'), behavior: SnackBarBehavior.floating));
  }
}

/// The Synapse Pro paywall (prompt 40 §3). Ethical: never locks correctness.
class ProScreen extends ConsumerWidget {
  const ProScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final p = ref.watch(personalizationProvider);
    final benefits = [
      ('Unlimited hearts', Icons.favorite_rounded),
      ('Unlimited Copilot questions', Icons.auto_awesome_rounded),
      ('AI-generated Cases & OSCE stations', Icons.local_hospital_rounded),
      ('Advanced Insights & exam readiness', Icons.insights_rounded),
      ('Full curriculum tracks', Icons.timeline_rounded),
      ('Offline downloads', Icons.download_rounded),
      ('Generative ECG & layered Sounds', Icons.monitor_heart_rounded),
      ('Exclusive cosmetics', Icons.workspace_premium_rounded),
    ];

    return ModuleScaffold(
      title: 'Synapse Pro',
      accent: const Color(0xFFB794F6),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFB794F6), Color(0xFF8C9EFF)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 32),
              const SizedBox(height: 10),
              Text('Go further, faster', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Everything in Synapse, unlimited. Learning fundamentals stay free, always.', style: TextStyle(color: Colors.white70)),
            ]),
          ),
          const SizedBox(height: 20),
          for (final (label, icon) in benefits)
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
              Icon(icon, color: const Color(0xFFB794F6), size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: TextStyle(color: t.text, fontSize: 14.5))),
              Icon(Icons.check_rounded, color: t.success, size: 18),
            ])),
          const SizedBox(height: 16),
          AppCard(
            color: t.surfaceAlt,
            child: Row(children: [
              Icon(Icons.verified_user_rounded, color: t.success, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('We never lock clinical correctness or safety content behind a paywall.', style: TextStyle(color: t.textMuted, fontSize: 12.5, height: 1.4))),
            ]),
          ),
          const SizedBox(height: 16),
          if (p.isPro)
            AppButton(label: 'Manage subscription', variant: AppButtonVariant.secondary, accent: const Color(0xFFB794F6), expand: true, onPressed: () => ref.read(personalizationProvider.notifier).cancelPro())
          else ...[
            AppButton(label: 'Start 7-day free trial · \$8.99/mo', accent: const Color(0xFFB794F6), expand: true, onPressed: () {
              ref.read(personalizationProvider.notifier).subscribePro();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Welcome to Synapse Pro!'), behavior: SnackBarBehavior.floating));
            }),
            const SizedBox(height: 8),
            Center(child: TextButton(onPressed: () => ref.read(personalizationProvider.notifier).restore(), child: const Text('Restore purchases'))),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Profile customization (prompt 39 §3) — equip owned cosmetics + preferences.
class CustomizeScreen extends ConsumerWidget {
  const CustomizeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(personalizationProvider);
    final ownedCosmetics = kCosmetics.where((c) => p.owns(c.id)).toList();

    return ModuleScaffold(
      title: 'Customize',
      subtitle: 'Your identity across Synapse',
      accent: const Color(0xFFF7A8C4),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (ownedCosmetics.isEmpty)
            EmptyState(
              icon: Icons.brush_rounded,
              title: 'No cosmetics yet',
              message: 'Earn gems by studying, then unlock cosmetics in the shop.',
              actionLabel: 'Open shop',
              accent: const Color(0xFFF7A8C4),
              onAction: () => context.push(Routes.shop),
            )
          else
            for (final c in ownedCosmetics)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListRow(
                  title: c.name,
                  subtitle: c.kind,
                  leadingIcon: c.icon,
                  accent: c.color,
                  trailing: (p.equippedAccent == c.id || p.equippedFlame == c.id || p.equippedAvatar == c.id)
                      ? AppBadge(label: 'On', color: c.color, subtle: true)
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: () => ref.read(personalizationProvider.notifier).equip(c),
                ),
              ),
          const SizedBox(height: 16),
          AppButton(label: 'Browse the shop', icon: Icons.storefront_rounded, accent: const Color(0xFFF7A8C4), variant: AppButtonVariant.secondary, expand: true, onPressed: () => context.push(Routes.shop)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
