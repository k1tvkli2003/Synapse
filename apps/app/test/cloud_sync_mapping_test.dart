import 'package:flutter_test/flutter_test.dart';
import 'package:synapse_app/cloud/cloud_sync_service.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_engines/synapse_engines.dart';

void main() {
  group('profile row mapping', () {
    test('round-trips through profileToRow/profileFromRow', () {
      const profile = UserProfile(
        id: 'local-1',
        handle: 'kev81',
        displayName: 'Keyvan',
        specialty: 'Internal Medicine',
        year: 3,
        bio: 'Studying nights.',
        prefs: UserPrefs(dailyGoalXp: 80),
      );
      final row = profileToRow(profile, 'uid-123');
      expect(row['id'], 'uid-123');
      expect(row['handle'], 'kev81');
      expect(row['display_name'], 'Keyvan');
      expect(row['specialty'], 'Internal Medicine');
      expect(row['year'], 3);

      // Simulate what comes back from PostgREST (snake_case + timestamps).
      final fromDb = Map<String, dynamic>.from(row)
        ..['created_at'] = DateTime(2026, 1, 1).toIso8601String()
        ..['updated_at'] = DateTime(2026, 1, 2).toIso8601String();
      final restored = profileFromRow(fromDb);

      expect(restored.id, 'uid-123');
      expect(restored.handle, 'kev81');
      expect(restored.displayName, 'Keyvan');
      expect(restored.specialty, 'Internal Medicine');
      expect(restored.year, 3);
      expect(restored.bio, 'Studying nights.');
      expect(restored.prefs.dailyGoalXp, 80);
      expect(restored.updatedAt, DateTime(2026, 1, 2));
    });
  });

  group('game state row mapping', () {
    test('round-trips through gameStateToRow/gameStateFromRow', () {
      const game = GamificationState(
        xp: XPState(total: 540, level: 3, intoLevel: 230, toNext: 310),
        wallet: Wallet(gems: 75),
        hearts: Hearts(current: 3, max: 5),
        streak: Streak(
          current: 6,
          longest: 12,
          lastActiveDay: '2026-07-03',
          freezes: 1,
        ),
        league: League.gold,
        weekXp: 210,
      );
      final row = gameStateToRow(game, 'uid-123');
      expect(row['user_id'], 'uid-123');
      expect(row['xp_total'], 540);
      expect(row['gems'], 75);
      expect(row['hearts'], 3);
      expect(row['hearts_max'], 5);
      expect(row['streak_current'], 6);
      expect(row['streak_best'], 12);
      expect(row['last_active_day'], '2026-07-03');
      expect(row['freezes'], 1);
      expect(row['league'], 'gold');
      expect(row['week_xp'], 210);

      final restored = gameStateFromRow(row);
      // Level/intoLevel/toNext are recomputed from xp_total via XpCurve
      // rather than stored verbatim — the derivation must stay consistent.
      final expectedXp = XpCurve.levelFromTotal(540);
      expect(restored.xp.total, expectedXp.total);
      expect(restored.xp.level, expectedXp.level);
      expect(restored.xp.intoLevel, expectedXp.intoLevel);
      expect(restored.wallet.gems, 75);
      expect(restored.hearts.current, 3);
      expect(restored.hearts.max, 5);
      expect(restored.streak.current, 6);
      expect(restored.streak.longest, 12);
      expect(restored.streak.lastActiveDay, '2026-07-03');
      expect(restored.streak.freezes, 1);
      expect(restored.league, League.gold);
      expect(restored.weekXp, 210);
    });
  });

  group('remoteGameStateIsUntouched', () {
    test('true for a missing row', () {
      expect(remoteGameStateIsUntouched(null), isTrue);
    });

    test('true for a fresh trigger-created row', () {
      expect(
        remoteGameStateIsUntouched({
          'xp_total': 0,
          'level': 1,
          'gems': 0,
          'streak_current': 0,
        }),
        isTrue,
      );
    });

    test('false once any progress exists', () {
      expect(
        remoteGameStateIsUntouched({
          'xp_total': 40,
          'level': 1,
          'gems': 0,
          'streak_current': 0,
        }),
        isFalse,
      );
    });
  });
}
