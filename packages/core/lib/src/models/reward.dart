import 'package:equatable/equatable.dart';

import 'ids.dart';
import 'module_key.dart';

/// What kind of action earned a reward. Every module emits one of these.
enum RewardKind { correct, lesson, win, review, streak, contribution }

/// The competitive weekly tiers (prompt 04 §3).
enum League {
  bronze,
  silver,
  gold,
  sapphire,
  ruby,
  emerald,
  diamond;

  String get label => name[0].toUpperCase() + name.substring(1);

  League? get next {
    final i = index;
    return i < League.values.length - 1 ? League.values[i + 1] : null;
  }

  League? get previous => index > 0 ? League.values[index - 1] : null;
}

class Wallet extends Equatable {
  const Wallet({this.gems = 0});
  final int gems;

  Wallet copyWith({int? gems}) => Wallet(gems: gems ?? this.gems);
  Map<String, dynamic> toJson() => {'gems': gems};
  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(gems: j['gems'] as int? ?? 0);

  @override
  List<Object?> get props => [gems];
}

class Hearts extends Equatable {
  const Hearts({this.current = 5, this.max = 5, this.nextRefillAt});

  final int current;
  final int max;
  final DateTime? nextRefillAt;

  bool get isFull => current >= max;
  bool get isEmpty => current <= 0;

  Hearts copyWith({int? current, int? max, DateTime? nextRefillAt, bool clearRefill = false}) {
    return Hearts(
      current: current ?? this.current,
      max: max ?? this.max,
      nextRefillAt: clearRefill ? null : (nextRefillAt ?? this.nextRefillAt),
    );
  }

  Map<String, dynamic> toJson() =>
      {'current': current, 'max': max, 'nextRefillAt': nextRefillAt?.toIso8601String()};

  factory Hearts.fromJson(Map<String, dynamic> j) => Hearts(
        current: j['current'] as int? ?? 5,
        max: j['max'] as int? ?? 5,
        nextRefillAt: DateTime.tryParse(j['nextRefillAt']?.toString() ?? ''),
      );

  @override
  List<Object?> get props => [current, max, nextRefillAt];
}

class Streak extends Equatable {
  const Streak({
    this.current = 0,
    this.longest = 0,
    this.lastActiveDay,
    this.freezes = 0,
  });

  final int current;
  final int longest;

  /// ISO date (yyyy-MM-dd) of the last day with activity.
  final String? lastActiveDay;
  final int freezes;

  Streak copyWith({int? current, int? longest, String? lastActiveDay, int? freezes}) {
    return Streak(
      current: current ?? this.current,
      longest: longest ?? this.longest,
      lastActiveDay: lastActiveDay ?? this.lastActiveDay,
      freezes: freezes ?? this.freezes,
    );
  }

  Map<String, dynamic> toJson() =>
      {'current': current, 'longest': longest, 'lastActiveDay': lastActiveDay, 'freezes': freezes};

  factory Streak.fromJson(Map<String, dynamic> j) => Streak(
        current: j['current'] as int? ?? 0,
        longest: j['longest'] as int? ?? 0,
        lastActiveDay: j['lastActiveDay'] as String?,
        freezes: j['freezes'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [current, longest, lastActiveDay, freezes];
}

class XPState extends Equatable {
  const XPState({this.total = 0, this.level = 1, this.intoLevel = 0, this.toNext = 100});

  final int total;
  final int level;
  final int intoLevel;
  final int toNext;

  double get levelProgress => toNext == 0 ? 0 : (intoLevel / toNext).clamp(0.0, 1.0);

  XPState copyWith({int? total, int? level, int? intoLevel, int? toNext}) {
    return XPState(
      total: total ?? this.total,
      level: level ?? this.level,
      intoLevel: intoLevel ?? this.intoLevel,
      toNext: toNext ?? this.toNext,
    );
  }

  Map<String, dynamic> toJson() =>
      {'total': total, 'level': level, 'intoLevel': intoLevel, 'toNext': toNext};

  factory XPState.fromJson(Map<String, dynamic> j) => XPState(
        total: j['total'] as int? ?? 0,
        level: j['level'] as int? ?? 1,
        intoLevel: j['intoLevel'] as int? ?? 0,
        toNext: j['toNext'] as int? ?? 100,
      );

  @override
  List<Object?> get props => [total, level, intoLevel, toNext];
}

class Achievement extends Equatable {
  const Achievement({
    required this.id,
    required this.title,
    required this.desc,
    required this.icon,
    this.progress = 0,
    this.goal = 1,
    this.unlockedAt,
    this.module,
  });

  final String id;
  final String title;
  final String desc;

  /// Icon key resolved to an `IconData` in the UI layer.
  final String icon;
  final int progress;
  final int goal;
  final DateTime? unlockedAt;

  /// Optional module the badge belongs to (null = cross-module).
  final ModuleKey? module;

  bool get isUnlocked => unlockedAt != null;
  double get ratio => goal == 0 ? 0 : (progress / goal).clamp(0.0, 1.0);

  Achievement copyWith({int? progress, DateTime? unlockedAt}) {
    return Achievement(
      id: id,
      title: title,
      desc: desc,
      icon: icon,
      goal: goal,
      module: module,
      progress: progress ?? this.progress,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  @override
  List<Object?> get props => [id, progress, unlockedAt];
}

/// Emitted by **every** module on a meaningful success. The gamification engine
/// (prompt 09) is the only consumer; it converts this into XP/gem/heart deltas
/// and side-effect intents (toasts, level-ups, achievement unlocks).
class RewardEvent extends Equatable {
  RewardEvent({
    required this.source,
    required this.kind,
    required this.xp,
    this.gems = 0,
    this.conceptIds = const [],
    this.firstTry = false,
    DateTime? at,
  }) : at = at ?? _epoch;

  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  final ModuleKey source;
  final RewardKind kind;
  final int xp;
  final int gems;
  final List<ConceptId> conceptIds;
  final bool firstTry;
  final DateTime at;

  @override
  List<Object?> get props => [source, kind, xp, gems, conceptIds, firstTry];
}
