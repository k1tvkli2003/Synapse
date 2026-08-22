import 'package:equatable/equatable.dart';

import '../models/ids.dart';
import '../serialization/canonical_json.dart';

final _idPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$');
final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
final _base64UrlPattern = RegExp(r'^[A-Za-z0-9_-]+={0,2}$');

String _id(String value, String field) {
  if (value != value.trim() || !_idPattern.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'Invalid stable identifier.');
  }
  return value;
}

String _boundedText(String value, String field, int maxLength) {
  if (value != value.trim() || value.isEmpty || value.length > maxLength) {
    throw ArgumentError.value(
      value,
      field,
      'Must be trimmed and between 1 and $maxLength characters.',
    );
  }
  return value;
}

String _base64Url(String value, String field, {int maxLength = 8192}) {
  if (value.isEmpty ||
      value.length > maxLength ||
      !_base64UrlPattern.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'Invalid base64url value.');
  }
  return value;
}

String _sha256(String value, String field) {
  if (!_sha256Pattern.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  }
  return value;
}

DateTime _utc(DateTime value) => value.toUtc();

DateTime _date(Object? value, String field) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) {
    throw FormatException('$field must be an ISO-8601 timestamp.');
  }
  return parsed.toUtc();
}

enum PersonalDevicePlatform { windows, android, web }

enum DeviceTrustRole { root, trusted }

enum PairingSessionState { pending, approved, consumed, expired, rejected }

enum PersonalSyncEventKind {
  attempt,
  reward,
  studyHistory,
  progress,
  mastery,
  note,
  bookmark,
  readingPosition,
  setting,
  deviceReceipt,
}

enum PersonalSyncMergePolicy {
  appendOnly,
  monotonicMaximum,
  lastWriteWins,
  tombstoneWins,
}

enum PersonalContentChannel { internal }

T _enum<T extends Enum>(Iterable<T> values, Object? raw, String field) {
  if (raw is! String) throw FormatException('$field must be a string.');
  return values.firstWhere(
    (value) => value.name == raw,
    orElse: () => throw FormatException('Unknown $field: $raw'),
  );
}

final class PersonalWorkspace extends Equatable {
  PersonalWorkspace({
    required this.id,
    required this.keyVersion,
    required this.recoveryGeneration,
    required DateTime createdAt,
  }) : createdAt = _utc(createdAt) {
    _id(id, 'id');
    if (keyVersion < 1) throw ArgumentError.value(keyVersion, 'keyVersion');
    if (recoveryGeneration < 1) {
      throw ArgumentError.value(recoveryGeneration, 'recoveryGeneration');
    }
  }

  final PersonalWorkspaceId id;
  final int keyVersion;
  final int recoveryGeneration;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'keyVersion': keyVersion,
    'recoveryGeneration': recoveryGeneration,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PersonalWorkspace.fromJson(Map<String, Object?> json) =>
      PersonalWorkspace(
        id: json['id'] as String,
        keyVersion: json['keyVersion'] as int,
        recoveryGeneration: json['recoveryGeneration'] as int,
        createdAt: _date(json['createdAt'], 'createdAt'),
      );

  @override
  List<Object?> get props => [id, keyVersion, recoveryGeneration, createdAt];
}

final class TrustedDevice extends Equatable {
  TrustedDevice({
    required this.id,
    required this.workspaceId,
    required this.label,
    required this.platform,
    required this.role,
    required this.signingPublicKey,
    required this.encryptionPublicKey,
    required DateTime createdAt,
    required DateTime lastSeenAt,
    DateTime? revokedAt,
  }) : createdAt = _utc(createdAt),
       lastSeenAt = _utc(lastSeenAt),
       revokedAt = revokedAt?.toUtc() {
    _id(id, 'id');
    _id(workspaceId, 'workspaceId');
    _boundedText(label, 'label', 80);
    _base64Url(signingPublicKey, 'signingPublicKey', maxLength: 256);
    _base64Url(encryptionPublicKey, 'encryptionPublicKey', maxLength: 256);
  }

