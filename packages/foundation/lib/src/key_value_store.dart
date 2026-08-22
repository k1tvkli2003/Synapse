/// Minimal async key-value port for infrastructure state, not domain models.
abstract interface class KeyValueStore {
  Future<Object?> read(String key);

  Future<void> write(String key, Object value);

  Future<void> remove(String key);

  Future<void> clear();
}

/// In-memory adapter with defensive collection copies.
final class MemoryKeyValueStore implements KeyValueStore {
  MemoryKeyValueStore([Map<String, Object>? seed]) : _values = {...?seed};

  final Map<String, Object> _values;

  Map<String, Object> get snapshot => Map.unmodifiable(_values);

  @override
  Future<Object?> read(String key) async => _copy(_values[key]);

  @override
  Future<void> write(String key, Object value) async {
    _values[key] = _copy(value)!;
  }

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<void> clear() async => _values.clear();
}

Object? _copy(Object? value) => switch (value) {
  null || String() || num() || bool() => value,
  List<Object?>() => List<Object?>.unmodifiable(value.map(_copy)),
  Map<String, Object?>() => Map<String, Object?>.unmodifiable(
    value.map((key, item) => MapEntry(key, _copy(item))),
  ),
  _ => throw ArgumentError.value(
    value,
    'value',
    'Only JSON-safe key-value data is supported.',
  ),
};
