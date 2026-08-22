import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as hashes;
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';

import '../curriculum/curriculum_package_models.dart';
import '../curriculum/curriculum_package_repository.dart';
import '../curriculum/curriculum_release_trust.dart';
import 'personal_sync_api.dart';

/// A privacy-safe failure receipt for the private curriculum channel. It keeps
/// no package body, lesson text, access token, or learner-authored material.
final class PersonalContentDeliveryFailure {
  PersonalContentDeliveryFailure({
    required this.code,
    required DateTime occurredAt,
    this.releaseId,
    this.manifestSha256,
    this.packageId,
  }) : occurredAt = occurredAt.toUtc() {
    _requireCode(code);
    final configuredReleaseId = releaseId;
    final configuredManifestSha256 = manifestSha256;
    final configuredPackageId = packageId;
    if (configuredReleaseId != null) {
      _requireId(configuredReleaseId, 'releaseId');
    }
    if (configuredManifestSha256 != null) {
      _requireSha(configuredManifestSha256, 'manifestSha256');
    }
    if (configuredPackageId != null) {
      _requireId(configuredPackageId, 'packageId');
    }
  }

  final String code;
  final DateTime occurredAt;
  final String? releaseId;
  final String? manifestSha256;
  final ContentPackageId? packageId;

  Map<String, Object?> toJson() => {
    'code': code,
    'occurredAt': occurredAt.toIso8601String(),
    'releaseId': releaseId,
    'manifestSha256': manifestSha256,
    'packageId': packageId,
  };

  factory PersonalContentDeliveryFailure.fromJson(Map<String, Object?> json) =>
      PersonalContentDeliveryFailure(
        code: _string(json, 'code'),
        occurredAt: _date(json, 'occurredAt'),
        releaseId: _optionalString(json, 'releaseId'),
        manifestSha256: _optionalString(json, 'manifestSha256'),
        packageId: _optionalString(json, 'packageId'),
      );
}

/// The accepted private-channel head and last safe diagnostic. The accepted
/// head moves only after every shard has passed signature verification and the
/// composed release has activated locally.
final class PersonalContentChannelState {
  const PersonalContentChannelState({this.acceptedHead, this.latestFailure});

  final PersonalChannelHead? acceptedHead;
  final PersonalContentDeliveryFailure? latestFailure;

  Map<String, Object?> toJson() => {
    'schemaVersion': PersonalContentChannelStateRepository.schemaVersion,
    'acceptedHead': acceptedHead?.toJson(),
    'latestFailure': latestFailure?.toJson(),
  };

  factory PersonalContentChannelState.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] !=
        PersonalContentChannelStateRepository.schemaVersion) {
      throw const PersonalContentDeliveryException(
        'corrupt_content_channel_state',
        'The private content channel state has an unsupported schema.',
      );
    }
    try {
      return PersonalContentChannelState(
        acceptedHead: json['acceptedHead'] == null
            ? null
            : PersonalChannelHead.fromJson(
                _map(json['acceptedHead'], 'acceptedHead'),
              ),
        latestFailure: json['latestFailure'] == null
            ? null
            : PersonalContentDeliveryFailure.fromJson(
                _map(json['latestFailure'], 'latestFailure'),
              ),
      );
    } on PersonalContentDeliveryException {
      rethrow;
    } on Object catch (error) {
      throw PersonalContentDeliveryException(
        'corrupt_content_channel_state',
        'The private content channel state is malformed.',
        error,
      );
    }
  }
}

/// Small persistence port for the channel head. It is deliberately separate
/// from immutable package storage so recording a transport failure can never
/// mutate a reviewed release or a learner checkpoint.
final class PersonalContentChannelStateRepository {
  PersonalContentChannelStateRepository({
    required KeyValueStore store,
    required Clock clock,
  }) : this._(store, clock);

  PersonalContentChannelStateRepository._(this._store, this._clock);

  static const stateKey = '__synapse_personal_content_channel_v1';
  static const schemaVersion = 1;

  final KeyValueStore _store;
  final Clock _clock;