  final TrustedDeviceId id;
  final PersonalWorkspaceId workspaceId;
  final String label;
  final PersonalDevicePlatform platform;
  final DeviceTrustRole role;
  final String signingPublicKey;
  final String encryptionPublicKey;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final DateTime? revokedAt;

  bool get isActive => revokedAt == null;

  Map<String, Object?> toJson() => {
    'id': id,
    'workspaceId': workspaceId,
    'label': label,
    'platform': platform.name,
    'role': role.name,
    'signingPublicKey': signingPublicKey,
    'encryptionPublicKey': encryptionPublicKey,
    'createdAt': createdAt.toIso8601String(),
    'lastSeenAt': lastSeenAt.toIso8601String(),
    'revokedAt': revokedAt?.toIso8601String(),
  };

  factory TrustedDevice.fromJson(Map<String, Object?> json) => TrustedDevice(
    id: json['id'] as String,
    workspaceId: json['workspaceId'] as String,
    label: json['label'] as String,
    platform: _enum(
      PersonalDevicePlatform.values,
      json['platform'],
      'platform',
    ),
    role: _enum(DeviceTrustRole.values, json['role'], 'role'),
    signingPublicKey: json['signingPublicKey'] as String,
    encryptionPublicKey: json['encryptionPublicKey'] as String,
    createdAt: _date(json['createdAt'], 'createdAt'),
    lastSeenAt: _date(json['lastSeenAt'], 'lastSeenAt'),
    revokedAt: json['revokedAt'] == null
        ? null
        : _date(json['revokedAt'], 'revokedAt'),
  );

  @override
  List<Object?> get props => [
    id,
    workspaceId,
    label,
    platform,
    role,
    signingPublicKey,
    encryptionPublicKey,
    createdAt,
    lastSeenAt,
    revokedAt,
  ];
}

final class PairingSession extends Equatable {
  PairingSession({
    required this.id,
    this.pairingCode,
    this.workspaceId,
    required this.candidateDeviceId,
    required this.candidateLabel,
    required this.candidatePlatform,
    required this.candidateSigningPublicKey,
    required this.candidateEncryptionPublicKey,
    required this.state,
    required DateTime createdAt,
    required DateTime expiresAt,
    DateTime? approvedAt,
    this.sealedWorkspaceKey,
  }) : createdAt = _utc(createdAt),
       expiresAt = _utc(expiresAt),
       approvedAt = approvedAt?.toUtc() {
    _id(id, 'id');
    if (pairingCode != null) {
      _boundedText(pairingCode!, 'pairingCode', 16);
    }
    if (workspaceId != null) _id(workspaceId!, 'workspaceId');
    _id(candidateDeviceId, 'candidateDeviceId');
    _boundedText(candidateLabel, 'candidateLabel', 80);
    _base64Url(
      candidateSigningPublicKey,
      'candidateSigningPublicKey',
      maxLength: 256,
    );
    _base64Url(
      candidateEncryptionPublicKey,
      'candidateEncryptionPublicKey',
      maxLength: 256,
    );
    if (!expiresAt.isAfter(createdAt)) {
      throw ArgumentError('Pairing expiry must follow creation.');
    }
    if (sealedWorkspaceKey != null) {
      _base64Url(sealedWorkspaceKey!, 'sealedWorkspaceKey', maxLength: 4096);
    }
  }

  final PairingSessionId id;

  /// Present only on the candidate's short-lived pairing payload. The service
  /// never replays this proof after it has been approved or consumed.
  final String? pairingCode;
  final PersonalWorkspaceId? workspaceId;
  final TrustedDeviceId candidateDeviceId;
  final String candidateLabel;
  final PersonalDevicePlatform candidatePlatform;
  final String candidateSigningPublicKey;
  final String candidateEncryptionPublicKey;
  final PairingSessionState state;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? approvedAt;
  final String? sealedWorkspaceKey;

  bool isExpiredAt(DateTime now) => !now.toUtc().isBefore(expiresAt);

