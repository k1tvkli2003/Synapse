import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:synapse_config/synapse_config.dart';

/// A tiny schema-versioned KV store over SharedPreferences (prompt 08 §1).
/// Persists only what must survive a restart (prefs, drafts, progress) — not
/// server caches.
class PersistedStore {
  PersistedStore(this._prefs) {
    final v = _prefs.getInt(_schemaKey);
    if (v == null) {
      _prefs.setInt(_schemaKey, appSchemaVersion);
    } else if (v != appSchemaVersion) {
      // Forward migration hook — for now we simply restamp.
      _prefs.setInt(_schemaKey, appSchemaVersion);
    }
  }

  static const _schemaKey = '__synapse_schema';
  final SharedPreferences _prefs;

  Map<String, dynamic>? readJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJson(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  /// Returns the raw decoded JSON value for infrastructure adapters that need
  /// to distinguish a missing record from a corrupt one. Presentation stores
  /// should keep using [readJson], which intentionally degrades invalid UI
  /// preferences to their defaults.
  Object? readJsonStrict(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  bool? readBool(String key) => _prefs.getBool(key);
  Future<void> writeBool(String key, bool v) => _prefs.setBool(key, v);

  Future<void> remove(String key) => _prefs.remove(key);
}