  Future<PersonalContentChannelState> read() async {
    final raw = await _store.read(stateKey);
    if (raw == null) return const PersonalContentChannelState();
    if (raw is! Map) {
      throw const PersonalContentDeliveryException(
        'corrupt_content_channel_state',
        'The private content channel state is not an object.',
      );
    }
    return PersonalContentChannelState.fromJson(Map<String, Object?>.from(raw));
  }

  Future<void> accept(PersonalChannelHead head) async {
    _requireInternalHead(head);
    // A malformed previous state must never be silently overwritten by a
    // remote response, even though a successful acceptance clears failures.
    await read();
    await _write(
      PersonalContentChannelState(acceptedHead: head, latestFailure: null),
    );
  }

  Future<void> recordFailure({
    required String code,
    PersonalChannelHead? head,
    ContentPackageId? packageId,
  }) async {
    final current = await read();
    await _write(
      PersonalContentChannelState(
        acceptedHead: current.acceptedHead,
        latestFailure: PersonalContentDeliveryFailure(
          code: code,
          occurredAt: _clock.nowUtc(),
          releaseId: head?.releaseId,
          manifestSha256: head?.manifestSha256,
          packageId: packageId,
        ),
      ),
    );
  }

  Future<void> _write(PersonalContentChannelState state) =>
      _store.write(stateKey, state.toJson());

  static void _requireInternalHead(PersonalChannelHead head) {
    if (head.channel != PersonalContentChannel.internal) {
      throw const PersonalContentDeliveryException(
        'content_channel_not_internal',
        'Only the private internal channel may be accepted by this app.',
      );
    }
  }
}

enum PersonalContentDeliveryResultKind { notModified, activated }

final class PersonalContentDeliveryResult {
  const PersonalContentDeliveryResult._({
    required this.kind,
    required this.releaseId,
    required this.manifestSha256,
    required this.sequence,
    this.installedShards = 0,
    this.activationChanged = false,
  });

  const PersonalContentDeliveryResult.notModified({
    required String releaseId,
    required String manifestSha256,
    required int sequence,
  }) : this._(
         kind: PersonalContentDeliveryResultKind.notModified,
         releaseId: releaseId,
         manifestSha256: manifestSha256,
         sequence: sequence,
       );

  const PersonalContentDeliveryResult.activated({
    required String releaseId,
    required String manifestSha256,
    required int sequence,
    required int installedShards,
    required bool activationChanged,
  }) : this._(
         kind: PersonalContentDeliveryResultKind.activated,
         releaseId: releaseId,
         manifestSha256: manifestSha256,
         sequence: sequence,
         installedShards: installedShards,
         activationChanged: activationChanged,
       );

  final PersonalContentDeliveryResultKind kind;
  final CurriculumReleaseId releaseId;
  final String manifestSha256;
  final int sequence;
  final int installedShards;
  final bool activationChanged;
}

final class PersonalContentDeliveryException implements Exception {
  const PersonalContentDeliveryException(this.code, this.message, [this.cause]);

  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'PersonalContentDeliveryException($code): $message';
}

/// Pulls immutable chapter packages from the device-authorized private gateway
/// and only advances a local channel head after every detail is verified.
///
/// It is intentionally foreground-compatible and contains no UI work. A
/// caller may run it after startup or connectivity returns, but lesson screens
/// should always render the already-active local package while this runs.
final class PersonalContentDeliveryCoordinator {
  PersonalContentDeliveryCoordinator({
    required PersonalSyncGateway gateway,
    required CurriculumPackageRepository packages,
    required PersonalContentChannelStateRepository channelState,
  }) : this._(gateway, packages, channelState);

  PersonalContentDeliveryCoordinator._(
    this._gateway,
    this._packages,
    this._channelState,
  );

  final PersonalSyncGateway _gateway;
  final CurriculumPackageRepository _packages;
  final PersonalContentChannelStateRepository _channelState;

  Future<PersonalContentDeliveryResult>? _active;

  /// Coalesces concurrent startup/manual refreshes. A later caller observes
  /// the exact same verified activation result instead of racing a registry
  /// mutation or downloading a mutable second copy of a shard.
  Future<PersonalContentDeliveryResult> refresh({required String accessToken}) {
    final active = _active;
    if (active != null) return active;
    late final Future<PersonalContentDeliveryResult> next;
    next = _refresh(accessToken: accessToken).whenComplete(() {
      if (identical(_active, next)) _active = null;
    });
    _active = next;
    return next;
  }

