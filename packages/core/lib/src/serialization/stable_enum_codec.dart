enum SerializationIssueCode {
  malformedEnvelope,
  unsupportedSchemaVersion,
  unknownWireValue,
  invalidField,
}

final class SerializationException implements FormatException {
  const SerializationException({
    required this.code,
    required this.message,
    this.source,
    this.offset,
  });

  final SerializationIssueCode code;

  @override
  final String message;

  @override
  final Object? source;

  @override
  final int? offset;

  @override
  String toString() => 'SerializationException(${code.name}): $message';
}

/// Bidirectional enum codec whose wire IDs do not depend on declaration order.
final class StableEnumCodec<T extends Enum> {
  StableEnumCodec(Map<String, T> values) : _decode = Map.unmodifiable(values) {
    if (values.isEmpty) {
      throw ArgumentError('At least one wire value is required.');
    }
    final reverse = <T, String>{};
    for (final entry in values.entries) {
      if (!_wirePattern.hasMatch(entry.key)) {
        throw ArgumentError.value(entry.key, 'values', 'Invalid wire ID.');
      }
      if (reverse.containsKey(entry.value)) {
        throw ArgumentError('Every enum value must have exactly one wire ID.');
      }
      reverse[entry.value] = entry.key;
    }
    _encode = Map.unmodifiable(reverse);
  }

  static final _wirePattern = RegExp(
    r'^[a-z][A-Za-z0-9]*(?:[._-][A-Za-z0-9]+)*$',
  );

  final Map<String, T> _decode;
  late final Map<T, String> _encode;

  String encode(T value) {
    final wire = _encode[value];
    if (wire == null) {
      throw SerializationException(
        code: SerializationIssueCode.unknownWireValue,
        message: 'The enum value has no stable wire mapping.',
        source: value.name,
      );
    }
    return wire;
  }

  T decode(Object? value) {
    final decoded = value is String ? _decode[value] : null;
    if (decoded == null) {
      throw SerializationException(
        code: SerializationIssueCode.unknownWireValue,
        message: 'Unknown stable enum wire value.',
        source: value,
      );
    }
    return decoded;
  }
}
