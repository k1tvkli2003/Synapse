/// The shared domain core of Synapse — models, the knowledge-graph spine, the
/// unified content model, concept mastery, and the typed in-app event bus.
///
/// Everything here is **pure Dart** (no Flutter import) so engines, services and
/// tests can depend on it freely. Every module imports these shapes and never
/// redefines them (prompt 04).
library;

// Identity & primitives
export 'src/models/ids.dart';
export 'src/models/module_key.dart';
export 'src/models/resource_artifact_models.dart';
export 'src/models/resource_document_reading_models.dart';
export 'src/models/resource_reference_models.dart';
export 'src/models/user_profile.dart';

// Curriculum spine
export 'src/curriculum/curriculum_identity.dart';
export 'src/curriculum/curriculum_learning_models.dart';
export 'src/curriculum/curriculum_manifest.dart';
export 'src/curriculum/curriculum_models.dart';
export 'src/curriculum/curriculum_progress_models.dart';
export 'src/curriculum/curriculum_reading_state_models.dart';
export 'src/curriculum/curriculum_study_workspace_models.dart';
export 'src/curriculum/curriculum_study_models.dart';

// Knowledge spine
export 'src/models/concept.dart';
export 'src/models/learn_item.dart';
export 'src/models/concept_mastery.dart';

// Economy & scheduling
export 'src/models/reward.dart';
export 'src/models/quest.dart';
export 'src/models/srs.dart';

// Reference knowledge banks (Part III)
export 'src/models/evidence.dart';
export 'src/models/diseases.dart';
export 'src/models/drugs.dart';
export 'src/models/tools.dart';
export 'src/models/library.dart';

// Module domain models
export 'src/models/terms.dart';
export 'src/models/cards.dart';
export 'src/models/mnemonics.dart';
export 'src/models/ecg.dart';
export 'src/models/sounds.dart';
export 'src/models/labs.dart';
export 'src/models/algorithms.dart';
export 'src/models/orlab.dart';
export 'src/models/rounds.dart';
export 'src/models/buddies.dart';
export 'src/models/arena.dart';
export 'src/models/cases.dart';
export 'src/models/osce.dart';

// Social spine
export 'src/models/social.dart';

// Event bus
export 'src/events/synapse_event.dart';
export 'src/events/event_bus.dart';

// Stable persistence and wire contracts
export 'src/serialization/stable_enum_codec.dart';
export 'src/serialization/canonical_json.dart';
export 'src/serialization/synapse_event_codec.dart';
export 'src/serialization/versioned_envelope.dart';

// Personal multi-device sync and private content delivery
export 'src/sync/personal_sync_models.dart';

// Utilities
export 'src/util/result.dart';
