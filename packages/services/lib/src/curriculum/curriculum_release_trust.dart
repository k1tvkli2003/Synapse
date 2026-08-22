import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';

import 'curriculum_package_models.dart';

/// The detached, publisher-signed authorization for one exact curriculum
/// candidate. The signature covers [signingBytes], never this object with the
/// signature field included.
final class CurriculumSignedReleaseEnvelope {
  CurriculumSignedReleaseEnvelope({
    required this.keyId,
    required this.sourceId,
    required this.releaseId,
    required this.releaseChannel,
    required this.canonicalSha256,
    required this.canonicalByteLength,
    required this.transportSha256,
    required this.transportByteLength,
    required DateTime signedAt,
    required List<int> signatureBytes,
  }) : signedAt = signedAt.toUtc(),
       signatureBytes = List<int>.unmodifiable(signatureBytes) {
    _requireStableToken(keyId, 'keyId');
    _requireStableToken(sourceId, 'sourceId');
    _requireStableToken(releaseId, 'releaseId');
    _requireSha(canonicalSha256, 'canonicalSha256');
    _requireSha(transportSha256, 'transportSha256');
    if (canonicalByteLength < 1) {
      throw ArgumentError.value(
        canonicalByteLength,
        'canonicalByteLength',
        'Expected a positive byte length.',
      );
    }
    if (transportByteLength < 1) {
      throw ArgumentError.value(
        transportByteLength,
        'transportByteLength',
        'Expected a positive byte length.',
      );
    }
    if (signatureBytes.length != 64) {
      throw ArgumentError.value(
        signatureBytes.length,
        'signatureBytes',
        'An Ed25519 signature must contain 64 bytes.',
      );
    }
  }

  static const schemaVersion = 1;
  static const algorithm = 'ed25519';
  static const domain = 'synapse.curriculum.release.v1';

  final String keyId;
  final CurriculumSourceId sourceId;
  final CurriculumReleaseId releaseId;
  final CurriculumReleaseChannel releaseChannel;
  final String canonicalSha256;
  final int canonicalByteLength;
  final String transportSha256;
  final int transportByteLength;
  final DateTime signedAt;
  final List<int> signatureBytes;

  Map<String, Object?> get signingPayload => {
    'schemaVersion': schemaVersion,
    'domain': domain,
    'algorithm': algorithm,
    'keyId': keyId,
    'sourceId': sourceId,
    'releaseId': releaseId,
    'releaseChannel': _encodeReleaseChannel(releaseChannel),
    'canonicalSha256': canonicalSha256,
    'canonicalByteLength': canonicalByteLength,
    'transportSha256': transportSha256,
    'transportByteLength': transportByteLength,
    'signedAt': signedAt.toIso8601String(),
  };

  List<int> get signingBytes =>
      List<int>.unmodifiable(utf8.encode(CanonicalJson.encode(signingPayload)));

  String get envelopeSha256 => CanonicalJson.sha256Hex(toJson());

  Map<String, Object?> toJson() => {
    ...signingPayload,
    'signature': _encodeBase64Url(signatureBytes),
  };

  factory CurriculumSignedReleaseEnvelope.fromJson(Map<String, Object?> json) {
    if (json.length != 13 ||
        json['schemaVersion'] != schemaVersion ||
        json['domain'] != domain ||
        json['algorithm'] != algorithm) {
      throw const CurriculumPackageException(
        'invalid_release_envelope',
        'Unsupported or non-canonical curriculum release envelope.',
      );
    }
    try {
      return CurriculumSignedReleaseEnvelope(
        keyId: _requiredString(json, 'keyId'),
        sourceId: _requiredString(json, 'sourceId'),
        releaseId: _requiredString(json, 'releaseId'),
        releaseChannel: _decodeReleaseChannel(json['releaseChannel']),
        canonicalSha256: _requiredString(json, 'canonicalSha256'),
        canonicalByteLength: _positiveInt(json, 'canonicalByteLength'),
        transportSha256: _requiredString(json, 'transportSha256'),
        transportByteLength: _positiveInt(json, 'transportByteLength'),
        signedAt: _requiredDate(json, 'signedAt'),
        signatureBytes: _decodeCanonicalBase64Url(
          _requiredString(json, 'signature'),
        ),
      );
    } on CurriculumPackageException {
      rethrow;
    } on Object catch (error) {
      throw CurriculumPackageException(
        'invalid_release_envelope',
        'Curriculum release envelope fields are invalid.',
        error,
      );
    }
  }
}