  Map<String, Object?> toJson() => {
    'id': id,
    if (pairingCode != null) 'pairingCode': pairingCode,
    if (workspaceId != null) 'workspaceId': workspaceId,
    'candidateDeviceId': candidateDeviceId,
    'candidateLabel': candidateLabel,
    'candidatePlatform': candidatePlatform.name,
    'candidateSigningPublicKey': candidateSigningPublicKey,
    'candidateEncryptionPublicKey': candidateEncryptionPublicKey,
    'state': state.name,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
    'approvedAt': approvedAt?.toIso8601String(),
    'sealedWorkspaceKey': sealedWorkspaceKey,
  };

  factory PairingSession.fromJson(Map<String, Object?> json) => PairingSession(
    id: json['id'] as String,
    pairingCode: json['pairingCode'] as String?,
    workspaceId: json['workspaceId'] as String?,
    candidateDeviceId: json['candidateDeviceId'] as String,
    candidateLabel: json['candidateLabel'] as String,
    candidatePlatform: _enum(
      PersonalDevicePlatform.values,
      json['candidatePlatform'],
      'candidatePlatform',
    ),
    candidateSigningPublicKey: json['candidateSigningPublicKey'] as String,
    candidateEncryptionPublicKey:
        json['candidateEncryptionPublicKey'] as String,
    state: _enum(PairingSessionState.values, json['state'], 'state'),
    createdAt: _date(json['createdAt'], 'createdAt'),
    expiresAt: _date(json['expiresAt'], 'expiresAt'),
    approvedAt: json['approvedAt'] == null
        ? null
        : _date(json['approvedAt'], 'approvedAt'),
    sealedWorkspaceKey: json['sealedWorkspaceKey'] as String?,
  );

  @override
  List<Object?> get props => [
    id,
    pairingCode,
    workspaceId,
    candidateDeviceId,
    candidateLabel,
    candidatePlatform,
    candidateSigningPublicKey,
    candidateEncryptionPublicKey,
    state,
    createdAt,
    expiresAt,
    approvedAt,
    sealedWorkspaceKey,
  ];
}

final class EncryptedSyncEvent extends Equatable {
  EncryptedSyncEvent({
    required this.id,
    required this.workspaceId,
    required this.deviceId,
    required this.stream,
    required this.entityHash,
    required this.kind,
    required this.mergePolicy,
    required this.logicalRevision,
    required this.keyVersion,
    required this.idempotencyKey,
    required DateTime clientCreatedAt,
    required this.nonce,
    required this.cipherText,
    required this.authenticationTag,
    this.tombstone = false,
    this.serverSequence,
  }) : clientCreatedAt = _utc(clientCreatedAt) {
    _id(id, 'id');
    _id(workspaceId, 'workspaceId');
    _id(deviceId, 'deviceId');
    _boundedText(stream, 'stream', 80);
    _sha256(entityHash, 'entityHash');
    _id(idempotencyKey, 'idempotencyKey');
    if (logicalRevision < 1) {
      throw ArgumentError.value(logicalRevision, 'logicalRevision');
    }
    if (keyVersion < 1) throw ArgumentError.value(keyVersion, 'keyVersion');
    if (serverSequence != null && serverSequence! < 1) {
      throw ArgumentError.value(serverSequence, 'serverSequence');
    }
    _base64Url(nonce, 'nonce', maxLength: 128);
    _base64Url(cipherText, 'cipherText', maxLength: 4 * 1024 * 1024);
    _base64Url(authenticationTag, 'authenticationTag', maxLength: 128);
  }

  final EncryptedSyncEventId id;
  final PersonalWorkspaceId workspaceId;
  final TrustedDeviceId deviceId;
  final String stream;
  final String entityHash;
  final PersonalSyncEventKind kind;
  final PersonalSyncMergePolicy mergePolicy;
  final int logicalRevision;
  final int keyVersion;
  final String idempotencyKey;
  final DateTime clientCreatedAt;
  final String nonce;
  final String cipherText;
  final String authenticationTag;
  final bool tombstone;
  final int? serverSequence;

