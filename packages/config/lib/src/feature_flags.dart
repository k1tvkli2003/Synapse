import 'package:meta/meta.dart';

/// One flag per module plus sub-feature flags so modules ship incrementally
/// (prompt 02 §4). All modules are ON by default; experimental sub-features are
/// gated and resolve to a "coming soon" surface when off (prompt 31 §G).
@immutable
class FeatureFlags {
  const FeatureFlags({
    this.moduleCopilot = true,
    this.moduleTerms = true,
    this.moduleCards = true,
    this.moduleMnemonics = true,
    this.moduleEcg = true,
    this.moduleSounds = true,
    this.moduleLabs = true,
    this.moduleAlgorithms = true,
    this.moduleOrLab = true,
    this.moduleRounds = true,
    this.moduleBuddies = true,
    this.moduleArena = true,
    this.moduleCases = true,
    // Experimental sub-features (off until their generative backends land).
    this.featureEcgGenerative = false,
    this.featureSoundSimulator = false,
    this.featureOrVisual = false,
    this.featureLiveRooms = false,
  });

  final bool moduleCopilot;
  final bool moduleTerms;
  final bool moduleCards;
  final bool moduleMnemonics;
  final bool moduleEcg;
  final bool moduleSounds;
  final bool moduleLabs;
  final bool moduleAlgorithms;
  final bool moduleOrLab;
  final bool moduleRounds;
  final bool moduleBuddies;
  final bool moduleArena;
  final bool moduleCases;

  final bool featureEcgGenerative;
  final bool featureSoundSimulator;
  final bool featureOrVisual;
  final bool featureLiveRooms;

  static const FeatureFlags defaults = FeatureFlags();
}