/// A compile-time or remotely policy-pinned publisher public key. Private key
/// material never belongs in the application or this model.
final class CurriculumReleaseTrustAnchor {
  CurriculumReleaseTrustAnchor({
    required this.keyId,
    required List<int> publicKeyBytes,
    required Iterable<CurriculumSourceId> allowedSourceIds,
    required Iterable<CurriculumReleaseChannel> allowedChannels,
    required DateTime validFrom,
    DateTime? validUntil,
    this.revoked = false,
  }) : publicKeyBytes = List<int>.unmodifiable(publicKeyBytes),
       allowedSourceIds = Set<CurriculumSourceId>.unmodifiable(
         allowedSourceIds,
       ),
       allowedChannels = Set<CurriculumReleaseChannel>.unmodifiable(
         allowedChannels,
       ),
       validFrom = validFrom.toUtc(),
       validUntil = validUntil?.toUtc() {
    _requireStableToken(keyId, 'keyId');
    if (publicKeyBytes.length != 32) {
      throw ArgumentError.value(
        publicKeyBytes.length,
        'publicKeyBytes',
        'An Ed25519 public key must contain 32 bytes.',
      );
    }
    if (this.allowedSourceIds.isEmpty || this.allowedChannels.isEmpty) {
      throw ArgumentError(
        'A release trust anchor must scope at least one source and channel.',
      );
    }
    for (final sourceId in this.allowedSourceIds) {
      _requireStableToken(sourceId, 'allowedSourceIds');
    }
    if (this.validUntil != null && !this.validUntil!.isAfter(this.validFrom)) {
      throw ArgumentError('validUntil must be later than validFrom.');
    }
  }

  final String keyId;
  final List<int> publicKeyBytes;
  final Set<CurriculumSourceId> allowedSourceIds;
  final Set<CurriculumReleaseChannel> allowedChannels;
  final DateTime validFrom;
  final DateTime? validUntil;

  /// Revocation is fail-closed for every signature from this key, including
  /// signatures created before the revocation policy was shipped.
  final bool revoked;
}

abstract interface class CurriculumReleaseTrustVerifier {
  Future<void> verifyCandidate({
    required CurriculumManifest manifest,
    required String canonicalSha256,
    required int canonicalByteLength,
    required String transportSha256,
    required int transportByteLength,
    required CurriculumSignedReleaseEnvelope envelope,
  });
}

