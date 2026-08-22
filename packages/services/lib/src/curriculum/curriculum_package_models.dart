import 'package:synapse_core/synapse_core.dart';

enum CurriculumActivationTarget { preview, learner }

enum CurriculumPackageTrustKind {
  /// Read compatibility for registries written before trust provenance was
  /// persisted. It may be inspected in Preview but never learner-activated.
  legacyCallerHashes,

  /// Bytes shipped inside the signed application artifact.
  bundledArtifact,

  /// Bytes authorized by a persisted, pinned-key Ed25519 envelope.
  signedRelease,
}

String encodeCurriculumPackageTrustKind(CurriculumPackageTrustKind value) =>
    switch (value) {
      CurriculumPackageTrustKind.legacyCallerHashes => 'legacy_caller_hashes',
      CurriculumPackageTrustKind.bundledArtifact => 'bundled_artifact',
      CurriculumPackageTrustKind.signedRelease => 'signed_release',
    };

CurriculumPackageTrustKind decodeCurriculumPackageTrustKind(Object? value) =>
    switch (value) {
      null ||
      'legacy_caller_hashes' => CurriculumPackageTrustKind.legacyCallerHashes,
      'bundled_artifact' => CurriculumPackageTrustKind.bundledArtifact,
      'signed_release' => CurriculumPackageTrustKind.signedRelease,
      _ => throw CurriculumPackageException(
        'corrupt_registry',
        'Unknown curriculum package trust kind $value.',
      ),
    };

String encodeCurriculumActivationTarget(CurriculumActivationTarget value) =>
    switch (value) {
      CurriculumActivationTarget.preview => 'preview',
      CurriculumActivationTarget.learner => 'learner',
    };

CurriculumActivationTarget decodeCurriculumActivationTarget(Object? value) =>
    switch (value) {
      'preview' => CurriculumActivationTarget.preview,
      'learner' => CurriculumActivationTarget.learner,
      _ => throw CurriculumPackageException(
        'invalid_activation_target',
        'Unknown curriculum activation target $value.',
      ),
    };

final class CurriculumPackageException implements Exception {
  const CurriculumPackageException(this.code, this.message, [this.cause]);

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'CurriculumPackageException($code): $message';
}

final class CurriculumPackageRecord {
  CurriculumPackageRecord({
    required this.candidateId,
    required this.releaseId,
    required this.sourceId,
    required this.canonicalSha256,
    required this.transportSha256,
    required this.transportByteLength,
    required this.canonicalByteLength,
    required this.releaseChannel,
    required this.contentState,
    required this.isScaffold,
    required this.trustKind,
    required DateTime installedAt,
    this.trustKeyId,
    this.trustEnvelopeSha256,
    DateTime? trustSignedAt,
    this.chapterShard,
  }) : installedAt = installedAt.toUtc(),
       trustSignedAt = trustSignedAt?.toUtc() {
    final isSigned = trustKind == CurriculumPackageTrustKind.signedRelease;
    if (isSigned !=
        (trustKeyId != null &&
            trustEnvelopeSha256 != null &&
            this.trustSignedAt != null)) {
      throw ArgumentError(
        'Signed package records require complete signing provenance; '
        'non-signed records must not carry it.',
      );
    }
    if (chapterShard != null && !isChapterShard) {
      throw ArgumentError(
        'Only chapter-shard records may carry chapter shard provenance.',
      );
    }
  }

  final String candidateId;
  final CurriculumReleaseId releaseId;
  final CurriculumSourceId sourceId;
  final String canonicalSha256;
  final String transportSha256;
  final int transportByteLength;
  final int canonicalByteLength;
  final String releaseChannel;
  final String contentState;
  final bool isScaffold;
  final CurriculumPackageTrustKind trustKind;
  final String? trustKeyId;
  final String? trustEnvelopeSha256;
  final DateTime? trustSignedAt;

  /// Immutable source placement for a chapter-sized package. Full-release
  /// packages retain a null value for backwards-compatible registry records.
  final CurriculumChapterShard? chapterShard;
  final DateTime installedAt;

  bool get isChapterShard => chapterShard != null;

  Map<String, Object?> toJson() => {
    'candidateId': candidateId,
    'releaseId': releaseId,
    'sourceId': sourceId,
    'canonicalSha256': canonicalSha256,
    'transportSha256': transportSha256,
    'transportByteLength': transportByteLength,
    'canonicalByteLength': canonicalByteLength,
    'releaseChannel': releaseChannel,
    'contentState': contentState,
    'isScaffold': isScaffold,
    'trustKind': encodeCurriculumPackageTrustKind(trustKind),
    'trustKeyId': trustKeyId,
    'trustEnvelopeSha256': trustEnvelopeSha256,
    'trustSignedAt': trustSignedAt?.toIso8601String(),
    'chapterShard': chapterShard?.toJson(),
    'installedAt': installedAt.toIso8601String(),
  };

