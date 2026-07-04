import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';

/// A purchasable feature tier (prompt 40). Entitlements are server-validated in
/// production; here they are local + restorable so the gating logic is real.
enum Tier { free, pro }

/// A cosmetic item bought with the shared gem economy (prompt 39 §2). Strictly
/// cosmetic — never gates clinical content or correctness.
class Cosmetic {
  const Cosmetic({required this.id, required this.name, required this.kind, required this.price, required this.color, required this.icon});
  final String id;
  final String name;
  final String kind; // accent | avatar | flame | persona | theme
  final int price;
  final Color color;
  final IconData icon;
}

const kCosmetics = <Cosmetic>[
  Cosmetic(id: 'accent_emerald', name: 'Emerald accent', kind: 'accent', price: 200, color: Color(0xFF7BE0A3), icon: Icons.palette_rounded),
  Cosmetic(id: 'accent_rose', name: 'Rose accent', kind: 'accent', price: 200, color: Color(0xFFF7A8C4), icon: Icons.palette_rounded),
  Cosmetic(id: 'accent_amber', name: 'Amber accent', kind: 'accent', price: 200, color: Color(0xFFFFC773), icon: Icons.palette_rounded),
  Cosmetic(id: 'flame_blue', name: 'Blue streak flame', kind: 'flame', price: 350, color: Color(0xFF6FD3E8), icon: Icons.local_fire_department_rounded),
  Cosmetic(id: 'flame_violet', name: 'Violet streak flame', kind: 'flame', price: 350, color: Color(0xFFB794F6), icon: Icons.local_fire_department_rounded),
  Cosmetic(id: 'avatar_scrubs', name: 'Scrubs avatar', kind: 'avatar', price: 500, color: Color(0xFF5FD9C4), icon: Icons.person_rounded),
  Cosmetic(id: 'avatar_coat', name: 'White-coat avatar', kind: 'avatar', price: 500, color: Color(0xFF8C9EFF), icon: Icons.person_rounded),
  Cosmetic(id: 'persona_socratic', name: 'Socratic Copilot persona', kind: 'persona', price: 400, color: Color(0xFFB794F6), icon: Icons.auto_awesome_rounded),
  Cosmetic(id: 'theme_midnight', name: 'Midnight profile theme', kind: 'theme', price: 600, color: Color(0xFF050816), icon: Icons.dark_mode_rounded),
];

class Personalization {
  const Personalization({this.tier = Tier.free, this.owned = const {}, this.equippedAccent, this.equippedFlame, this.equippedAvatar});
  final Tier tier;
  final Set<String> owned;
  final String? equippedAccent;
  final String? equippedFlame;
  final String? equippedAvatar;

  bool get isPro => tier == Tier.pro;
  bool owns(String id) => owned.contains(id);

  Personalization copyWith({Tier? tier, Set<String>? owned, String? equippedAccent, String? equippedFlame, String? equippedAvatar}) {
    return Personalization(
      tier: tier ?? this.tier,
      owned: owned ?? this.owned,
      equippedAccent: equippedAccent ?? this.equippedAccent,
      equippedFlame: equippedFlame ?? this.equippedFlame,
      equippedAvatar: equippedAvatar ?? this.equippedAvatar,
    );
  }
}

/// Identity + entitlement + cosmetics state, persisted (prompt 39 / 40).
class PersonalizationNotifier extends Notifier<Personalization> {
  static const _key = 'personalization';

  @override
  Personalization build() {
    final store = ref.watch(sharedPreferencesProvider);
    final j = store.readJson(_key);
    if (j == null) return const Personalization();
    return Personalization(
      tier: (j['tier'] == 'pro') ? Tier.pro : Tier.free,
      owned: (j['owned'] as List?)?.map((e) => e.toString()).toSet() ?? {},
      equippedAccent: j['accent'] as String?,
      equippedFlame: j['flame'] as String?,
      equippedAvatar: j['avatar'] as String?,
    );
  }

  void subscribePro() { state = state.copyWith(tier: Tier.pro); _persist(); }
  void cancelPro() { state = state.copyWith(tier: Tier.free); _persist(); }

  /// Restore purchases (prompt 40 §3) — re-reads persisted entitlement.
  void restore() => state = build();

  void addOwned(String id) {
    state = state.copyWith(owned: {...state.owned, id});
    _persist();
  }

  void equip(Cosmetic c) {
    switch (c.kind) {
      case 'accent':
        state = state.copyWith(equippedAccent: c.id);
      case 'flame':
        state = state.copyWith(equippedFlame: c.id);
      case 'avatar':
        state = state.copyWith(equippedAvatar: c.id);
    }
    _persist();
  }

  void _persist() {
    ref.read(sharedPreferencesProvider).writeJson(_key, {
      'tier': state.tier.name,
      'owned': state.owned.toList(),
      'accent': state.equippedAccent,
      'flame': state.equippedFlame,
      'avatar': state.equippedAvatar,
    });
  }
}

final personalizationProvider =
    NotifierProvider<PersonalizationNotifier, Personalization>(PersonalizationNotifier.new);

/// App-wide entitlement gate (prompt 40 §2). Read this to decide whether a Pro
/// feature is unlocked.
final entitlementProvider = Provider<bool>((ref) => ref.watch(personalizationProvider).isPro);
