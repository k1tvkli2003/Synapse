enum NetworkState { unknown, offline, constrained, online }

/// Platform-independent connectivity port.
abstract interface class NetworkMonitor {
  Future<NetworkState> current();

  Stream<NetworkState> get changes;
}

/// Deterministic network source for tests and offline-first previews.
final class StaticNetworkMonitor implements NetworkMonitor {
  const StaticNetworkMonitor(this.state);

  final NetworkState state;

  @override
  Future<NetworkState> current() async => state;

  @override
  Stream<NetworkState> get changes => Stream.value(state);
}
