import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Canonical JSON for immutable release receipts.
///
/// Object keys are recursively sorted. Lists retain semantic order. Unsupported
/// values and non-finite numbers fail instead of producing platform-dependent
/// output.
abstract final class CanonicalJson {
  static Object? normalize(Object? value) {
    if (value == null || value is String || value is bool || value is int) {
      return value;
    }
    if (value is double) {
      if (!value.isFinite) {
        throw ArgumentError.value(
          value,
          'value',
          'Canonical JSON requires finite numbers.',
        );
      }
      return value;
    }
    if (value is num) {
      final converted = value.toDouble();
      if (!converted.isFinite) {
        throw ArgumentError.value(
          value,
          'value',
          'Canonical JSON requires finite numbers.',
        );
      }
      return value;
    }
    if (value is List) {
      return value.map(normalize).toList(growable: false);
    }
    if (value is Map) {
      if (value.keys.any((key) => key is! String)) {
        throw ArgumentError.value(
          value,
          'value',
          'Canonical JSON object keys must be strings.',
        );
      }
      final keys = value.keys.cast<String>().toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: normalize(value[key]),
      };
    }
    throw ArgumentError.value(
      value,
      'value',
      'Unsupported canonical JSON value.',
    );
  }

  static String encode(Object? value) => jsonEncode(normalize(value));

  static List<int> utf8Bytes(Object? value) => utf8.encode(encode(value));

  static String sha256Hex(Object? value) =>
      sha256.convert(utf8Bytes(value)).toString();
}
