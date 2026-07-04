import 'package:equatable/equatable.dart';

import 'ids.dart';

class Follow extends Equatable {
  const Follow({required this.followerId, required this.followeeId});
  final UserId followerId;
  final UserId followeeId;
  @override
  List<Object?> get props => [followerId, followeeId];
}

enum NotificationKind { reward, social, review, league, system, quest }

/// One item in the unified inbox (prompt 24).
class AppNotification extends Equatable {
  AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.iconKey = 'bell',
    this.route,
    this.readAt,
    DateTime? at,
  }) : at = at ?? _epoch;

  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final String iconKey;

  /// Optional deep-link to open when tapped.
  final String? route;
  final DateTime? readAt;
  final DateTime at;

  bool get isRead => readAt != null;

  AppNotification copyWith({DateTime? readAt}) => AppNotification(
        id: id,
        kind: kind,
        title: title,
        body: body,
        iconKey: iconKey,
        route: route,
        at: at,
        readAt: readAt ?? this.readAt,
      );

  @override
  List<Object?> get props => [id, kind, title, body, readAt];
}

enum ChatKind { dm, group, clan }

class ChatThread extends Equatable {
  const ChatThread({
    required this.id,
    required this.title,
    required this.kind,
    this.participantIds = const [],
    this.lastMessage,
    this.lastAt,
    this.unread = 0,
  });

  final ThreadId id;
  final String title;
  final ChatKind kind;
  final List<UserId> participantIds;
  final String? lastMessage;
  final DateTime? lastAt;
  final int unread;

  @override
  List<Object?> get props => [id, title, kind, lastMessage, unread];
}

class ChatMessage extends Equatable {
  ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.senderName,
    required this.body,
    this.mine = false,
    DateTime? at,
  }) : at = at ?? _epoch;

  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  final String id;
  final ThreadId threadId;
  final UserId senderId;
  final String senderName;
  final String body;
  final bool mine;
  final DateTime at;

  @override
  List<Object?> get props => [id, threadId, senderId, body, at];
}
