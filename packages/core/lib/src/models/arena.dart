import 'package:equatable/equatable.dart';

import 'ids.dart';
import 'reward.dart';

/// Bacterial gram classification — decides which antibiotics are effective.
enum Spectrum { gramPositive, gramNegative, broad }

enum CardRarity { common, rare, epic, legendary }

/// An antibiotic "unit" the player deploys (prompt 21). Stats reinforce real
/// pharmacology: spectrum coverage, cost, potency.
class UnitCard extends Equatable {
  const UnitCard({
    required this.id,
    required this.name,
    required this.drugClass,
    required this.cost,
    required this.damage,
    required this.hp,
    required this.spectrum,
    this.rarity = CardRarity.common,
    this.conceptId,
    this.mechanism,
  });

  final String id;
  final String name;
  final String drugClass;
  final int cost; // mana
  final int damage;
  final int hp;
  final Spectrum spectrum;
  final CardRarity rarity;
  final ConceptId? conceptId;
  final String? mechanism;

  /// Damage multiplier against a bacterium with the given gram type.
  double effectivenessVs(Spectrum bacteria) {
    if (spectrum == Spectrum.broad) return 1.0;
    return spectrum == bacteria ? 1.5 : 0.4;
  }

  @override
  List<Object?> get props => [id, name, cost, damage, hp, spectrum];
}

class BacteriaUnit extends Equatable {
  const BacteriaUnit({
    required this.id,
    required this.name,
    required this.hp,
    required this.damage,
    required this.spectrum,
    this.speed = 1.0,
    this.conceptId,
    this.resistsClasses = const [],
  });

  final String id;
  final String name;
  final int hp;
  final int damage;
  final Spectrum spectrum;
  final double speed;
  final ConceptId? conceptId;
  final List<String> resistsClasses;

  @override
  List<Object?> get props => [id, name, hp, damage, spectrum];
}

class ArenaDeck extends Equatable {
  const ArenaDeck({required this.cardIds, this.name = 'My Deck'});
  final String name;
  final List<String> cardIds; // 8 cards
  @override
  List<Object?> get props => [name, cardIds];
}

class ArenaProfile extends Equatable {
  const ArenaProfile({
    this.trophies = 0,
    this.wins = 0,
    this.losses = 0,
    this.league = League.bronze,
    this.ownedCardIds = const [],
  });

  final int trophies;
  final int wins;
  final int losses;
  final League league;
  final List<String> ownedCardIds;

  ArenaProfile copyWith({int? trophies, int? wins, int? losses, League? league}) => ArenaProfile(
        trophies: trophies ?? this.trophies,
        wins: wins ?? this.wins,
        losses: losses ?? this.losses,
        league: league ?? this.league,
        ownedCardIds: ownedCardIds,
      );

  @override
  List<Object?> get props => [trophies, wins, losses, league];
}

class Capsule extends Equatable {
  const Capsule({required this.id, required this.name, required this.cost, this.rarity = CardRarity.common});
  final String id;
  final String name;
  final int cost; // gems
  final CardRarity rarity;
  @override
  List<Object?> get props => [id, name, cost, rarity];
}

class Clan extends Equatable {
  const Clan({required this.id, required this.name, this.members = 0, this.trophies = 0, this.badge = '🦠'});
  final ClanId id;
  final String name;
  final int members;
  final int trophies;
  final String badge;
  @override
  List<Object?> get props => [id, name, members, trophies];
}
