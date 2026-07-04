import 'package:synapse_core/synapse_core.dart';

/// The level curve (prompt 09 §2). Each level costs progressively more XP so
/// early levels feel fast and later ones feel earned.
class XpCurve {
  const XpCurve._();

  /// XP needed to go *from* level [n] to [n]+1.
  static int xpForLevel(int n) => 40 + (n * 60) + (n * n * 10);

  /// Cumulative XP required to *reach* level [n] (level 1 == 0).
  static int totalToReach(int n) {
    var sum = 0;
    for (var i = 1; i < n; i++) {
      sum += xpForLevel(i);
    }
    return sum;
  }

  /// Resolve a total XP amount into a full [XPState].
  static XPState levelFromTotal(int total) {
    var level = 1;
    while (total >= totalToReach(level + 1)) {
      level++;
      if (level > 999) break;
    }
    final into = total - totalToReach(level);
    final toNext = xpForLevel(level);
    return XPState(total: total, level: level, intoLevel: into, toNext: toNext);
  }
}
