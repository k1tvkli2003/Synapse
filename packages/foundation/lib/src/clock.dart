/// Source of UTC time for domain code and infrastructure.
abstract interface class Clock {
  DateTime nowUtc();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// Deterministic clock for tests, fixtures, replays, and migrations.
final class MutableClock implements Clock {
  MutableClock(DateTime initial) : _value = initial.toUtc();

  DateTime _value;

  @override
  DateTime nowUtc() => _value;

  void set(DateTime value) => _value = value.toUtc();

  void advance(Duration duration) => _value = _value.add(duration);
}
