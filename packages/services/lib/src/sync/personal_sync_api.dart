import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:synapse_core/synapse_core.dart';

final class PersonalSyncApiException implements Exception {
  const PersonalSyncApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.requestId,
    this.retryAfter,
    this.cause,
  });

  final String code;
  final String message;
  final int? statusCode;
  final String? requestId;
  final Duration? retryAfter;
  final Object? cause;

  bool get isRetryable =>
      statusCode == null ||
      statusCode == 408 ||
      statusCode == 429 ||
      (statusCode! >= 500 && statusCode! <= 599);

  @override
  String toString() => 'PersonalSyncApiException($code): $message';
}

final class DeviceTokenResponse {
  const DeviceTokenResponse({
    required this.accessToken,
    required this.expiresAt,
    this.workspace,
    this.device,
    this.sealedWorkspaceKey,
  });

  final String accessToken;
  final DateTime expiresAt;
  final PersonalWorkspace? workspace;
  final TrustedDevice? device;
  final String? sealedWorkspaceKey;
}

final class SyncPullPage {
  const SyncPullPage({required this.events, required this.nextSequence});

  final List<EncryptedSyncEvent> events;
  final int nextSequence;
}

abstract interface class PersonalSyncGateway {
  Future<({PersonalWorkspace workspace, TrustedDevice device})> bootstrap({
    required String bootstrapToken,
    required String recoveryVerifierSha256,
    required TrustedDevice device,
  });

  Future<PairingSession> createPairingSession({
    required TrustedDevice candidate,
  });

  Future<PairingSession> approvePairingSession({
    required String accessToken,
    required PairingSessionId sessionId,
    required String pairingCode,
    required String candidateEncryptionPublicKey,
    required String sealedWorkspaceKey,
  });

  Future<DeviceTokenResponse> exchangeDeviceToken({
    required TrustedDeviceId deviceId,
    required String nonce,
    required DateTime timestamp,
    required String signature,
    PairingSessionId? pairingSessionId,
    String? pairingCode,
  });

  Future<List<TrustedDevice>> listDevices(String accessToken);

  Future<void> revokeDevice({
    required String accessToken,
    required TrustedDeviceId deviceId,
  });

  Future<({PersonalWorkspace workspace, TrustedDevice device})> rotateRecovery({
    required PersonalWorkspaceId workspaceId,
    required int expectedGeneration,
    required String recoveryVerifierSha256,
    required String newRecoveryVerifierSha256,
    required TrustedDevice newRootDevice,
  });

  Future<List<EncryptedSyncEvent>> pushEvents({
    required String accessToken,
    required Iterable<EncryptedSyncEvent> events,
  });

  Future<SyncPullPage> pullEvents({
    required String accessToken,
    required int afterSequence,
    int limit = 200,
  });

  Future<ContentManifest?> fetchManifest({
    required String accessToken,
    String? ifNoneMatch,
  });

  Future<Uint8List> downloadPackage({
    required String accessToken,
    required ContentPackageId packageId,
  });
}

