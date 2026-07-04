import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synapse_core/synapse_core.dart';
import 'package:synapse_services/synapse_services.dart';

/// The unified inbox (prompt 24). Seeded locally; reactors can append more.
class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => DemoSeed.notifications();

  int get unread => state.where((n) => !n.isRead).length;

  void markRead(String id) {
    state = state.map((n) => n.id == id ? n.copyWith(readAt: DateTime.now()) : n).toList();
  }

  void markAllRead() {
    final now = DateTime.now();
    state = state.map((n) => n.isRead ? n : n.copyWith(readAt: now)).toList();
  }

  void add(AppNotification n) => state = [n, ...state];
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(NotificationsNotifier.new);

final unreadCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider);
  return list.where((n) => !n.isRead).length;
});
