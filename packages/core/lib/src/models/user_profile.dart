import 'package:equatable/equatable.dart';

import 'ids.dart';

enum UserRole { student, resident, nurse, clinician, other }

enum ThemeModePref { dark, light, system }

class NotificationPrefs extends Equatable {
  const NotificationPrefs({
    this.dailyReminder = true,
    this.reminderHour = 19,
    this.streakAlerts = true,
    this.social = true,
    this.leagues = true,
  });

  final bool dailyReminder;
  final int reminderHour; // 0-23 local
  final bool streakAlerts;
  final bool social;
  final bool leagues;

  NotificationPrefs copyWith({
    bool? dailyReminder,
    int? reminderHour,
    bool? streakAlerts,
    bool? social,
    bool? leagues,
  }) {
    return NotificationPrefs(
      dailyReminder: dailyReminder ?? this.dailyReminder,
      reminderHour: reminderHour ?? this.reminderHour,
      streakAlerts: streakAlerts ?? this.streakAlerts,
      social: social ?? this.social,
      leagues: leagues ?? this.leagues,
    );
  }

  Map<String, dynamic> toJson() => {
        'dailyReminder': dailyReminder,
        'reminderHour': reminderHour,
        'streakAlerts': streakAlerts,
        'social': social,
        'leagues': leagues,
      };

  factory NotificationPrefs.fromJson(Map<String, dynamic> j) => NotificationPrefs(
        dailyReminder: j['dailyReminder'] as bool? ?? true,
        reminderHour: j['reminderHour'] as int? ?? 19,
        streakAlerts: j['streakAlerts'] as bool? ?? true,
        social: j['social'] as bool? ?? true,
        leagues: j['leagues'] as bool? ?? true,
      );

  @override
  List<Object?> get props =>
      [dailyReminder, reminderHour, streakAlerts, social, leagues];
}

class UserPrefs extends Equatable {
  const UserPrefs({
    this.theme = ThemeModePref.dark,
    this.locale = 'en',
    this.analyticsOptIn = false,
    this.reduceMotion = false,
    this.dailyGoalXp = 50,
    this.notifications = const NotificationPrefs(),
    this.interests = const [],
  });

  final ThemeModePref theme;
  final String locale;
  final bool analyticsOptIn;
  final bool reduceMotion;
  final int dailyGoalXp;
  final NotificationPrefs notifications;

  /// Module ids the user picked at onboarding; used to order the Hub grid.
  final List<String> interests;

  UserPrefs copyWith({
    ThemeModePref? theme,
    String? locale,
    bool? analyticsOptIn,
    bool? reduceMotion,
    int? dailyGoalXp,
    NotificationPrefs? notifications,
    List<String>? interests,
  }) {
    return UserPrefs(
      theme: theme ?? this.theme,
      locale: locale ?? this.locale,
      analyticsOptIn: analyticsOptIn ?? this.analyticsOptIn,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      dailyGoalXp: dailyGoalXp ?? this.dailyGoalXp,
      notifications: notifications ?? this.notifications,
      interests: interests ?? this.interests,
    );
  }

  Map<String, dynamic> toJson() => {
        'theme': theme.name,
        'locale': locale,
        'analyticsOptIn': analyticsOptIn,
        'reduceMotion': reduceMotion,
        'dailyGoalXp': dailyGoalXp,
        'notifications': notifications.toJson(),
        'interests': interests,
      };

  factory UserPrefs.fromJson(Map<String, dynamic> j) => UserPrefs(
        theme: ThemeModePref.values
            .firstWhere((t) => t.name == j['theme'], orElse: () => ThemeModePref.dark),
        locale: j['locale'] as String? ?? 'en',
        analyticsOptIn: j['analyticsOptIn'] as bool? ?? false,
        reduceMotion: j['reduceMotion'] as bool? ?? false,
        dailyGoalXp: j['dailyGoalXp'] as int? ?? 50,
        notifications: j['notifications'] is Map
            ? NotificationPrefs.fromJson(
                Map<String, dynamic>.from(j['notifications'] as Map))
            : const NotificationPrefs(),
        interests: (j['interests'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );

  @override
  List<Object?> get props =>
      [theme, locale, analyticsOptIn, reduceMotion, dailyGoalXp, notifications, interests];
}

class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.handle,
    required this.displayName,
    this.avatarUrl,
    this.role = UserRole.student,
    this.specialty,
    this.year,
    this.bio,
    this.prefs = const UserPrefs(),
    this.createdAt,
    this.updatedAt,
  });

  final UserId id;
  final String handle;
  final String displayName;
  final String? avatarUrl;
  final UserRole role;
  final String? specialty;
  final int? year;
  final String? bio;
  final UserPrefs prefs;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get firstName => displayName.split(' ').first;

  UserProfile copyWith({
    String? handle,
    String? displayName,
    String? avatarUrl,
    UserRole? role,
    String? specialty,
    int? year,
    String? bio,
    UserPrefs? prefs,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id,
      handle: handle ?? this.handle,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      specialty: specialty ?? this.specialty,
      year: year ?? this.year,
      bio: bio ?? this.bio,
      prefs: prefs ?? this.prefs,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'handle': handle,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'role': role.name,
        'specialty': specialty,
        'year': year,
        'bio': bio,
        'prefs': prefs.toJson(),
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'] as String,
        handle: j['handle'] as String,
        displayName: j['displayName'] as String,
        avatarUrl: j['avatarUrl'] as String?,
        role: UserRole.values
            .firstWhere((r) => r.name == j['role'], orElse: () => UserRole.student),
        specialty: j['specialty'] as String?,
        year: j['year'] as int?,
        bio: j['bio'] as String?,
        prefs: j['prefs'] is Map
            ? UserPrefs.fromJson(Map<String, dynamic>.from(j['prefs'] as Map))
            : const UserPrefs(),
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
        updatedAt: DateTime.tryParse(j['updatedAt']?.toString() ?? ''),
      );

  @override
  List<Object?> get props =>
      [id, handle, displayName, avatarUrl, role, specialty, year, bio, prefs];
}
