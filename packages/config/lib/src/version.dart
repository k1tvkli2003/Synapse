/// Application + persistence schema versions.
///
/// [appSchemaVersion] is stamped onto every persisted snapshot (Hive / drift /
/// shared_preferences) so migrations can be applied deterministically
/// (prompt 02 §4, prompt 08 §1).
const String appVersion = '0.1.0';

/// Bump whenever a persisted shape changes; persistence layers compare against
/// the stored value and migrate forward.
const int appSchemaVersion = 1;

/// Human-readable product name.
const String appName = 'Synapse';