final class HttpPersonalSyncGateway implements PersonalSyncGateway {
  HttpPersonalSyncGateway({
    required Uri baseUri,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : baseUri = _normalizedBase(baseUri),
       _client = client ?? http.Client() {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout');
    }
  }

  final Uri baseUri;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<({PersonalWorkspace workspace, TrustedDevice device})> bootstrap({
    required String bootstrapToken,
    required String recoveryVerifierSha256,
    required TrustedDevice device,
  }) async {
    final payload = await _json(
      'POST',
      '/v1/bootstrap/redeem',
      body: {
        'bootstrapToken': bootstrapToken,
        'recoveryVerifierSha256': recoveryVerifierSha256,
        'device': device.toJson(),
      },
    );
    return (
      workspace: PersonalWorkspace.fromJson(_map(payload['workspace'])),
      device: TrustedDevice.fromJson(_map(payload['device'])),
    );
  }

  @override
  Future<PairingSession> createPairingSession({
    required TrustedDevice candidate,
  }) async {
    final payload = await _json(
      'POST',
      '/v1/pairing/sessions',
      body: {'candidate': candidate.toJson()},
    );
    return PairingSession.fromJson(_map(payload['session']));
  }

  @override
  Future<PairingSession> approvePairingSession({
    required String accessToken,
    required PairingSessionId sessionId,
    required String pairingCode,
    required String candidateEncryptionPublicKey,
    required String sealedWorkspaceKey,
  }) async {
    final payload = await _json(
      'POST',
      '/v1/pairing/$sessionId/approve',
      accessToken: accessToken,
      body: {
        'pairingCode': pairingCode,
        'candidateEncryptionPublicKey': candidateEncryptionPublicKey,
        'sealedWorkspaceKey': sealedWorkspaceKey,
      },
    );
    return PairingSession.fromJson(_map(payload['session']));
  }

  @override
  Future<DeviceTokenResponse> exchangeDeviceToken({
    required TrustedDeviceId deviceId,
    required String nonce,
    required DateTime timestamp,
    required String signature,
    PairingSessionId? pairingSessionId,
    String? pairingCode,
  }) async {
    if ((pairingSessionId == null) != (pairingCode == null)) {
      throw const PersonalSyncApiException(
        code: 'invalid_pairing_proof',
        message: 'Pairing session and pairing code must be supplied together.',
      );
    }
    final payload = await _json(
      'POST',
      '/v1/device-token',
      body: {
        'deviceId': deviceId,
        'nonce': nonce,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'signature': signature,
        'pairingSessionId': pairingSessionId,
        'pairingCode': pairingCode,
      },
    );
    return DeviceTokenResponse(
      accessToken: payload['accessToken'] as String,
      expiresAt: DateTime.parse(payload['expiresAt'] as String).toUtc(),
      workspace: payload['workspace'] == null
          ? null
          : PersonalWorkspace.fromJson(_map(payload['workspace'])),
      device: payload['device'] == null
          ? null
          : TrustedDevice.fromJson(_map(payload['device'])),
      sealedWorkspaceKey: payload['sealedWorkspaceKey'] as String?,
    );
  }

  @override
  Future<List<TrustedDevice>> listDevices(String accessToken) async {
    final payload = await _json('GET', '/v1/devices', accessToken: accessToken);
    return List.unmodifiable(
      (payload['devices'] as List)
          .map((item) => TrustedDevice.fromJson(_map(item)))
          .toList(growable: false),
    );
  }

  @override
  Future<void> revokeDevice({
    required String accessToken,
    required TrustedDeviceId deviceId,
  }) async {
    await _request('DELETE', '/v1/devices/$deviceId', accessToken: accessToken);
  }

  @override
  Future<({PersonalWorkspace workspace, TrustedDevice device})> rotateRecovery({
    required PersonalWorkspaceId workspaceId,
    required int expectedGeneration,
    required String recoveryVerifierSha256,
    required String newRecoveryVerifierSha256,
    required TrustedDevice newRootDevice,
  }) async {
    final payload = await _json(
      'POST',
      '/v1/recovery/rotate',
      body: {
        'workspaceId': workspaceId,
        'expectedGeneration': expectedGeneration,
        'recoveryVerifierSha256': recoveryVerifierSha256,
        'newRecoveryVerifierSha256': newRecoveryVerifierSha256,
        'newRootDevice': newRootDevice.toJson(),
      },
    );
    return (
      workspace: PersonalWorkspace.fromJson(_map(payload['workspace'])),
      device: TrustedDevice.fromJson(_map(payload['device'])),
    );
  }

  @override
  Future<List<EncryptedSyncEvent>> pushEvents({
    required String accessToken,
    required Iterable<EncryptedSyncEvent> events,
  }) async {
    final batch = List<EncryptedSyncEvent>.unmodifiable(events);
    if (batch.isEmpty || batch.length > 500) {
      throw const PersonalSyncApiException(
        code: 'invalid_sync_push_batch',
        message: 'Sync push batches require between 1 and 500 events.',
      );
    }
    final payload = await _json(
      'POST',
      '/v1/sync/push',
      accessToken: accessToken,
      body: {
        'events': batch.map((event) => event.toJson()).toList(growable: false),
      },
    );
    return List.unmodifiable(
      (payload['events'] as List)
          .map((item) => EncryptedSyncEvent.fromJson(_map(item)))
          .toList(growable: false),
    );
  }

  @override
  Future<SyncPullPage> pullEvents({
    required String accessToken,
    required int afterSequence,
    int limit = 200,
  }) async {
    if (afterSequence < 0 || limit < 1 || limit > 500) {
      throw const PersonalSyncApiException(
        code: 'invalid_sync_pull_cursor',
        message: 'The sync pull cursor or limit is invalid.',
      );
    }
    final payload = await _json(
      'POST',
      '/v1/sync/pull',
      accessToken: accessToken,
      body: {'afterSequence': afterSequence, 'limit': limit},
    );
    return SyncPullPage(
      events: List.unmodifiable(
        (payload['events'] as List)
            .map((item) => EncryptedSyncEvent.fromJson(_map(item)))
            .toList(growable: false),
      ),
      nextSequence: payload['nextSequence'] as int,
    );
  }

  @override
  Future<ContentManifest?> fetchManifest({
    required String accessToken,
    String? ifNoneMatch,
  }) async {
    final normalizedEtag = ifNoneMatch == null
        ? null
        : ifNoneMatch.startsWith('"') && ifNoneMatch.endsWith('"')
        ? ifNoneMatch
        : '"$ifNoneMatch"';
    final response = await _request(
      'GET',
      '/v1/content/manifest',
      accessToken: accessToken,
      headers: {'if-none-match': ?normalizedEtag},
      acceptedStatuses: const {200, 304},
    );
    if (response.statusCode == 304) return null;
    return ContentManifest.fromJson(_decodeMap(response.bodyBytes));
  }

  @override
  Future<Uint8List> downloadPackage({
    required String accessToken,
    required ContentPackageId packageId,
  }) async {
    final response = await _request(
      'GET',
      '/v1/content/packages/$packageId',
      accessToken: accessToken,
    );
    return response.bodyBytes;
  }

  Future<Map<String, Object?>> _json(
    String method,
    String path, {
    String? accessToken,
    Map<String, Object?>? body,
  }) async {
    final response = await _request(
      method,
      path,
      accessToken: accessToken,
      body: body,
    );
    return _decodeMap(response.bodyBytes);
  }

  Future<http.Response> _request(
    String method,
    String path, {
    String? accessToken,
    Map<String, Object?>? body,
    Map<String, String> headers = const {},
    Set<int> acceptedStatuses = const {200},
  }) async {
    final request = http.Request(method, baseUri.resolve(path))
      ..headers.addAll({
        'accept': 'application/json',
        if (body != null) 'content-type': 'application/json',
        if (accessToken != null) 'authorization': 'Bearer $accessToken',
        ...headers,
      });
    if (body != null) request.body = jsonEncode(body);
    try {
      final streamed = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(streamed);
      if (!acceptedStatuses.contains(response.statusCode)) {
        throw _apiError(response);
      }
      return response;
    } on PersonalSyncApiException {
      rethrow;
    } on Object catch (error) {
      throw PersonalSyncApiException(
        code: 'sync_gateway_unreachable',
        message: 'The private Synapse sync gateway could not be reached.',
        cause: error,
      );
    }
  }
}

PersonalSyncApiException _apiError(http.Response response) {
  try {
    final payload = _decodeMap(response.bodyBytes);
    final error = _map(payload['error']);
    return PersonalSyncApiException(
      code: error['code'] as String? ?? 'sync_gateway_error',
      message:
          error['message'] as String? ?? 'The private sync request failed.',
      statusCode: response.statusCode,
      requestId: error['requestId'] as String?,
      retryAfter: _retryAfter(response.headers['retry-after']),
    );
  } on Object {
    return PersonalSyncApiException(
      code: 'sync_gateway_error',
      message: 'The private sync request failed.',
      statusCode: response.statusCode,
      retryAfter: _retryAfter(response.headers['retry-after']),
    );
  }
}

Map<String, Object?> _decodeMap(Uint8List bytes) {
  final decoded = jsonDecode(utf8.decode(bytes));
  return _map(decoded);
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) throw const FormatException('Expected a JSON object.');
  return Map<String, Object?>.from(value);
}

Duration? _retryAfter(String? value) {
  final seconds = int.tryParse(value ?? '');
  return seconds == null ? null : Duration(seconds: seconds);
}

Uri _normalizedBase(Uri value) {
  if (!value.hasScheme || value.host.isEmpty) {
    throw ArgumentError.value(value, 'baseUri', 'Expected an absolute URI.');
  }
  return value.replace(
    path: value.path.endsWith('/') ? value.path : '${value.path}/',
  );
}