  String canonicalAssociatedData() => CanonicalJson.encode({
    'id': id,
    'workspaceId': workspaceId,
    'deviceId': deviceId,
    'stream': stream,
    'entityHash': entityHash,
    'kind': kind.name,
    'mergePolicy': mergePolicy.name,
    'logicalRevision': logicalRevision,
    'keyVersion': keyVersion,
    'idempotencyKey': idempotencyKey,
    'clientCreatedAt': clientCreatedAt.toIso8601String(),
    'tombstone': tombstone,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'workspaceId': workspaceId,
    'deviceId': deviceId,
    'stream': stream,
    'entityHash': entityHash,
    'kind': kind.name,
    'mergePolicy': mergePolicy.name,
    'logicalRevision': logicalRevision,
    'keyVersion': keyVersion,
    'idempotencyKey': idempotencyKey,
    'clientCreatedAt': clientCreatedAt.toIso8601String(),
    'nonce': nonce,
    'cipherText': cipherText,
    'authenticationTag': authenticationTag,
    'tombstone': tombstone,
    'serverSequence': serverSequence,
  };

  factory EncryptedSyncEvent.fromJson(Map<String, Object?> json) =>
      EncryptedSyncEvent(
        id: json['id'] as String,
        workspaceId: json['workspaceId'] as String,
        deviceId: json['deviceId'] as String,
        stream: json['stream'] as String,
        entityHash: json['entityHash'] as String,
        kind: _enum(PersonalSyncEventKind.values, json['kind'], 'event kind'),
        mergePolicy: _enum(
          PersonalSyncMergePolicy.values,
          json['mergePolicy'],
          'merge policy',
        ),
        logicalRevision: json['logicalRevision'] as int,
        keyVersion: json['keyVersion'] as int,
        idempotencyKey: json['idempotencyKey'] as String,
        clientCreatedAt: _date(json['clientCreatedAt'], 'clientCreatedAt'),
        nonce: json['nonce'] as String,
        cipherText: json['cipherText'] as String,
        authenticationTag: json['authenticationTag'] as String,
        tombstone: json['tombstone'] as bool? ?? false,
        serverSequence: json['serverSequence'] as int?,
      );

  @override
  List<Object?> get props => [
    id,
    workspaceId,
    deviceId,
    stream,
    entityHash,
    kind,
    mergePolicy,
    logicalRevision,
    keyVersion,
    idempotencyKey,
    clientCreatedAt,
    nonce,
    cipherText,
    authenticationTag,
    tombstone,
    serverSequence,
  ];
}

final class SyncCheckpoint extends Equatable {
  SyncCheckpoint({
    required this.id,
    required this.workspaceId,
    required this.serverSequence,
    required DateTime updatedAt,
  }) : updatedAt = _utc(updatedAt) {
    _id(id, 'id');
    _id(workspaceId, 'workspaceId');
    if (serverSequence < 0) {
      throw ArgumentError.value(serverSequence, 'serverSequence');
    }
  }

  final SyncCheckpointId id;
  final PersonalWorkspaceId workspaceId;
  final int serverSequence;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'workspaceId': workspaceId,
    'serverSequence': serverSequence,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory SyncCheckpoint.fromJson(Map<String, Object?> json) => SyncCheckpoint(
    id: json['id'] as String,
    workspaceId: json['workspaceId'] as String,
    serverSequence: json['serverSequence'] as int,
    updatedAt: _date(json['updatedAt'], 'updatedAt'),
  );

  @override
  List<Object?> get props => [id, workspaceId, serverSequence, updatedAt];
}

/// The complete detached authorization for one chapter package. It mirrors the
/// curriculum runtime's Ed25519 envelope so the private gateway can transport
/// bytes without becoming the authority that decides whether learners may use
/// them.
final class ChapterPackageAuthorization extends Equatable {
  ChapterPackageAuthorization({
    required this.keyId,
    required this.sourceId,
    required this.releaseId,
    required this.releaseChannel,
    required this.canonicalSha256,
    required this.canonicalByteLength,
    required this.transportSha256,
    required this.transportByteLength,
    required DateTime signedAt,
    required this.signature,
  }) : signedAt = _utc(signedAt) {
    _id(keyId, 'keyId');
    _id(sourceId, 'sourceId');
    _id(releaseId, 'releaseId');
    _sha256(canonicalSha256, 'canonicalSha256');
    _sha256(transportSha256, 'transportSha256');
    if (canonicalByteLength < 1) {
      throw ArgumentError.value(canonicalByteLength, 'canonicalByteLength');
    }
    if (transportByteLength < 1) {
      throw ArgumentError.value(transportByteLength, 'transportByteLength');
    }
    if (signature.isEmpty ||
        signature.contains('=') ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(signature)) {
      throw ArgumentError.value(
        signature,
        'signature',
        'Expected canonical unpadded base64url.',
      );
    }
  }

