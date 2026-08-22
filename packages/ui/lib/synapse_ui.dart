/// The Synapse design system: tokens, theming, responsive primitives and the
/// shared widget library every module is built from (prompt 03 / 30).
library;

export 'package:flutter_animate/flutter_animate.dart';

// Theme
export 'src/theme/spacing.dart';
export 'src/theme/palette.dart';
export 'src/theme/tokens.dart';
export 'src/theme/app_theme.dart';
export 'src/theme/module_visuals.dart';

// Responsive
export 'src/responsive/breakpoints.dart';
export 'src/responsive/adaptive.dart';

// Widgets
export 'src/widgets/atoms.dart';
export 'src/widgets/containers.dart';
export 'src/widgets/forms.dart';
export 'src/widgets/states.dart';
export 'src/widgets/gamification.dart';
export 'src/widgets/module_tile.dart';
export 'src/widgets/shells.dart';
export 'src/widgets/feedback.dart';
export 'src/widgets/audio_player_bar.dart';
export 'src/widgets/reference.dart';

// Motion
export 'src/motion/motion_reveal.dart';
export 'src/motion/motion_scope.dart';
export 'src/motion/signal_burst.dart';

// Sensory design language (motion lives in tokens; sound + haptics here)
export 'src/feedback/sensory.dart';
