import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

/// Saves the already passphrase-encrypted Recovery Kit using the platform's
/// native file/export affordance. On Web, [XFile.saveTo] triggers the browser
/// download flow and intentionally ignores the opaque path returned by the
/// selector implementation.
Future<bool> exportEncryptedRecoveryKit(String serialized) async {
  final location = await getSaveLocation(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Synapse Recovery Kit',
        extensions: ['synapse-recovery'],
      ),
    ],
    suggestedName: 'synapse-recovery-kit.synapse-recovery',
    confirmButtonText: 'Save Recovery Kit',
  );
  if (location == null) return false;
  final file = XFile.fromData(
    Uint8List.fromList(utf8.encode(serialized)),
    mimeType: 'application/json',
    name: 'synapse-recovery-kit.synapse-recovery',
  );
  await file.saveTo(location.path);
  return true;
}
