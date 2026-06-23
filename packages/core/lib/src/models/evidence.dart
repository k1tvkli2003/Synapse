import 'package:equatable/equatable.dart';

/// The kind of source a [Citation] points to (prompt 50 §1).
enum CitationType {
  guideline,
  rct,
  review,
  textbook,
  cohort,
  other;

  String get label => switch (this) {
        CitationType.guideline => 'Guideline',
        CitationType.rct => 'RCT',
        CitationType.review => 'Review',
        CitationType.textbook => 'Textbook',
        CitationType.cohort => 'Cohort study',
        CitationType.other => 'Source',
      };
}

/// Strength-of-evidence grade attached to a fact or recommendation (prompt 50).
enum LevelOfEvidence {
  a,
  b,
  c,
  expert;

  String get label => switch (this) {
        LevelOfEvidence.a => 'Level A',
        LevelOfEvidence.b => 'Level B',
        LevelOfEvidence.c => 'Level C',
        LevelOfEvidence.expert => 'Expert opinion',
      };
}

/// A single, verifiable reference (prompt 50 §1).
class Citation extends Equatable {
  const Citation({
    required this.title,
    required this.source,
    this.year,
    this.url,
    this.type = CitationType.other,
  });

  final String title;
  final String source;
  final int? year;
  final String? url;
  final CitationType type;

  String get short => year != null ? '$source, $year' : source;

  Map<String, dynamic> toJson() => {
        'title': title,
        'source': source,
        'year': year,
        'url': url,
        'type': type.name,
      };

  factory Citation.fromJson(Map<String, dynamic> j) => Citation(
        title: j['title'] as String,
        source: j['source'] as String,
        year: (j['year'] as num?)?.toInt(),
        url: j['url'] as String?,
        type: CitationType.values.firstWhere((t) => t.name == j['type'],
            orElse: () => CitationType.other),
      );

  @override
  List<Object?> get props => [title, source, year, url, type];
}

/// The evidence bundle attached to every reference [LearnItem] (prompt 50 §1).
/// Content without citations or past [expiresOn] is surfaced as "review due".
class Evidence extends Equatable {
  const Evidence({
    this.citations = const [],
    this.levelOfEvidence,
    this.lastReviewed,
    this.expiresOn,
    this.region,
  });

  final List<Citation> citations;
  final LevelOfEvidence? levelOfEvidence;
  final DateTime? lastReviewed;
  final DateTime? expiresOn;
  final String? region;

  bool get hasCitations => citations.isNotEmpty;

  /// True when the content is past its review-by date and should be flagged.
  bool isStale(DateTime now) => expiresOn != null && now.isAfter(expiresOn!);

  /// "Unverified" content has no sources at all — visually marked (prompt 50).
  bool get isUnverified => citations.isEmpty;

  @override
  List<Object?> get props => [citations, levelOfEvidence, lastReviewed, expiresOn, region];
}

/// The editorial lifecycle of a content item (prompt 50 §1 / §2).
enum ReviewStatus {
  draft,
  inReview,
  approved,
  needsUpdate,
  deprecated;

  String get label => switch (this) {
        ReviewStatus.draft => 'Draft',
        ReviewStatus.inReview => 'In review',
        ReviewStatus.approved => 'Reviewed',
        ReviewStatus.needsUpdate => 'Update due',
        ReviewStatus.deprecated => 'Deprecated',
      };

  /// Only approved content is presented as established fact.
  bool get isPublished => this == ReviewStatus.approved;
}

/// A single entry in a content item's change log (prompt 50 §2).
class ChangeLogEntry extends Equatable {
  const ChangeLogEntry({required this.at, required this.summary, this.author});
  final DateTime at;
  final String summary;
  final String? author;

  @override
  List<Object?> get props => [at, summary, author];
}

/// The review/governance state of a content item (prompt 50 §1).
class ReviewState extends Equatable {
  const ReviewState({
    this.status = ReviewStatus.approved,
    this.reviewerId,
    this.reviewerName,
    this.reviewedAt,
    this.changeLog = const [],
    this.communityContributed = false,
  });

  final ReviewStatus status;
  final String? reviewerId;
  final String? reviewerName;
  final DateTime? reviewedAt;
  final List<ChangeLogEntry> changeLog;

  /// Distinguishes "established fact" from "community-contributed" (prompt 50 §4).
  final bool communityContributed;

  ReviewState copyWith({
    ReviewStatus? status,
    String? reviewerId,
    String? reviewerName,
    DateTime? reviewedAt,
    List<ChangeLogEntry>? changeLog,
    bool? communityContributed,
  }) {
    return ReviewState(
      status: status ?? this.status,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerName: reviewerName ?? this.reviewerName,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      changeLog: changeLog ?? this.changeLog,
      communityContributed: communityContributed ?? this.communityContributed,
    );
  }

  @override
  List<Object?> get props =>
      [status, reviewerId, reviewerName, reviewedAt, changeLog, communityContributed];
}
