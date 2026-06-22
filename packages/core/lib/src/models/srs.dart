import 'package:equatable/equatable.dart';

import 'ids.dart';

/// The four grades a reviewer can give (prompt 04 §4 / SM-2 style, prompt 22).
enum ReviewGrade {
  again,
  hard,
  good,
  easy;

  String get label => name[0].toUpperCase() + name.substring(1);
}

/// Where an SRS card originated. Terms, Cards and saved Mnemonics all schedule
/// through the *one* SRS engine and mix into a single Daily Review.
enum SrsOrigin { terms, cards, mnemonics }

/// A scheduled review item shared by Terms / Cards / Mnemonics (prompt 22).
class SrsCard extends Equatable {
  SrsCard({
    required this.id,
    required this.ownerId,
    required this.origin,
    required this.front,
    required this.back,
    this.conceptId,
    this.box = 0,
    this.ease = 2.5,
    this.intervalDays = 0,
    DateTime? dueAt,
    this.lapses = 0,
    this.reps = 0,
  }) : dueAt = dueAt ?? _epoch;

  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  final String id;
  final UserId ownerId;
  final ConceptId? conceptId;
  final SrsOrigin origin;
  final String front;
  final String back;
  final int box;
  final double ease;
  final int intervalDays;
  final DateTime dueAt;
  final int lapses;
  final int reps;

  bool isDue([DateTime? now]) => !dueAt.isAfter(now ?? DateTime.now());

  SrsCard copyWith({
    String? front,
    String? back,
    ConceptId? conceptId,
    int? box,
    double? ease,
    int? intervalDays,
    DateTime? dueAt,
    int? lapses,
    int? reps,
  }) {
    return SrsCard(
      id: id,
      ownerId: ownerId,
      origin: origin,
      front: front ?? this.front,
      back: back ?? this.back,
      conceptId: conceptId ?? this.conceptId,
      box: box ?? this.box,
      ease: ease ?? this.ease,
      intervalDays: intervalDays ?? this.intervalDays,
      dueAt: dueAt ?? this.dueAt,
      lapses: lapses ?? this.lapses,
      reps: reps ?? this.reps,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'conceptId': conceptId,
        'origin': origin.name,
        'front': front,
        'back': back,
        'box': box,
        'ease': ease,
        'intervalDays': intervalDays,
        'dueAt': dueAt.toIso8601String(),
        'lapses': lapses,
        'reps': reps,
      };

  factory SrsCard.fromJson(Map<String, dynamic> j) => SrsCard(
        id: j['id'] as String,
        ownerId: j['ownerId'] as String,
        conceptId: j['conceptId'] as String?,
        origin: SrsOrigin.values
            .firstWhere((o) => o.name == j['origin'], orElse: () => SrsOrigin.cards),
        front: j['front'] as String,
        back: j['back'] as String,
        box: j['box'] as int? ?? 0,
        ease: (j['ease'] as num?)?.toDouble() ?? 2.5,
        intervalDays: j['intervalDays'] as int? ?? 0,
        dueAt: DateTime.tryParse(j['dueAt']?.toString() ?? '') ?? _epoch,
        lapses: j['lapses'] as int? ?? 0,
        reps: j['reps'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [id, box, ease, intervalDays, dueAt, lapses, reps];
}