  static const schemaVersion = 1;
  static const domain = 'synapse.curriculum.release.v1';
  static const algorithm = 'ed25519';

  final String keyId;
  final String sourceId;
  final String releaseId;
  final PersonalContentChannel releaseChannel;
  final String canonicalSha256;
  final int canonicalByteLength;
  final String transportSha256;
  final int transportByteLength;
  final DateTime signedAt;
  final String signature;

  Map<String, Object?> get signingPayload => {
    'schemaVersion': schemaVersion,
    'domain': domain,
    'algorithm': algorithm,
    'keyId': keyId,
    'sourceId': sourceId,
    'releaseId': releaseId,
    'releaseChannel': releaseChannel.name,
    'canonicalSha256': canonicalSha256,
    'canonicalByteLength': canonicalByteLength,
    'transportSha256': transportSha256,
    'transportByteLength': transportByteLength,
    'signedAt': signedAt.toIso8601String(),
  };

  Map<String, Object?> toJson() => {...signingPayload, 'signature': signature};

  factory ChapterPackageAuthorization.fromJson(Map<String, Object?> json) {
    if (json.length != 13 ||
        json['schemaVersion'] != schemaVersion ||
        json['domain'] != domain ||
        json['algorithm'] != algorithm) {
      throw const FormatException('Invalid chapter package authorization.');
    }
    final rawSignedAt = json['signedAt'];
    if (rawSignedAt is! String || !rawSignedAt.endsWith('Z')) {
      throw const FormatException(
        'Chapter authorization must use UTC signedAt.',
      );
    }
    final signedAt = _date(rawSignedAt, 'signedAt');
    if (signedAt.toIso8601String() != rawSignedAt) {
      throw const FormatException(
        'Chapter authorization signedAt is not canonical.',
      );
    }
    return ChapterPackageAuthorization(
      keyId: json['keyId'] as String,
      sourceId: json['sourceId'] as String,
      releaseId: json['releaseId'] as String,
      releaseChannel: _enum(
        PersonalContentChannel.values,
        json['releaseChannel'],
        'releaseChannel',
      ),
      canonicalSha256: json['canonicalSha256'] as String,
      canonicalByteLength: json['canonicalByteLength'] as int,
      transportSha256: json['transportSha256'] as String,
      transportByteLength: json['transportByteLength'] as int,
      signedAt: signedAt,
      signature: json['signature'] as String,
    );
  }

  @override
  List<Object?> get props => [
    keyId,
    sourceId,
    releaseId,
    releaseChannel,
    canonicalSha256,
    canonicalByteLength,
    transportSha256,
    transportByteLength,
    signedAt,
    signature,
  ];
}

final class SignedChapterPackage extends Equatable {
  SignedChapterPackage({
    required this.id,
    required this.releaseId,
    required this.courseSourceKey,
    required this.chapterSourceKey,
    required this.ordinal,
    required this.byteLength,
    required this.sha256,
    required this.signature,
    required this.objectKey,
    this.authorization,
  }) {
    _id(id, 'id');
    _id(releaseId, 'releaseId');
    _boundedText(courseSourceKey, 'courseSourceKey', 160);
    _boundedText(chapterSourceKey, 'chapterSourceKey', 160);
    if (ordinal < 1) throw ArgumentError.value(ordinal, 'ordinal');
    if (byteLength < 1) throw ArgumentError.value(byteLength, 'byteLength');
    _sha256(sha256, 'sha256');
    _base64Url(signature, 'signature', maxLength: 512);
    _boundedText(objectKey, 'objectKey', 500);
    final signed = authorization;
    if (signed != null &&
        (signed.releaseId != releaseId ||
            signed.transportSha256 != sha256 ||
            signed.transportByteLength != byteLength ||
            signed.signature != signature)) {
      throw ArgumentError(
        'Chapter package authorization must exactly match package transport metadata.',
      );
    }
  }

