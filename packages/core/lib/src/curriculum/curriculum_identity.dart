import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The frozen namespace for every source-key-derived curriculum identity.
///
/// It is UUIDv5(DNS, `synapse.medical-learning-os.curriculum.v1`). Changing it
/// would orphan progress, source lineage, offline packs, and deep links.
abstract final class CurriculumIdentity {
  static const namespace = '5d371ba2-7a1c-5ef1-8d21-cc4b30633a02';

  static final RegExp _sourceKeyPattern = RegExp(
    r'^[a-z0-9][a-z0-9._-]*/course/[0-9]{2,3}'
    r'(?:/chapter/[0-9]{3})?'
    r'(?:/unit/[0-9]{3})?'
    r'(?:/concept-cluster/[0-9]{3})?'
    r'(?:/micro-lesson/[0-9]{3})?$',
  );

  static bool isValidSourceKey(String value) =>
      value == value.trim() && _sourceKeyPattern.hasMatch(value);

  static String fromSourceKey(String sourceKey) {
    if (!isValidSourceKey(sourceKey)) {
      throw ArgumentError.value(
        sourceKey,
        'sourceKey',
        'Use the normalized Course/Chapter/Unit/Concept Cluster/Micro-lesson ordinal grammar.',
      );
    }
    return uuidV5(namespace, sourceKey);
  }

  static String uuidV5(String namespaceUuid, String name) {
    final namespaceBytes = _parseUuid(namespaceUuid);
    final digest = sha1.convert([
      ...namespaceBytes,
      ...utf8.encode(name),
    ]).bytes;
    final bytes = digest.take(16).toList(growable: false);
    bytes[6] = (bytes[6] & 0x0f) | 0x50;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    return _formatUuid(bytes);
  }

  static List<int> _parseUuid(String value) {
    final compact = value.toLowerCase().replaceAll('-', '');
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(compact)) {
      throw ArgumentError.value(value, 'namespaceUuid', 'Invalid UUID.');
    }
    return List<int>.generate(
      16,
      (index) =>
          int.parse(compact.substring(index * 2, index * 2 + 2), radix: 16),
      growable: false,
    );
  }

  static String _formatUuid(List<int> bytes) {
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