/// Cross-platform Ed25519 verification against a fixed, source/channel-scoped
/// keyring. A missing, unknown, expired, future-dated, revoked, or mismatched
/// key/envelope fails closed.
final class PinnedEd25519CurriculumReleaseTrustVerifier
    implements CurriculumReleaseTrustVerifier {
  PinnedEd25519CurriculumReleaseTrustVerifier({
    required Iterable<CurriculumReleaseTrustAnchor> anchors,
    required this.clock,
    this.maximumFutureClockSkew = const Duration(minutes: 5),
    Ed25519? algorithm,
  }) : _algorithm = algorithm ?? Ed25519(),
       _anchors = _indexAnchors(anchors) {
    if (maximumFutureClockSkew.isNegative) {
      throw ArgumentError.value(
        maximumFutureClockSkew,
        'maximumFutureClockSkew',
      );
    }
  }

  final Map<String, CurriculumReleaseTrustAnchor> _anchors;
  final Clock clock;
  final Ed25519 _algorithm;
  final Duration maximumFutureClockSkew;

  @override
  Future<void> verifyCandidate({
    required CurriculumManifest manifest,
    required String canonicalSha256,
    required int canonicalByteLength,
    required String transportSha256,
    required int transportByteLength,
    required CurriculumSignedReleaseEnvelope envelope,
  }) async {
    final anchor = _anchors[envelope.keyId];
    if (anchor == null) {
      throw const CurriculumPackageException(
        'unknown_release_signing_key',
        'The curriculum release was signed by an unknown key.',
      );
    }
    if (anchor.revoked) {
      throw const CurriculumPackageException(
        'revoked_release_signing_key',
        'The curriculum release signing key is revoked.',
      );
    }
    if (!anchor.allowedSourceIds.contains(manifest.source.id) ||
        !anchor.allowedChannels.contains(manifest.release.channel)) {
      throw const CurriculumPackageException(
        'release_signing_scope_mismatch',
        'The signing key is not authorized for this source and channel.',
      );
    }
    if (envelope.sourceId != manifest.source.id ||
        envelope.releaseId != manifest.release.id ||
        envelope.releaseChannel != manifest.release.channel ||
        envelope.canonicalSha256 != canonicalSha256 ||
        envelope.canonicalByteLength != canonicalByteLength ||
        envelope.transportSha256 != transportSha256 ||
        envelope.transportByteLength != transportByteLength) {
      throw const CurriculumPackageException(
        'signed_release_mismatch',
        'The signed authorization does not match the candidate bytes.',
      );
    }
    final now = clock.nowUtc();
    if (envelope.signedAt.isBefore(anchor.validFrom) ||
        (anchor.validUntil != null &&
            envelope.signedAt.isAfter(anchor.validUntil!)) ||
        envelope.signedAt.isBefore(manifest.release.createdAt) ||
        envelope.signedAt.isAfter(now.add(maximumFutureClockSkew))) {
      throw const CurriculumPackageException(
        'release_signature_time_invalid',
        'The release signature is outside its accepted time window.',
      );
    }
    final publicKey = SimplePublicKey(
      anchor.publicKeyBytes,
      type: KeyPairType.ed25519,
    );
    final signature = Signature(envelope.signatureBytes, publicKey: publicKey);
    final verified = await _algorithm.verify(
      envelope.signingBytes,
      signature: signature,
    );
    if (!verified) {
      throw const CurriculumPackageException(
        'release_signature_invalid',
        'The curriculum release signature is invalid.',
      );
    }
  }

  static Map<String, CurriculumReleaseTrustAnchor> _indexAnchors(
    Iterable<CurriculumReleaseTrustAnchor> anchors,
  ) {
    final result = <String, CurriculumReleaseTrustAnchor>{};
    for (final anchor in anchors) {
      if (result.containsKey(anchor.keyId)) {
        throw ArgumentError.value(
          anchor.keyId,
          'anchors',
          'Duplicate curriculum release signing key ID.',
        );
      }
      result[anchor.keyId] = anchor;
    }
    return Map.unmodifiable(result);
  }
}

String _encodeReleaseChannel(CurriculumReleaseChannel value) => switch (value) {
  CurriculumReleaseChannel.internal => 'internal',
  CurriculumReleaseChannel.beta => 'beta',
  CurriculumReleaseChannel.stable => 'stable',
};

CurriculumReleaseChannel _decodeReleaseChannel(Object? value) =>
    switch (value) {
      'internal' => CurriculumReleaseChannel.internal,
      'beta' => CurriculumReleaseChannel.beta,
      'stable' => CurriculumReleaseChannel.stable,
      _ => throw const CurriculumPackageException(
        'invalid_release_envelope',
        'Unknown release channel in signed envelope.',
      ),
    };

String _encodeBase64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

List<int> _decodeCanonicalBase64Url(String value) {
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
    throw const CurriculumPackageException(
      'invalid_release_envelope',
      'Signature must use unpadded base64url.',
    );
  }
  final padding = '=' * ((4 - value.length % 4) % 4);
  final decoded = base64Url.decode('$value$padding');
  if (_encodeBase64Url(decoded) != value) {
    throw const CurriculumPackageException(
      'invalid_release_envelope',
      'Signature base64url is not canonical.',
    );
  }
  return decoded;
}

String _requiredString(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw CurriculumPackageException(
      'invalid_release_envelope',
      '$field must be a non-empty trimmed string.',
    );
  }
  return value;
}

int _positiveInt(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! int || value < 1) {
    throw CurriculumPackageException(
      'invalid_release_envelope',
      '$field must be a positive integer.',
    );
  }
  return value;
}

DateTime _requiredDate(Map<String, Object?> json, String field) {
  final value = _requiredString(json, field);
  final parsed = DateTime.parse(value);
  if (!value.endsWith('Z') || parsed.toUtc().toIso8601String() != value) {
    throw CurriculumPackageException(
      'invalid_release_envelope',
      '$field must be a canonical UTC timestamp.',
    );
  }
  return parsed.toUtc();
}

void _requireStableToken(String value, String field) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$').hasMatch(value)) {
    throw ArgumentError.value(value, field, 'Expected a stable token.');
  }
}

void _requireSha(String value, String field) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  }
}