  final ContentPackageId id;
  final String releaseId;
  final String courseSourceKey;
  final String chapterSourceKey;
  final int ordinal;
  final int byteLength;
  final String sha256;
  final String signature;
  final String objectKey;
  final ChapterPackageAuthorization? authorization;

  Map<String, Object?> toJson() => {
    'id': id,
    'releaseId': releaseId,
    'courseSourceKey': courseSourceKey,
    'chapterSourceKey': chapterSourceKey,
    'ordinal': ordinal,
    'byteLength': byteLength,
    'sha256': sha256,
    'signature': signature,
    'objectKey': objectKey,
    if (authorization != null) 'authorization': authorization!.toJson(),
  };

  factory SignedChapterPackage.fromJson(Map<String, Object?> json) =>
      SignedChapterPackage(
        id: json['id'] as String,
        releaseId: json['releaseId'] as String,
        courseSourceKey: json['courseSourceKey'] as String,
        chapterSourceKey: json['chapterSourceKey'] as String,
        ordinal: json['ordinal'] as int,
        byteLength: json['byteLength'] as int,
        sha256: json['sha256'] as String,
        signature: json['signature'] as String,
        objectKey: json['objectKey'] as String,
        authorization: json['authorization'] == null
            ? null
            : ChapterPackageAuthorization.fromJson(
                Map<String, Object?>.from(json['authorization'] as Map),
              ),
      );

  @override
  List<Object?> get props => [
    id,
    releaseId,
    courseSourceKey,
    chapterSourceKey,
    ordinal,
    byteLength,
    sha256,
    signature,
    objectKey,
    authorization,
  ];
}

final class PersonalChannelHead extends Equatable {
  PersonalChannelHead({
    required this.releaseId,
    required this.manifestSha256,
    required this.sequence,
    required DateTime updatedAt,
    this.channel = PersonalContentChannel.internal,
  }) : updatedAt = _utc(updatedAt) {
    _id(releaseId, 'releaseId');
    _sha256(manifestSha256, 'manifestSha256');
    if (sequence < 1) throw ArgumentError.value(sequence, 'sequence');
  }

  final PersonalContentChannel channel;
  final String releaseId;
  final String manifestSha256;
  final int sequence;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'channel': channel.name,
    'releaseId': releaseId,
    'manifestSha256': manifestSha256,
    'sequence': sequence,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory PersonalChannelHead.fromJson(Map<String, Object?> json) =>
      PersonalChannelHead(
        channel: _enum(
          PersonalContentChannel.values,
          json['channel'],
          'content channel',
        ),
        releaseId: json['releaseId'] as String,
        manifestSha256: json['manifestSha256'] as String,
        sequence: json['sequence'] as int,
        updatedAt: _date(json['updatedAt'], 'updatedAt'),
      );

  @override
  List<Object?> get props => [
    channel,
    releaseId,
    manifestSha256,
    sequence,
    updatedAt,
  ];
}

final class ContentManifest extends Equatable {
  ContentManifest({
    required this.schemaVersion,
    required this.head,
    required Iterable<SignedChapterPackage> packages,
  }) : packages = List.unmodifiable(packages) {
    if (schemaVersion != legacySchemaVersion &&
        schemaVersion != currentSchemaVersion) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion');
    }
    if (this.packages.map((item) => item.id).toSet().length !=
        this.packages.length) {
      throw ArgumentError('Content package IDs must be unique.');
    }
    if (this.packages.any((item) => item.releaseId != head.releaseId)) {
      throw ArgumentError('Content packages must match the active release ID.');
    }
    if (this.packages.map((item) => item.chapterSourceKey).toSet().length !=
        this.packages.length) {
      throw ArgumentError('Content chapter source keys must be unique.');
    }
    if (this.packages.map((item) => item.ordinal).toSet().length !=
        this.packages.length) {
      throw ArgumentError('Content chapter ordinals must be unique.');
    }
    for (var index = 1; index < this.packages.length; index++) {
      if (this.packages[index - 1].ordinal >= this.packages[index].ordinal) {
        throw ArgumentError(
          'Content packages must be ordered by chapter ordinal.',
        );
      }
    }
    if (schemaVersion == currentSchemaVersion) {
      if (this.packages.any((item) => item.authorization == null)) {
        throw ArgumentError(
          'Schema v2 content packages require authorization.',
        );
      }
      if (canonicalSha256 != head.manifestSha256) {
        throw ArgumentError(
          'Content manifest head hash does not match canonical metadata.',
        );
      }
    }
  }

