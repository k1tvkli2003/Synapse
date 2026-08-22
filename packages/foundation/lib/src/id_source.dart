import 'clock.dart';
import 'random_source.dart';

/// Generates opaque operational IDs; never use it as a medical record ID.
abstract interface class IdSource {
  String nextId();
}

/// Time-sortable IDs with an in-process counter and random suffix.
///
/// This is intentionally not an authentication or cryptographic identifier.
final class TimeOrderedIdSource implements IdSource {
  TimeOrderedIdSource({
    required this.clock,
    required this.random,
    this.prefix = 'syn',
  });

  final Clock clock;
  final RandomSource random;
  final String prefix;
  int _counter = 0;

  @override
  String nextId() {
    final timestamp = clock.nowUtc().microsecondsSinceEpoch.toRadixString(36);
    final counter = (_counter++).toRadixString(36).padLeft(2, '0');
    final entropy = random.nextInt(0x1000000).toRadixString(36).padLeft(5, '0');
    return '$prefix-$timestamp-$counter-$entropy';
  }
}

/// Finite deterministic ID source. Exhaustion fails instead of recycling IDs.
final class SequenceIdSource implements IdSource {
  SequenceIdSource(Iterable<String> ids) : _ids = List.unmodifiable(ids);

  final List<String> _ids;
  int _index = 0;

  @override
  String nextId() {
    if (_index >= _ids.length) {
      throw StateError('The deterministic ID sequence is exhausted.');
    }
    return _ids[_index++];
  }
}
