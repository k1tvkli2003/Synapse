enum DataClassification { operational, pseudonymous, sensitive, prohibited }

/// One scalar observability attribute with an explicit privacy classification.
final class ObservabilityAttribute {
  const ObservabilityAttribute({
    required this.key,
    required this.value,
    this.classification = DataClassification.operational,
  });

  final String key;
  final Object value;
  final DataClassification classification;
}

/// Drops unknown keys, blocks sensitive values, and scrubs common credential or
/// identifier shapes from otherwise approved strings.
final class RedactionPolicy {
  RedactionPolicy({
    required Iterable<String> allowedKeys,
    this.allowPseudonymous = false,
    this.maximumStringLength = 160,
  }) : allowedKeys = Set.unmodifiable(allowedKeys);

  final Set<String> allowedKeys;
  final bool allowPseudonymous;
  final int maximumStringLength;

  Map<String, Object> sanitize(Iterable<ObservabilityAttribute> attributes) {
    final safe = <String, Object>{};
    for (final attribute in attributes) {
      if (!allowedKeys.contains(attribute.key)) continue;
      safe[attribute.key] = switch (attribute.classification) {
        DataClassification.operational => _sanitizeScalar(attribute.value),
        DataClassification.pseudonymous when allowPseudonymous =>
          _sanitizeScalar(attribute.value),
        DataClassification.pseudonymous => '[PSEUDONYMIZED]',
        DataClassification.sensitive ||
        DataClassification.prohibited => '[REDACTED]',
      };
    }
    return Map.unmodifiable(safe);
  }

  Object _sanitizeScalar(Object value) => switch (value) {
    bool() || num() => value,
    String() => sanitizeText(value, maximumLength: maximumStringLength),
    _ => '[UNSUPPORTED]',
  };
}

String sanitizeText(String value, {int maximumLength = 160}) {
  var safe = value.replaceAll(
    RegExp(r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b', caseSensitive: false),
    '[REDACTED_EMAIL]',
  );
  safe = safe.replaceAll(
    RegExp(r'\bBearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
    'Bearer [REDACTED_TOKEN]',
  );
  safe = safe.replaceAll(
    RegExp(r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b'),
    '[REDACTED_TOKEN]',
  );
  safe = safe.replaceAll(
    RegExp(r'([?&][A-Za-z0-9_.-]+=)[^&#\s]+'),
    r'$1[REDACTED]',
  );
  if (safe.length > maximumLength) {
    safe = '${safe.substring(0, maximumLength)}…';
  }
  return safe;
}
