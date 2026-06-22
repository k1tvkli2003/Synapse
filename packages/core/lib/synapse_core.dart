/// The shared domain core of Synapse — models, the knowledge-graph spine, the
/// unified content model, concept mastery, and the typed in-app event bus.
///
/// Everything here is **pure Dart** (no Flutter import) so engines, services and
/// tests can depend on it freely. Every module imports these shapes and never
/// redefines them (prompt 04).
library synapse_core;

// Identity & primitives
export 'src/models/ids.dart';
export 'src/models/module_key.dart';
export 'src/models/user_profile.dart';

// Knowledge spine
export 'src/models/concept.dart';
export 'src/models/learn_item.dart';
export 'src/models/concept_mastery.dart';

// Economy & scheduling
export 'src/models/reward.dart';
export 'src/models/quest.dart';
export 'src/models/srs.dart';

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

// Social spine
export 'src/models/social.dart';

// Event bus
export 'src/events/synapse_event.dart';
export 'src/events/event_bus.dart';

// Utilities
export 'src/util/result.dart';