  static const legacySchemaVersion = 1;
  static const currentSchemaVersion = 2;

  final int schemaVersion;
  final PersonalChannelHead head;
  final List<SignedChapterPackage> packages;

  /// Canonical content-channel metadata excludes its own digest field and all
  /// object bytes, so it can be independently verified before a package is
  /// downloaded.
  Map<String, Object?> get canonicalPayload => {
    'schemaVersion': schemaVersion,
    'head': {
      'channel': head.channel.name,
      'releaseId': head.releaseId,
      'sequence': head.sequence,
      'updatedAt': head.updatedAt.toIso8601String(),
    },
    'packages': packages.map((item) => item.toJson()).toList(growable: false),
  };

  String get canonicalSha256 => CanonicalJson.sha256Hex(canonicalPayload);

  static String canonicalSha256For({
    required int schemaVersion,
    required PersonalContentChannel channel,
    required String releaseId,
    required int sequence,
    required DateTime updatedAt,
    required Iterable<SignedChapterPackage> packages,
  }) => CanonicalJson.sha256Hex({
    'schemaVersion': schemaVersion,
    'head': {
      'channel': channel.name,
      'releaseId': releaseId,
      'sequence': sequence,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    },
    'packages': packages.map((item) => item.toJson()).toList(growable: false),
  });

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'head': head.toJson(),
    'packages': packages.map((item) => item.toJson()).toList(growable: false),
  };

  factory ContentManifest.fromJson(Map<String, Object?> json) =>
      ContentManifest(
        schemaVersion: json['schemaVersion'] as int,
        head: PersonalChannelHead.fromJson(
          Map<String, Object?>.from(json['head'] as Map),
        ),
        packages: (json['packages'] as List)
            .map(
              (item) => SignedChapterPackage.fromJson(
                Map<String, Object?>.from(item as Map),
              ),
            )
            .toList(growable: false),
      );

  @override
  List<Object?> get props => [schemaVersion, head, packages];
}

final class RecoveryGeneration extends Equatable {
  RecoveryGeneration({
    required this.workspaceId,
    required this.generation,
    required this.verifierSha256,
    required DateTime rotatedAt,
  }) : rotatedAt = _utc(rotatedAt) {
    _id(workspaceId, 'workspaceId');
    if (generation < 1) throw ArgumentError.value(generation, 'generation');
    _sha256(verifierSha256, 'verifierSha256');
  }

  final PersonalWorkspaceId workspaceId;
  final int generation;
  final String verifierSha256;
  final DateTime rotatedAt;

  Map<String, Object?> toJson() => {
    'workspaceId': workspaceId,
    'generation': generation,
    'verifierSha256': verifierSha256,
    'rotatedAt': rotatedAt.toIso8601String(),
  };

  factory RecoveryGeneration.fromJson(Map<String, Object?> json) =>
      RecoveryGeneration(
        workspaceId: json['workspaceId'] as String,
        generation: json['generation'] as int,
        verifierSha256: json['verifierSha256'] as String,
        rotatedAt: _date(json['rotatedAt'], 'rotatedAt'),
      );

  @override
  List<Object?> get props => [
    workspaceId,
    generation,
    verifierSha256,
    rotatedAt,
  ];
}
