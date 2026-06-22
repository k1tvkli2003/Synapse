import 'package:equatable/equatable.dart';

import 'ids.dart';
import 'user_profile.dart';

/// A study-partner profile used by the matching screen (prompt 20).
class BuddyProfile extends Equatable {
  const BuddyProfile({
    required this.userId,
    required this.name,
    required this.role,
    this.specialty,
    this.year,
    this.goals = const [],
    this.availability = const [],
    this.bio,
    this.matchScore = 0,
    this.status = BuddyStatus.suggested,
  });

  final UserId userId;
  final String name;
  final UserRole role;
  final String? specialty;
  final int? year;
  final List<String> goals;

  /// e.g. ["Mon eve", "Wed eve", "Weekends"].
  final List<String> availability;
  final String? bio;

  /// 0–100 compatibility from shared goals/specialty/availability.
  final int matchScore;
  final BuddyStatus status;

  BuddyProfile copyWith({BuddyStatus? status}) => BuddyProfile(
        userId: userId,
        name: name,
        role: role,
        specialty: specialty,
        year: year,
        goals: goals,
        availability: availability,
        bio: bio,
        matchScore: matchScore,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props => [userId, status, matchScore];
}

enum BuddyStatus { suggested, requested, incoming, matched, passed }

class StudyGroup extends Equatable {
  const StudyGroup({
    required this.id,
    required this.name,
    this.topic,
    this.memberIds = const [],
    this.memberCount = 0,
  });

  final String id;
  final String name;
  final String? topic;
  final List<UserId> memberIds;
  final int memberCount;

  @override
  List<Object?> get props => [id, name, memberIds];
}