  Future<PersonalContentDeliveryResult> _refresh({
    required String accessToken,
  }) async {
    final state = await _channelState.read();
    PersonalChannelHead? candidateHead;
    ContentPackageId? candidatePackageId;
    try {
      // A damaged local registry needs a full response even if the server head
      // has not advanced, so signed restore can repair it without a new app.
      final requiresRecovery = (await _packages.auditIntegrity()).isNotEmpty;
      final manifest = await _gateway.fetchManifest(
        accessToken: accessToken,
        ifNoneMatch: requiresRecovery
            ? null
            : state.acceptedHead?.manifestSha256,
      );
      if (manifest == null) {
        final accepted = state.acceptedHead;
        if (accepted == null) {
          throw const PersonalContentDeliveryException(
            'content_not_modified_without_local_head',
            'The gateway reported no content change before any local head existed.',
          );
        }
        return PersonalContentDeliveryResult.notModified(
          releaseId: accepted.releaseId,
          manifestSha256: accepted.manifestSha256,
          sequence: accepted.sequence,
        );
      }
      candidateHead = manifest.head;
      _validateManifest(manifest: manifest, accepted: state.acceptedHead);

      final installedByCandidate = {
        for (final record in await _packages.inventory())
          record.candidateId: record,
      };
      var installedShards = 0;
      for (final package in manifest.packages) {
        candidatePackageId = package.id;
        final envelope = _envelopeFor(package, manifest.head);
        final bytes = await _gateway.downloadPackage(
          accessToken: accessToken,
          packageId: package.id,
        );
        _validateDownloadedBytes(package: package, bytes: bytes);
        final json = utf8.decode(bytes, allowMalformed: false);
        final shard = CurriculumChapterShard(
          courseSourceKey: package.courseSourceKey,
          chapterSourceKey: package.chapterSourceKey,
          ordinal: package.ordinal,
        );
        try {
          final result = await _packages.installSignedChapterShard(
            candidateId: package.id,
            manifestJson: json,
            envelope: envelope,
            shard: shard,
          );
          if (!result.alreadyInstalled) installedShards += 1;
        } on CurriculumPackageException catch (error) {
          final existing = installedByCandidate[package.id];
          if (error.code != 'corrupt_installed_package' || existing == null) {
            rethrow;
          }
          await _packages.restoreSignedInstalledChapterShard(
            candidateId: package.id,
            manifestJson: json,
            expectedInstalledCanonicalSha256: existing.canonicalSha256,
            envelope: envelope,
            shard: shard,
          );
          installedShards += 1;
        }
      }
      final activation = await _packages.activate(
        releaseId: manifest.head.releaseId,
        target: CurriculumActivationTarget.learner,
      );
      await _channelState.accept(manifest.head);
      return PersonalContentDeliveryResult.activated(
        releaseId: manifest.head.releaseId,
        manifestSha256: manifest.head.manifestSha256,
        sequence: manifest.head.sequence,
        installedShards: installedShards,
        activationChanged: activation.changed,
      );
    } on Object catch (error) {
      await _channelState.recordFailure(
        code: _failureCode(error),
        head: candidateHead,
        packageId: candidatePackageId,
      );
      rethrow;
    }
  }

