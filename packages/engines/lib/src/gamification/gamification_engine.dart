import 'package:meta/meta.dart';
import 'package:synapse_core/synapse_core.dart';

import 'xp_curve.dart';

/// The full reward state owned by `rewardProvider` (prompt 08 §2).
@immutable
class GamificationState {
  const GamificationState({
    this.xp = const XPState(),
    this.wallet = const Wallet(),
    this.hearts = const Hearts(),
    this.streak = const Streak(),
    this.league = League.bronze,
    this.weekXp = 0,
  });

  final XPState xp;
  final Wallet wallet;
  final Hearts hearts;
  final Streak streak;
  final League league;
  final int weekXp;

  GamificationState copyWith({
    XPState? xp,
    Wallet? wallet,
    Hearts? hearts,
    Streak? streak,
    League? league,
    int? weekXp,
  }) {
    return GamificationState(
      xp: xp ?? this.xp,
      wallet: wallet ?? this.wallet,
      hearts: hearts ?? this.hearts,
      streak: streak ?? this.streak,
      league: league ?? this.league,
      weekXp: weekXp ?? this.weekXp,
    );
  }

  Map<String, dynamic> toJson() => {
        'xp': xp.toJson(),
        'wallet': wallet.toJson(),
        'hearts': hearts.toJson(),
        'streak': streak.toJson(),
        'league': league.name,
        'weekXp': weekXp,
      };

  factory GamificationState.fromJson(Map<String, dynamic> j) => GamificationState(
        xp: j['xp'] is Map ? XPState.fromJson(Map<String, dynamic>.from(j['xp'])) : const XPState(),
        wallet: j['wallet'] is Map ? Wallet.fromJson(Map<String, dynamic>.from(j['wallet'])) : const Wallet(),
        hearts: j['hearts'] is Map ? Hearts.fromJson(Map<String, dynamic>.from(j['hearts'])) : const Hearts(),
        streak: j['streak'] is Map ? Streak.fromJson(Map<String, dynamic>.from(j['streak'])) : const Streak(),
        league: League.values.firstWhere((l) => l.name == j['league'], orElse: () => League.bronze),
        weekXp: j['weekXp'] as int? ?? 0,
      );
}

/// A side-effect the UI should surface (a toast, a celebration).
sealed class RewardIntent {
  const RewardIntent();
}

class XpGainedIntent extends RewardIntent {
  const XpGainedIntent(this.xp, this.gems);
  final int xp;
  final int gems;
}

class LevelUpIntent extends RewardIntent {
  const LevelUpIntent(this.newLevel);
  final int newLevel;
}

class StreakUpIntent extends RewardIntent {
  const StreakUpIntent(this.days);
  final int days;
}

class GamificationResult {
  const GamificationResult(this.state, this.intents);
  final GamificationState state;
  final List<RewardIntent> intents;
}

/// The pure reward engine. `rewardProvider.award(event)` calls this, persists
/// the result, and fires the returned intents as toasts/celebrations.
class GamificationEngine {
  const GamificationEngine();

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Apply a [RewardEvent] to [state]. First-try and streak bonuses are folded
  /// into the XP; streak rolls over once per calendar day of activity.
  GamificationResult award(GamificationState state, RewardEvent event, {DateTime? now}) {
    final ts = now ?? DateTime.now();
    final intents = <RewardIntent>[];

    // XP with multipliers.
    final firstTryBonus = event.firstTry ? 1.2 : 1.0;
    final streakBonus = 1.0 + (state.streak.current.clamp(0, 30) * 0.01); // up to +30%
    final gainedXp = (event.xp * firstTryBonus * streakBonus).round();
    final newTotal = state.xp.total + gainedXp;
    final newXp = XpCurve.levelFromTotal(newTotal);
    if (newXp.level > state.xp.level) intents.add(LevelUpIntent(newXp.level));

    // Gems.
    final newWallet = state.wallet.copyWith(gems: state.wallet.gems + event.gems);

    // Streak rollover (any activity from any module counts).
    final streakResult = _rollStreak(state.streak, ts);
    if (streakResult.changed) intents.add(StreakUpIntent(streakResult.streak.current));

    intents.add(XpGainedIntent(gainedXp, event.gems));

    return GamificationResult(
      state.copyWith(
        xp: newXp,
        wallet: newWallet,
        streak: streakResult.streak,
        weekXp: state.weekXp + gainedXp,
      ),
      intents,
    );
  }

  /// Lose a heart on a wrong answer in a hearted drill.
  GamificationState loseHeart(GamificationState state, {DateTime? now}) {
    if (state.hearts.current <= 0) return state;
    final next = (state.hearts.current - 1);
    return state.copyWith(
      hearts: state.hearts.copyWith(
        current: next,
        nextRefillAt: next < state.hearts.max
            ? (now ?? DateTime.now()).add(const Duration(minutes: 30))
            : null,
      ),
    );
  }

  /// Refill hearts by spending gems.
  GamificationState refillHeartsWithGems(GamificationState state, {int cost = 50}) {
    if (state.hearts.isFull || state.wallet.gems < cost) return state;
    return state.copyWith(
      hearts: state.hearts.copyWith(current: state.hearts.max, clearRefill: true),
      wallet: state.wallet.copyWith(gems: state.wallet.gems - cost),
    );
  }

  _StreakResult _rollStreak(Streak streak, DateTime now) {
    final today = dayKey(now);
    if (streak.lastActiveDay == today) {
      return _StreakResult(streak, false); // already counted today
    }
    final yesterday = dayKey(now.subtract(const Duration(days: 1)));
    final continues = streak.lastActiveDay == yesterday;
    final current = continues ? streak.current + 1 : 1;
    final longest = current > streak.longest ? current : streak.longest;
    return _StreakResult(
      streak.copyWith(current: current, longest: longest, lastActiveDay: today),
      true,
    );
  }
}

class _StreakResult {
  const _StreakResult(this.streak, this.changed);
  final Streak streak;
  final bool changed;
}
