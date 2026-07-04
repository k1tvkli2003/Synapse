import 'package:flutter/widgets.dart';

/// The Synapse breakpoint contract (prompt 02 §3). Layouts are built from these
/// — never from hard-coded pixel widths.
enum Breakpoint {
  compact, // < 600
  medium, // 600–839
  expanded, // 840–1199
  large, // 1200–1599
  xlarge; // ≥ 1600

  static Breakpoint fromWidth(double w) {
    if (w < 600) return Breakpoint.compact;
    if (w < 840) return Breakpoint.medium;
    if (w < 1200) return Breakpoint.expanded;
    if (w < 1600) return Breakpoint.large;
    return Breakpoint.xlarge;
  }

  bool get isCompact => this == Breakpoint.compact;
  bool get isMobile => index <= Breakpoint.medium.index;
  bool get isWide => index >= Breakpoint.large.index;
  bool get usesRail => index >= Breakpoint.medium.index;
  bool get usesDrawer => index >= Breakpoint.large.index;

  /// Hub grid column count: 2 → 3 → 4 → 5 (prompt 30 §7).
  int get gridColumns => switch (this) {
        Breakpoint.compact => 2,
        Breakpoint.medium => 3,
        Breakpoint.expanded => 4,
        Breakpoint.large => 4,
        Breakpoint.xlarge => 5,
      };
}

extension BreakpointX on BuildContext {
  Breakpoint get bp => Breakpoint.fromWidth(MediaQuery.sizeOf(this).width);
  bool get isCompact => bp.isCompact;
  bool get isWide => bp.isWide;
  double get screenWidth => MediaQuery.sizeOf(this).width;
}

/// Picks a value per breakpoint, cascading down to the nearest defined one.
class Responsive<T> {
  const Responsive({
    required this.compact,
    this.medium,
    this.expanded,
    this.large,
    this.xlarge,
  });

  final T compact;
  final T? medium;
  final T? expanded;
  final T? large;
  final T? xlarge;

  T resolve(BuildContext context) => resolveFor(context.bp);

  T resolveFor(Breakpoint bp) => switch (bp) {
        Breakpoint.compact => compact,
        Breakpoint.medium => medium ?? compact,
        Breakpoint.expanded => expanded ?? medium ?? compact,
        Breakpoint.large => large ?? expanded ?? medium ?? compact,
        Breakpoint.xlarge => xlarge ?? large ?? expanded ?? medium ?? compact,
      };
}
