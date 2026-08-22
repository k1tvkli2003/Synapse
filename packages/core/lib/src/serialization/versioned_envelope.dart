import 'stable_enum_codec.dart';

final class VersionedEnvelope {
  VersionedEnvelope({
    required this.schemaVersion,
    required this.type,
    required Map<String, dynamic> payload,
  }) : payload = Map.unmodifiable(payload) {
    if (schemaVersion < 1) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion');
    }
    if (type.trim().isEmpty) throw ArgumentError.value(type, 'type');
  }

  final int schemaVersion;
  final String type;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'type': type,
    'payload': payload,
  };

  factory VersionedEnvelope.fromJson(
    Map<String, dynamic> json, {
    required Set<int> supportedVersions,
  }) {
    final schemaVersion = json['schemaVersion'];
    final type = json['type'];
    final payload = json['payload'];
    if (schemaVersion is! int || type is! String || payload is! Map) {
      throw SerializationException(
        code: SerializationIssueCode.malformedEnvelope,
        message: 'schemaVersion, type, and payload are required.',
        source: json.keys.toList(growable: false),
      );
    }
    if (!supportedVersions.contains(schemaVersion)) {
      throw SerializationException(
        code: SerializationIssueCode.unsupportedSchemaVersion,
        message: 'No reader exists for schema version $schemaVersion.',
        source: schemaVersion,
      );
    }
    return VersionedEnvelope(
      schemaVersion: schemaVersion,
      type: type,
      payload: Map<String, dynamic>.from(payload),
    );
  }
}