  factory CurriculumPackageRecord.fromJson(Map<String, Object?> json) =>
      CurriculumPackageRecord(
        candidateId: _string(json, 'candidateId'),
        releaseId: _string(json, 'releaseId'),
        sourceId: _string(json, 'sourceId'),
        canonicalSha256: _sha(json, 'canonicalSha256'),
        transportSha256: _sha(json, 'transportSha256'),
        transportByteLength: _nonNegativeInt(json, 'transportByteLength'),
        canonicalByteLength: _positiveInt(json, 'canonicalByteLength'),
        releaseChannel: _string(json, 'releaseChannel'),
        contentState: _string(json, 'contentState'),
        isScaffold: _bool(json, 'isScaffold'),
        trustKind: decodeCurriculumPackageTrustKind(json['trustKind']),
        trustKeyId: _optionalString(json, 'trustKeyId'),
        trustEnvelopeSha256: _optionalSha(json, 'trustEnvelopeSha256'),
        trustSignedAt: _optionalDate(json, 'trustSignedAt'),
        chapterShard: json['chapterShard'] == null
            ? null
            : CurriculumChapterShard.fromJson(
                _objectMap(json['chapterShard'], 'chapterShard'),
              ),
        installedAt: _date(json, 'installedAt'),
      );
}

/// Stable chapter placement for a signed content shard. It keeps a manifest
/// fragment tied to its source chapter without deriving identity from mutable
/// titles or the downloaded file name.
final class CurriculumChapterShard {
  CurriculumChapterShard({
    required this.courseSourceKey,
    required this.chapterSourceKey,
    required this.ordinal,
  }) {
    _sourceKey(courseSourceKey, 'courseSourceKey');
    _sourceKey(chapterSourceKey, 'chapterSourceKey');
    if (ordinal < 1) {
      throw ArgumentError.value(
        ordinal,
        'ordinal',
        'Expected a positive ordinal.',
      );
    }
  }

  final String courseSourceKey;
  final String chapterSourceKey;
  final int ordinal;

  Map<String, Object?> toJson() => {
    'courseSourceKey': courseSourceKey,
    'chapterSourceKey': chapterSourceKey,
    'ordinal': ordinal,
  };

  factory CurriculumChapterShard.fromJson(Map<String, Object?> json) =>
      CurriculumChapterShard(
        courseSourceKey: _sourceKey(
          _string(json, 'courseSourceKey'),
          'courseSourceKey',
        ),
        chapterSourceKey: _sourceKey(
          _string(json, 'chapterSourceKey'),
          'chapterSourceKey',
        ),
        ordinal: _positiveInt(json, 'ordinal'),
      );
}

final class CurriculumQuarantineRecord {
  CurriculumQuarantineRecord({
    required this.candidateId,
    required this.transportSha256,
    required this.transportByteLength,
    required this.code,
    required this.message,
    required DateTime failedAt,
    this.observedCanonicalSha256,
  }) : failedAt = failedAt.toUtc();

  final String candidateId;
  final String transportSha256;
  final int transportByteLength;
  final String code;
  final String message;
  final String? observedCanonicalSha256;
  final DateTime failedAt;

  Map<String, Object?> toJson() => {
    'candidateId': candidateId,
    'transportSha256': transportSha256,
    'transportByteLength': transportByteLength,
    'code': code,
    'message': message,
    'observedCanonicalSha256': observedCanonicalSha256,
    'failedAt': failedAt.toIso8601String(),
  };

  factory CurriculumQuarantineRecord.fromJson(Map<String, Object?> json) =>
      CurriculumQuarantineRecord(
        candidateId: _string(json, 'candidateId'),
        transportSha256: _sha(json, 'transportSha256'),
        transportByteLength: _nonNegativeInt(json, 'transportByteLength'),
        code: _string(json, 'code'),
        message: _string(json, 'message'),
        observedCanonicalSha256: _optionalSha(json, 'observedCanonicalSha256'),
        failedAt: _date(json, 'failedAt'),
      );
}

final class CurriculumActivationReceipt {
  CurriculumActivationReceipt({
    required this.id,
    required this.target,
    required this.releaseId,
    required DateTime activatedAt,
    this.previousReleaseId,
    this.rollbackOfReceiptId,
  }) : activatedAt = activatedAt.toUtc();

  final String id;
  final CurriculumActivationTarget target;
  final CurriculumReleaseId releaseId;
  final CurriculumReleaseId? previousReleaseId;
  final String? rollbackOfReceiptId;
  final DateTime activatedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'target': encodeCurriculumActivationTarget(target),
    'releaseId': releaseId,
    'previousReleaseId': previousReleaseId,
    'rollbackOfReceiptId': rollbackOfReceiptId,
    'activatedAt': activatedAt.toIso8601String(),
  };

  factory CurriculumActivationReceipt.fromJson(Map<String, Object?> json) =>
      CurriculumActivationReceipt(
        id: _string(json, 'id'),
        target: decodeCurriculumActivationTarget(json['target']),
        releaseId: _string(json, 'releaseId'),
        previousReleaseId: _optionalString(json, 'previousReleaseId'),
        rollbackOfReceiptId: _optionalString(json, 'rollbackOfReceiptId'),
        activatedAt: _date(json, 'activatedAt'),
      );
}

