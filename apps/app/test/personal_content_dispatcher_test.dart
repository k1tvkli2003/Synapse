import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:synapse_app/data/personal_sync/personal_content_dispatcher.dart';
import 'package:synapse_app/data/personal_sync/personal_device_sync_service.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_foundation/synapse_foundation.dart';
import 'package:synapse_services/synapse_services.dart';

void main() {
  test(
    'defers content refresh while offline without requesting a device token',
    () async {
      var tokenRequests = 0;
      final states = <PersonalContentDispatchState>[];
      final dispatcher = PersonalContentDispatcher(
        readRuntime: () async => _runtime(),
        ensureAccessToken: () async {
          tokenRequests += 1;
          return 'token_test';
        },
        coordinator: _coordinator(_TransientContentGateway()),
        isOnline: () => false,
        onState: states.add,
        onActivated: (_) {},
      );

      final receipt = await dispatcher.requestRefresh();

      expect(receipt.kind, PersonalContentDispatchReceiptKind.deferred);
      expect(receipt.errorCode, 'offline');
      expect(tokenRequests, 0);
      expect(states.last.phase, PersonalContentDispatchPhase.offline);
      dispatcher.dispose();
    },
  );

  test(
    'retries a transient content transport failure without touching Academy state',
    () async {
      final gateway = _TransientContentGateway();
      final states = <PersonalContentDispatchState>[];
      final dispatcher = PersonalContentDispatcher(
        readRuntime: () async => _runtime(),
        ensureAccessToken: () async => 'token_test',
        coordinator: _coordinator(gateway),
        isOnline: () => true,
        onState: states.add,
        onActivated: (_) {},
        baseRetryDelay: const Duration(milliseconds: 4),
        maxRetryDelay: const Duration(milliseconds: 20),
      );
      addTearDown(dispatcher.dispose);

      final first = await dispatcher.requestRefresh();

      expect(first.kind, PersonalContentDispatchReceiptKind.retryScheduled);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(gateway.manifestCalls, greaterThanOrEqualTo(2));
      expect(
        states.any(
          (state) => state.phase == PersonalContentDispatchPhase.retryScheduled,
        ),
        isTrue,
      );
    },
  );
}

PersonalContentDeliveryCoordinator _coordinator(PersonalSyncGateway gateway) {
  final clock = MutableClock(DateTime.utc(2026, 7, 27, 12));
  return PersonalContentDeliveryCoordinator(
    gateway: gateway,
    packages: LocalCurriculumPackageRepository(
      store: MemoryKeyValueStore(),
      clock: clock,
      idSource: SequenceIdSource(const ['content.dispatch.receipt.001']),
    ),
    channelState: PersonalContentChannelStateRepository(
      store: MemoryKeyValueStore(),
      clock: clock,
    ),
  );
}

PersonalSyncRuntime _runtime() {
  final key = base64Url
      .encode(Uint8List.fromList(List<int>.filled(32, 9)))
      .replaceAll('=', '');
  final createdAt = DateTime.utc(2026, 7, 27);
  final workspace = PersonalWorkspace(
    id: 'wrk_personal',
    keyVersion: 1,
    recoveryGeneration: 1,
    createdAt: createdAt,
  );
  return PersonalSyncRuntime(
    workspace: workspace,
    device: TrustedDevice(
      id: 'dev_windows',
      workspaceId: workspace.id,
      label: 'Windows',
      platform: PersonalDevicePlatform.windows,
      role: DeviceTrustRole.root,
      signingPublicKey: key,
      encryptionPublicKey: key,
      createdAt: createdAt,
      lastSeenAt: createdAt,
    ),
    recoveryKitExported: true,
  );
}

final class _TransientContentGateway implements PersonalSyncGateway {
  var manifestCalls = 0;

  @override
  Future<ContentManifest?> fetchManifest({
    required String accessToken,
    String? ifNoneMatch,
  }) async {
    manifestCalls += 1;
    throw const PersonalSyncApiException(
      code: 'content_storage_unavailable',
      message: 'Test transient content failure.',
      statusCode: 503,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
