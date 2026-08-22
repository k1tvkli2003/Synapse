import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synapse_services/synapse_services.dart';

import 'secure_learner_data_key_provider.dart';

LearnerDataPlaneDatabase createLearnerDataPlaneDatabase() =>
    LearnerDataPlaneDatabase(
      driftDatabase(
        name: 'synapse_learner_v1',
        native: const DriftNativeOptions(
          shareAcrossIsolates: true,
          databaseDirectory: _databaseDirectory,
        ),
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      ),
    );

IndexedLearnerRecordStore createIndexedLearnerRecordStore({
  required LearnerDataPlaneDatabase database,
  SecureStringStore secureStore = const FlutterSecureStringStore(),
}) => EncryptedIndexedLearnerRecordStore(
  database: database,
  keys: SecureLearnerDataKeyProvider(secureStore: secureStore),
);

Future<Object> _databaseDirectory() => getApplicationSupportDirectory();