/// Durable evidence that a trusted candidate replaced a locally corrupt body
/// without changing the immutable release identity.
final class CurriculumPackageRecoveryReceipt {
  CurriculumPackageRecoveryReceipt({
    required this.id,
    required this.candidateId,
    required this.releaseId,
    required this.previousCanonicalSha256,
    required this.restoredCanonicalSha256,
    required this.previousTransportSha256,
    required this.restoredTransportSha256,
    required DateTime restoredAt,
  }) : restoredAt = restoredAt.toUtc();

  final String id;
  final String candidateId;
  final CurriculumReleaseId releaseId;
  final String previousCanonicalSha256;
  final String restoredCanonicalSha256;
  final String previousTransportSha256;
  final String restoredTransportSha256;
  final DateTime restoredAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'candidateId': candidateId,
    'releaseId': releaseId,
    'previousCanonicalSha256': previousCanonicalSha256,
    'restoredCanonicalSha256': restoredCanonicalSha256,
    'previousTransportSha256': previousTransportSha256,
    'restoredTransportSha256': restoredTransportSha256,
    'restoredAt': restoredAt.toIso8601String(),
  };

  factory CurriculumPackageRecoveryReceipt.fromJson(
    Map<String, Object?> json,
  ) => CurriculumPackageRecoveryReceipt(
    id: _string(json, 'id'),
    candidateId: _string(json, 'candidateId'),
    releaseId: _string(json, 'releaseId'),
    previousCanonicalSha256: _sha(json, 'previousCanonicalSha256'),
    restoredCanonicalSha256: _sha(json, 'restoredCanonicalSha256'),
    previousTransportSha256: _sha(json, 'previousTransportSha256'),
    restoredTransportSha256: _sha(json, 'restoredTransportSha256'),
    restoredAt: _date(json, 'restoredAt'),
  );
}

final class CurriculumInstallResult {
  const CurriculumInstallResult({
    required this.record,
    required this.alreadyInstalled,
  });

  final CurriculumPackageRecord record;
  final bool alreadyInstalled;
}

final class CurriculumPackageRestoreResult {
  const CurriculumPackageRestoreResult({
    required this.record,
    required this.receipt,
  });

  final CurriculumPackageRecord record;
  final CurriculumPackageRecoveryReceipt receipt;
}

final class CurriculumActivationResult {
  const CurriculumActivationResult({
    required this.receipt,
    required this.changed,
  });

  final CurriculumActivationReceipt receipt;
  final bool changed;
}

final class CurriculumPackageIntegrityIssue {
  const CurriculumPackageIntegrityIssue({
    required this.code,
    required this.message,
    this.releaseId,
    this.target,
  });

  final String code;
  final String message;
  final CurriculumReleaseId? releaseId;
  final CurriculumActivationTarget? target;
}

String _string(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! String || value.trim().isEmpty || value != value.trim()) {
    throw CurriculumPackageException(
      'corrupt_registry',
      '$field must be a non-empty trimmed string.',
    );
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty || value != value.trim()) {
    throw CurriculumPackageException(
      'corrupt_registry',
      '$field must be null or a non-empty trimmed string.',
    );
  }
  return value;
}

String _sha(Map<String, Object?> json, String field) {
  final value = _string(json, field);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw CurriculumPackageException(
      'corrupt_registry',
      '$field must be a lowercase SHA-256 value.',
    );
  }
  return value;
}

String? _optionalSha(Map<String, Object?> json, String field) {
  if (json[field] == null) return null;
  return _sha(json, field);
}

int _positiveInt(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! int || value < 1) {
    throw CurriculumPackageException(
      'corrupt_registry',
      '$field must be a positive integer.',
    );
  }
  return value;
}

int _nonNegativeInt(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! int || value < 0) {
    throw CurriculumPackageException(
      'corrupt_registry',
      '$field must be a non-negative integer.',
    );
  }
  return value;
}

bool _bool(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! bool) {
    throw CurriculumPackageException(
      'corrupt_registry',
      '$field must be boolean.',
    );
  }
  return value;
}

DateTime _date(Map<String, Object?> json, String field) {
  final value = _string(json, field);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw CurriculumPackageException(
      'corrupt_registry',
      '$field must be an ISO-8601 timestamp.',
    );
  }
  return parsed.toUtc();
}

DateTime? _optionalDate(Map<String, Object?> json, String field) {
  if (json[field] == null) return null;
  return _date(json, field);
}

Map<String, Object?> _objectMap(Object? value, String field) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw CurriculumPackageException(
      'corrupt_registry',
      '$field must be a JSON object.',
    );
  }
  return Map<String, Object?>.from(value);
}

String _sourceKey(String value, String field) {
  if (!CurriculumIdentity.isValidSourceKey(value)) {
    throw CurriculumPackageException(
      'corrupt_registry',
      '$field must be a normalized curriculum source key.',
    );
  }
  return value;
}
