import 'package:synapse_core/synapse_core.dart';

/// Weekly league promotion/relegation (prompt 09 §2). In a local session the
/// cohort is simulated; the same thresholds apply server-side via a cron.
class LeagueEngine {
  const LeagueEngine._();

  static const int promoteThreshold = 600;
  static const int relegateThreshold = 120;

  /// Decide the league for next week from this week's XP.
  static LeagueOutcome evaluateWeek(League current, int weekXp) {
    if (weekXp >= promoteThreshold && current.next != null) {
      return LeagueOutcome(current.next!, LeagueMove.promoted);
    }
    if (weekXp < relegateThreshold && current.previous != null) {
      return LeagueOutcome(current.previous!, LeagueMove.relegated);
    }
    return LeagueOutcome(current, LeagueMove.stayed);
  }

  /// A plausible standing position for the UI given weekly XP.
  static int simulatedRank(int weekXp) {
    if (weekXp >= promoteThreshold) return 1;
    if (weekXp >= 400) return 3;
    if (weekXp >= 200) return 8;
    if (weekXp >= relegateThreshold) return 15;
    return 24;
  }
}

enum LeagueMove { promoted, stayed, relegated }

class LeagueOutcome {
  const LeagueOutcome(this.league, this.move);
  final League league;
  final LeagueMove move;
}