  static void _validateManifest({
    required ContentManifest manifest,
    required PersonalChannelHead? accepted,
  }) {
    if (manifest.schemaVersion != ContentManifest.currentSchemaVersion) {
      throw const PersonalContentDeliveryException(
        'content_manifest_schema_unsupported',
        'Automatic activation requires a complete schema-v2 content manifest.',
      );
    }
    if (manifest.head.channel != PersonalContentChannel.internal) {
      throw const PersonalContentDeliveryException(
        'content_channel_not_internal',
        'Only the private internal content channel is supported.',
      );
    }
    if (manifest.packages.isEmpty) {
      throw const PersonalContentDeliveryException(
        'content_manifest_empty',
        'A private content release must contain at least one chapter package.',
      );
    }
    if (manifest.canonicalSha256 != manifest.head.manifestSha256) {
      throw const PersonalContentDeliveryException(
        'content_manifest_hash_mismatch',
        'The private content manifest does not match its channel head.',
      );
    }
    if (accepted == null) return;
    if (manifest.head.sequence < accepted.sequence) {
      throw const PersonalContentDeliveryException(
        'content_channel_downgrade_rejected',
        'The gateway attempted to move the private content channel backwards.',
      );
    }
    if (manifest.head.sequence == accepted.sequence &&
        (manifest.head.releaseId != accepted.releaseId ||
            manifest.head.manifestSha256 != accepted.manifestSha256)) {
      throw const PersonalContentDeliveryException(
        'content_channel_equivocation_rejected',
        'The gateway returned conflicting metadata for one channel sequence.',
      );
    }
  }

  static CurriculumSignedReleaseEnvelope _envelopeFor(
    SignedChapterPackage package,
    PersonalChannelHead head,
  ) {
    final authorization = package.authorization;
    if (authorization == null ||
        authorization.releaseId != head.releaseId ||
        authorization.releaseChannel != PersonalContentChannel.internal ||
        authorization.transportSha256 != package.sha256 ||
        authorization.transportByteLength != package.byteLength ||
        authorization.signature != package.signature) {
      throw const PersonalContentDeliveryException(
        'content_package_authorization_invalid',
        'A chapter package authorization does not match its immutable transport metadata.',
      );
    }
    try {
      return CurriculumSignedReleaseEnvelope.fromJson(authorization.toJson());
    } on CurriculumPackageException catch (error) {
      throw PersonalContentDeliveryException(error.code, error.message, error);
    } on Object catch (error) {
      throw PersonalContentDeliveryException(
        'content_package_authorization_invalid',
        'A chapter package authorization could not be decoded.',
        error,
      );
    }
  }

  static void _validateDownloadedBytes({
    required SignedChapterPackage package,
    required List<int> bytes,
  }) {
    final authorization = package.authorization;
    final hash = hashes.sha256.convert(bytes).toString();
    if (authorization == null ||
        bytes.length != package.byteLength ||
        hash != package.sha256 ||
        bytes.length != authorization.transportByteLength ||
        hash != authorization.transportSha256) {
      throw const PersonalContentDeliveryException(
        'content_transport_hash_mismatch',
        'Downloaded chapter bytes do not match the signed immutable transport.',
      );
    }
  }

  static String _failureCode(Object error) => switch (error) {
    PersonalContentDeliveryException(:final code) => code,
    CurriculumPackageException(:final code) => code,
    PersonalSyncApiException(:final code) => code,
    FormatException() => 'content_payload_invalid',
    _ => 'content_delivery_failed',
  };
}

final _stableIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,159}$');
final _shaPattern = RegExp(r'^[0-9a-f]{64}$');
final _codePattern = RegExp(r'^[a-z][a-z0-9_]{1,79}$');

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw const PersonalContentDeliveryException(
      'corrupt_content_channel_state',
      'The private content channel state contains an invalid string.',
    );
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  return _string(json, key);
}

Map<String, Object?> _map(Object? value, String key) {
  if (value is! Map) {
    throw PersonalContentDeliveryException(
      'corrupt_content_channel_state',
      '$key must be a JSON object.',
    );
  }
  return Map<String, Object?>.from(value);
}

DateTime _date(Map<String, Object?> json, String key) {
  final raw = _string(json, key);
  final parsed = DateTime.tryParse(raw);
  if (parsed == null || !raw.endsWith('Z')) {
    throw const PersonalContentDeliveryException(
      'corrupt_content_channel_state',
      'The private content channel state contains an invalid UTC timestamp.',
    );
  }
  return parsed.toUtc();
}

void _requireId(String value, String field) {
  if (!_stableIdPattern.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'Expected a stable identifier.');
  }
}

void _requireSha(String value, String field) {
  if (!_shaPattern.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'Expected a lowercase SHA-256.');
  }
}

void _requireCode(String value) {
  if (!_codePattern.hasMatch(value)) {
    throw ArgumentError.value(value, 'code', 'Expected a stable failure code.');
  }
}
