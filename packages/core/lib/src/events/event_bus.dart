import 'dart:async';

import 'synapse_event.dart';

/// A typed, in-app domain-event bus (prompt 32 §2). It is a thin wrapper over a
/// broadcast stream; the durable outbox that syncs to the backend is layered on
/// top in `services` so events survive restarts. Pure Dart, so it can be unit
/// tested without Flutter.
class EventBus {
  EventBus() : _controller = StreamController<SynapseEvent>.broadcast();

  final StreamController<SynapseEvent> _controller;
  final List<SynapseEvent> _history = <SynapseEvent>[];

  /// All events, for reactors that want everything.
  Stream<SynapseEvent> get stream => _controller.stream;

  /// A filtered stream for a single event type — how reactors subscribe.
  Stream<T> on<T extends SynapseEvent>() => _controller.stream.whereType<T>();

  /// Recent events (most recent last), capped — useful for debugging + tests.
  List<SynapseEvent> get history => List.unmodifiable(_history);

  void publish(SynapseEvent event) {
    if (_controller.isClosed) return;
    _history.add(event);
    if (_history.length > 200) _history.removeAt(0);
    _controller.add(event);
  }

  Future<void> dispose() => _controller.close();
}

extension _WhereType<T> on Stream<T> {
  Stream<R> whereType<R>() => where((e) => e is R).cast<R>();
}
