/// The five top-level destinations of the adaptive shell (prompt 07 / 31).
enum ShellBranch { home, learn, clinical, social, profile }

/// The twelve modules of Synapse. Each is a *surface* over the shared core, not
/// a standalone app (prompt 32). This enum is the single registry: title, the
/// original source idea, the shell branch it lives under, a one-line tagline and
/// the signature accent hue (prompt 03 §1). Colour is stored as an ARGB int so
/// `core` stays Flutter-free; `packages/ui` exposes `tokens.accentOf(module)`.
enum ModuleKey {
  copilot(
    title: 'Copilot',
    source: 'Cortex',
    branch: ShellBranch.home,
    tagline: 'Your AI medical tutor',
    accentHex: 0xFFB794F6,
  ),
  terms(
    title: 'Terms',
    source: 'Lexis',
    branch: ShellBranch.learn,
    tagline: 'Learn the language of medicine',
    accentHex: 0xFF7BE0A3,
  ),
  cards(
    title: 'Cards',
    source: 'Rhizome',
    branch: ShellBranch.learn,
    tagline: 'Flashcards on a knowledge graph',
    accentHex: 0xFF6FD3E8,
  ),
  mnemonics(
    title: 'Mnemonics',
    source: 'Rememb',
    branch: ShellBranch.learn,
    tagline: 'Memory hooks, by the community',
    accentHex: 0xFFFFC773,
  ),
  ecg(
    title: 'ECG',
    source: 'Paze',
    branch: ShellBranch.clinical,
    tagline: 'Read tracings with confidence',
    accentHex: 0xFFFF8A8A,
  ),
  sounds(
    title: 'Sounds',
    source: 'Sonus',
    branch: ShellBranch.clinical,
    tagline: 'Train your ear: heart & lung',
    accentHex: 0xFF5FD9C4,
  ),
  labs(
    title: 'Labs',
    source: 'Smear',
    branch: ShellBranch.clinical,
    tagline: 'Interpret panels, pattern by pattern',
    accentHex: 0xFFC3E88D,
  ),
  algorithms(
    title: 'Algorithms',
    source: 'Omen',
    branch: ShellBranch.clinical,
    tagline: 'Decide step by step',
    accentHex: 0xFF8C9EFF,
  ),
  orLab(
    title: 'OR Lab',
    source: 'Scrubbed',
    branch: ShellBranch.clinical,
    tagline: 'Cinematic surgical dramas',
    accentHex: 0xFFA6B6CC,
  ),
  rounds(
    title: 'Rounds',
    source: 'Wave',
    branch: ShellBranch.social,
    tagline: 'Audio-first clinical feed',
    accentHex: 0xFFF7A8C4,
  ),
  buddies(
    title: 'Study Buddies',
    source: 'Synapse',
    branch: ShellBranch.social,
    tagline: 'Find your study partners',
    accentHex: 0xFF7FB5FF,
  ),
  arena(
    title: 'Arena',
    source: 'Cillin',
    branch: ShellBranch.social,
    tagline: 'Antibiotics vs. bacteria, live',
    accentHex: 0xFFFFB07A,
  );

  const ModuleKey({
    required this.title,
    required this.source,
    required this.branch,
    required this.tagline,
    required this.accentHex,
  });

  /// Display title shown on tiles and headers.
  final String title;

  /// The original source idea this module grew from (prompt 00 mapping table).
  final String source;

  /// Which shell branch this module is reached under.
  final ShellBranch branch;

  /// One-line tagline for tiles and empty states.
  final String tagline;

  /// Signature accent colour as ARGB (prompt 03 §1).
  final int accentHex;

  /// Stable string key used in events, routes and persistence.
  String get id => name;

  static ModuleKey? tryParse(String value) {
    for (final m in ModuleKey.values) {
      if (m.name == value) return m;
    }
    return null;
  }

  static List<ModuleKey> inBranch(ShellBranch branch) =>
      ModuleKey.values.where((m) => m.branch == branch).toList(growable: false);
}
