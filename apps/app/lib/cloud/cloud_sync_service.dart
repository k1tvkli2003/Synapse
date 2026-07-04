import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_engines/synapse_engines.dart';

import 'supabase_bootstrap.dart';

/// Reads/writes the `synapse_profiles` / `synapse_game_state` tables (the
/// identity + reward-economy hub — prompt 05/09). Deployed onto the shared
/// StudyHUB Supabase project (see supabase/migrations/0001_init.sql).
///
/// Mastery/quests/achievements/notifications/content tables are provisioned
/// (0001_init.sql) but not yet synced by this pass — profile + game_state is
/// the coherent, testable slice for v1 cloud sync.
class CloudSyncService {
  const CloudSyncService();

  Future<Map<String, dynamic>?> fetchProfile(String uid) =>
      cloud.from('synapse_profiles').select().eq('id', uid).maybeSingle();

  Future<Map<String, dynamic>?> fetchGameState(String uid) =>
      cloud.from('synapse_game_state').select().eq('user_id', uid).maybeSingle();

  Future<void> pushProfile(UserProfile profile, String uid) =>
      cloud.from('synapse_profiles').upsert(profileToRow(profile, uid));

  Future<void> pushGameState(GamificationState game, String uid) =>
      cloud.from('synapse_game_state').upsert(gameStateToRow(game, uid));
}

/// True when a freshly trigger-created remote row has never been touched by a
/// real session — i.e. this is the very first sync for the account, so a
/// device with existing local progress should seed the cloud rather than
/// adopt the (empty) cloud state.
bool remoteGameStateIsUntouched(Map<String, dynamic>? row) {
  if (row == null) return true;
  return (row['xp_total'] as int? ?? 0) == 0 &&
      (row['level'] as int? ?? 1) <= 1 &&
      (row['gems'] as int? ?? 0) == 0 &&
      (row['streak_current'] as int? ?? 0) == 0;
}

Map<String, dynamic> profileToRow(UserProfile p, String uid) => {
      'id': uid,
      'handle': p.handle,
      'display_name': p.displayName,
      'avatar_url': p.avatarUrl,
      'role': p.role.name,
      'specialty': p.specialty,
      'year': p.year,
      'bio': p.bio,
      'prefs': p.prefs.toJson(),
    };

UserProfile profileFromRow(Map<String, dynamic> r) => UserProfile(
      id: r['id'] as String,
      handle: r['handle'] as String,
      displayName: r['display_name'] as String,
      avatarUrl: r['avatar_url'] as String?,
      role: UserRole.values.firstWhere((x) => x.name == r['role'], orElse: () => UserRole.student),
      specialty: r['specialty'] as String?,
      year: r['year'] as int?,
      bio: r['bio'] as String?,
      prefs: r['prefs'] is Map
          ? UserPrefs.fromJson(Map<String, dynamic>.from(r['prefs'] as Map))
          : const UserPrefs(),
      createdAt: DateTime.tryParse(r['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(r['updated_at']?.toString() ?? ''),
    );

Map<String, dynamic> gameStateToRow(GamificationState g, String uid) => {
      'user_id': uid,
      'xp_total': g.xp.total,
      'level': g.xp.level,
      'gems': g.wallet.gems,
      'hearts': g.hearts.current,
      'hearts_max': g.hearts.max,
      'next_refill_at': g.hearts.nextRefillAt?.toIso8601String(),
      'streak_current': g.streak.current,
      'streak_best': g.streak.longest,
      'last_active_day': g.streak.lastActiveDay,
      'freezes': g.streak.freezes,
      'league': g.league.name,
      'week_xp': g.weekXp,
    };

GamificationState gameStateFromRow(Map<String, dynamic> r) => GamificationState(
      xp: XpCurve.levelFromTotal(r['xp_total'] as int? ?? 0),
      wallet: Wallet(gems: r['gems'] as int? ?? 0),
      hearts: Hearts(
        current: r['hearts'] as int? ?? 5,
        max: r['hearts_max'] as int? ?? 5,
        nextRefillAt: DateTime.tryParse(r['next_refill_at']?.toString() ?? ''),
      ),
      streak: Streak(
        current: r['streak_current'] as int? ?? 0,
        longest: r['streak_best'] as int? ?? 0,
        lastActiveDay: r['last_active_day'] as String?,
        freezes: r['freezes'] as int? ?? 0,
      ),
      league: League.values.firstWhere((x) => x.name == r['league'], orElse: () => League.bronze),
      weekXp: r['week_xp'] as int? ?? 0,
    );
