// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'learner_data_plane_database.dart';

// ignore_for_file: type=lint
class $EncryptedLearnerRecordsTable extends EncryptedLearnerRecords
    with TableInfo<$EncryptedLearnerRecordsTable, EncryptedLearnerRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EncryptedLearnerRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _namespaceMeta = const VerificationMeta(
    'namespace',
  );
  @override
  late final GeneratedColumn<String> namespace = GeneratedColumn<String>(
    'namespace',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordIdHashMeta = const VerificationMeta(
    'recordIdHash',
  );
  @override
  late final GeneratedColumn<String> recordIdHash = GeneratedColumn<String>(
    'record_id_hash',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 64,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeHashMeta = const VerificationMeta(
    'scopeHash',
  );
  @override
  late final GeneratedColumn<String> scopeHash = GeneratedColumn<String>(
    'scope_hash',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 64,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyVersionMeta = const VerificationMeta(
    'keyVersion',
  );
  @override
  late final GeneratedColumn<int> keyVersion = GeneratedColumn<int>(
    'key_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tombstoneMeta = const VerificationMeta(
    'tombstone',
  );
  @override
  late final GeneratedColumn<bool> tombstone = GeneratedColumn<bool>(
    'tombstone',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tombstone" IN (0, 1))',
    ),
  );
  static const VerificationMeta _updatedAtMicrosMeta = const VerificationMeta(
    'updatedAtMicros',
  );
  @override
  late final GeneratedColumn<int> updatedAtMicros = GeneratedColumn<int>(
    'updated_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nonceMeta = const VerificationMeta('nonce');
  @override
  late final GeneratedColumn<Uint8List> nonce = GeneratedColumn<Uint8List>(
    'nonce',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cipherTextMeta = const VerificationMeta(
    'cipherText',
  );
  @override
  late final GeneratedColumn<Uint8List> cipherText = GeneratedColumn<Uint8List>(
    'cipher_text',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authenticationMacMeta = const VerificationMeta(
    'authenticationMac',
  );
  @override
  late final GeneratedColumn<Uint8List> authenticationMac =
      GeneratedColumn<Uint8List>(
        'authentication_mac',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    namespace,
    recordIdHash,
    scopeHash,
    kind,
    keyVersion,
    revision,
    tombstone,
    updatedAtMicros,
    nonce,
    cipherText,
    authenticationMac,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'encrypted_learner_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<EncryptedLearnerRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('namespace')) {
      context.handle(
        _namespaceMeta,
        namespace.isAcceptableOrUnknown(data['namespace']!, _namespaceMeta),
      );
    } else if (isInserting) {
      context.missing(_namespaceMeta);
    }
    if (data.containsKey('record_id_hash')) {
      context.handle(
        _recordIdHashMeta,
        recordIdHash.isAcceptableOrUnknown(
          data['record_id_hash']!,
          _recordIdHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recordIdHashMeta);
    }
    if (data.containsKey('scope_hash')) {
      context.handle(
        _scopeHashMeta,
        scopeHash.isAcceptableOrUnknown(data['scope_hash']!, _scopeHashMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeHashMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('key_version')) {
      context.handle(
        _keyVersionMeta,
        keyVersion.isAcceptableOrUnknown(data['key_version']!, _keyVersionMeta),
      );
    } else if (isInserting) {
      context.missing(_keyVersionMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('tombstone')) {
      context.handle(
        _tombstoneMeta,
        tombstone.isAcceptableOrUnknown(data['tombstone']!, _tombstoneMeta),
      );
    } else if (isInserting) {
      context.missing(_tombstoneMeta);
    }
    if (data.containsKey('updated_at_micros')) {
      context.handle(
        _updatedAtMicrosMeta,
        updatedAtMicros.isAcceptableOrUnknown(
          data['updated_at_micros']!,
          _updatedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMicrosMeta);
    }
    if (data.containsKey('nonce')) {
      context.handle(
        _nonceMeta,
        nonce.isAcceptableOrUnknown(data['nonce']!, _nonceMeta),
      );
    } else if (isInserting) {
      context.missing(_nonceMeta);
    }
    if (data.containsKey('cipher_text')) {
      context.handle(
        _cipherTextMeta,
        cipherText.isAcceptableOrUnknown(data['cipher_text']!, _cipherTextMeta),
      );
    } else if (isInserting) {
      context.missing(_cipherTextMeta);
    }
    if (data.containsKey('authentication_mac')) {
      context.handle(
        _authenticationMacMeta,
        authenticationMac.isAcceptableOrUnknown(
          data['authentication_mac']!,
          _authenticationMacMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_authenticationMacMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {namespace, recordIdHash};
  @override
  EncryptedLearnerRecordRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EncryptedLearnerRecordRow(
      namespace: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}namespace'],
      )!,
      recordIdHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id_hash'],
      )!,
      scopeHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_hash'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      keyVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}key_version'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      tombstone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tombstone'],
      )!,
      updatedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_micros'],
      )!,
      nonce: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}nonce'],
      )!,
      cipherText: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}cipher_text'],
      )!,
      authenticationMac: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}authentication_mac'],
      )!,
    );
  }

  @override
  $EncryptedLearnerRecordsTable createAlias(String alias) {
    return $EncryptedLearnerRecordsTable(attachedDatabase, alias);
  }
}

class EncryptedLearnerRecordRow extends DataClass
    implements Insertable<EncryptedLearnerRecordRow> {
  final String namespace;
  final String recordIdHash;
  final String scopeHash;
  final String kind;
  final int keyVersion;
  final int revision;
  final bool tombstone;
  final int updatedAtMicros;
  final Uint8List nonce;
  final Uint8List cipherText;
  final Uint8List authenticationMac;
  const EncryptedLearnerRecordRow({
    required this.namespace,
    required this.recordIdHash,
    required this.scopeHash,
    required this.kind,
    required this.keyVersion,
    required this.revision,
    required this.tombstone,
    required this.updatedAtMicros,
    required this.nonce,
    required this.cipherText,
    required this.authenticationMac,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['namespace'] = Variable<String>(namespace);
    map['record_id_hash'] = Variable<String>(recordIdHash);
    map['scope_hash'] = Variable<String>(scopeHash);
    map['kind'] = Variable<String>(kind);
    map['key_version'] = Variable<int>(keyVersion);
    map['revision'] = Variable<int>(revision);
    map['tombstone'] = Variable<bool>(tombstone);
    map['updated_at_micros'] = Variable<int>(updatedAtMicros);
    map['nonce'] = Variable<Uint8List>(nonce);
    map['cipher_text'] = Variable<Uint8List>(cipherText);
    map['authentication_mac'] = Variable<Uint8List>(authenticationMac);
    return map;
  }

  EncryptedLearnerRecordsCompanion toCompanion(bool nullToAbsent) {
    return EncryptedLearnerRecordsCompanion(
      namespace: Value(namespace),
      recordIdHash: Value(recordIdHash),
      scopeHash: Value(scopeHash),
      kind: Value(kind),
      keyVersion: Value(keyVersion),
      revision: Value(revision),
      tombstone: Value(tombstone),
      updatedAtMicros: Value(updatedAtMicros),
      nonce: Value(nonce),
      cipherText: Value(cipherText),
      authenticationMac: Value(authenticationMac),
    );
  }

  factory EncryptedLearnerRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EncryptedLearnerRecordRow(
      namespace: serializer.fromJson<String>(json['namespace']),
      recordIdHash: serializer.fromJson<String>(json['recordIdHash']),
      scopeHash: serializer.fromJson<String>(json['scopeHash']),
      kind: serializer.fromJson<String>(json['kind']),
      keyVersion: serializer.fromJson<int>(json['keyVersion']),
      revision: serializer.fromJson<int>(json['revision']),
      tombstone: serializer.fromJson<bool>(json['tombstone']),
      updatedAtMicros: serializer.fromJson<int>(json['updatedAtMicros']),
      nonce: serializer.fromJson<Uint8List>(json['nonce']),
      cipherText: serializer.fromJson<Uint8List>(json['cipherText']),
      authenticationMac: serializer.fromJson<Uint8List>(
        json['authenticationMac'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'namespace': serializer.toJson<String>(namespace),
      'recordIdHash': serializer.toJson<String>(recordIdHash),
      'scopeHash': serializer.toJson<String>(scopeHash),
      'kind': serializer.toJson<String>(kind),
      'keyVersion': serializer.toJson<int>(keyVersion),
      'revision': serializer.toJson<int>(revision),
      'tombstone': serializer.toJson<bool>(tombstone),
      'updatedAtMicros': serializer.toJson<int>(updatedAtMicros),
      'nonce': serializer.toJson<Uint8List>(nonce),
      'cipherText': serializer.toJson<Uint8List>(cipherText),
      'authenticationMac': serializer.toJson<Uint8List>(authenticationMac),
    };
  }

  EncryptedLearnerRecordRow copyWith({
    String? namespace,
    String? recordIdHash,
    String? scopeHash,
    String? kind,
    int? keyVersion,
    int? revision,
    bool? tombstone,
    int? updatedAtMicros,
    Uint8List? nonce,
    Uint8List? cipherText,
    Uint8List? authenticationMac,
  }) => EncryptedLearnerRecordRow(
    namespace: namespace ?? this.namespace,
    recordIdHash: recordIdHash ?? this.recordIdHash,
    scopeHash: scopeHash ?? this.scopeHash,
    kind: kind ?? this.kind,
    keyVersion: keyVersion ?? this.keyVersion,
    revision: revision ?? this.revision,
    tombstone: tombstone ?? this.tombstone,
    updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
    nonce: nonce ?? this.nonce,
    cipherText: cipherText ?? this.cipherText,
    authenticationMac: authenticationMac ?? this.authenticationMac,
  );
  EncryptedLearnerRecordRow copyWithCompanion(
    EncryptedLearnerRecordsCompanion data,
  ) {
    return EncryptedLearnerRecordRow(
      namespace: data.namespace.present ? data.namespace.value : this.namespace,
      recordIdHash: data.recordIdHash.present
          ? data.recordIdHash.value
          : this.recordIdHash,
      scopeHash: data.scopeHash.present ? data.scopeHash.value : this.scopeHash,
      kind: data.kind.present ? data.kind.value : this.kind,
      keyVersion: data.keyVersion.present
          ? data.keyVersion.value
          : this.keyVersion,
      revision: data.revision.present ? data.revision.value : this.revision,
      tombstone: data.tombstone.present ? data.tombstone.value : this.tombstone,
      updatedAtMicros: data.updatedAtMicros.present
          ? data.updatedAtMicros.value
          : this.updatedAtMicros,
      nonce: data.nonce.present ? data.nonce.value : this.nonce,
      cipherText: data.cipherText.present
          ? data.cipherText.value
          : this.cipherText,
      authenticationMac: data.authenticationMac.present
          ? data.authenticationMac.value
          : this.authenticationMac,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EncryptedLearnerRecordRow(')
          ..write('namespace: $namespace, ')
          ..write('recordIdHash: $recordIdHash, ')
          ..write('scopeHash: $scopeHash, ')
          ..write('kind: $kind, ')
          ..write('keyVersion: $keyVersion, ')
          ..write('revision: $revision, ')
          ..write('tombstone: $tombstone, ')
          ..write('updatedAtMicros: $updatedAtMicros, ')
          ..write('nonce: $nonce, ')
          ..write('cipherText: $cipherText, ')
          ..write('authenticationMac: $authenticationMac')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    namespace,
    recordIdHash,
    scopeHash,
    kind,
    keyVersion,
    revision,
    tombstone,
    updatedAtMicros,
    $driftBlobEquality.hash(nonce),
    $driftBlobEquality.hash(cipherText),
    $driftBlobEquality.hash(authenticationMac),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EncryptedLearnerRecordRow &&
          other.namespace == this.namespace &&
          other.recordIdHash == this.recordIdHash &&
          other.scopeHash == this.scopeHash &&
          other.kind == this.kind &&
          other.keyVersion == this.keyVersion &&
          other.revision == this.revision &&
          other.tombstone == this.tombstone &&
          other.updatedAtMicros == this.updatedAtMicros &&
          $driftBlobEquality.equals(other.nonce, this.nonce) &&
          $driftBlobEquality.equals(other.cipherText, this.cipherText) &&
          $driftBlobEquality.equals(
            other.authenticationMac,
            this.authenticationMac,
          ));
}

class EncryptedLearnerRecordsCompanion
    extends UpdateCompanion<EncryptedLearnerRecordRow> {
  final Value<String> namespace;
  final Value<String> recordIdHash;
  final Value<String> scopeHash;
  final Value<String> kind;
  final Value<int> keyVersion;
  final Value<int> revision;
  final Value<bool> tombstone;
  final Value<int> updatedAtMicros;
  final Value<Uint8List> nonce;
  final Value<Uint8List> cipherText;
  final Value<Uint8List> authenticationMac;
  final Value<int> rowid;
  const EncryptedLearnerRecordsCompanion({
    this.namespace = const Value.absent(),
    this.recordIdHash = const Value.absent(),
    this.scopeHash = const Value.absent(),
    this.kind = const Value.absent(),
    this.keyVersion = const Value.absent(),
    this.revision = const Value.absent(),
    this.tombstone = const Value.absent(),
    this.updatedAtMicros = const Value.absent(),
    this.nonce = const Value.absent(),
    this.cipherText = const Value.absent(),
    this.authenticationMac = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EncryptedLearnerRecordsCompanion.insert({
    required String namespace,
    required String recordIdHash,
    required String scopeHash,
    required String kind,
    required int keyVersion,
    required int revision,
    required bool tombstone,
    required int updatedAtMicros,
    required Uint8List nonce,
    required Uint8List cipherText,
    required Uint8List authenticationMac,
    this.rowid = const Value.absent(),
  }) : namespace = Value(namespace),
       recordIdHash = Value(recordIdHash),
       scopeHash = Value(scopeHash),
       kind = Value(kind),
       keyVersion = Value(keyVersion),
       revision = Value(revision),
       tombstone = Value(tombstone),
       updatedAtMicros = Value(updatedAtMicros),
       nonce = Value(nonce),
       cipherText = Value(cipherText),
       authenticationMac = Value(authenticationMac);
  static Insertable<EncryptedLearnerRecordRow> custom({
    Expression<String>? namespace,
    Expression<String>? recordIdHash,
    Expression<String>? scopeHash,
    Expression<String>? kind,
    Expression<int>? keyVersion,
    Expression<int>? revision,
    Expression<bool>? tombstone,
    Expression<int>? updatedAtMicros,
    Expression<Uint8List>? nonce,
    Expression<Uint8List>? cipherText,
    Expression<Uint8List>? authenticationMac,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (namespace != null) 'namespace': namespace,
      if (recordIdHash != null) 'record_id_hash': recordIdHash,
      if (scopeHash != null) 'scope_hash': scopeHash,
      if (kind != null) 'kind': kind,
      if (keyVersion != null) 'key_version': keyVersion,
      if (revision != null) 'revision': revision,
      if (tombstone != null) 'tombstone': tombstone,
      if (updatedAtMicros != null) 'updated_at_micros': updatedAtMicros,
      if (nonce != null) 'nonce': nonce,
      if (cipherText != null) 'cipher_text': cipherText,
      if (authenticationMac != null) 'authentication_mac': authenticationMac,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EncryptedLearnerRecordsCompanion copyWith({
    Value<String>? namespace,
    Value<String>? recordIdHash,
    Value<String>? scopeHash,
    Value<String>? kind,
    Value<int>? keyVersion,
    Value<int>? revision,
    Value<bool>? tombstone,
    Value<int>? updatedAtMicros,
    Value<Uint8List>? nonce,
    Value<Uint8List>? cipherText,
    Value<Uint8List>? authenticationMac,
    Value<int>? rowid,
  }) {
    return EncryptedLearnerRecordsCompanion(
      namespace: namespace ?? this.namespace,
      recordIdHash: recordIdHash ?? this.recordIdHash,
      scopeHash: scopeHash ?? this.scopeHash,
      kind: kind ?? this.kind,
      keyVersion: keyVersion ?? this.keyVersion,
      revision: revision ?? this.revision,
      tombstone: tombstone ?? this.tombstone,
      updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
      nonce: nonce ?? this.nonce,
      cipherText: cipherText ?? this.cipherText,
      authenticationMac: authenticationMac ?? this.authenticationMac,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (namespace.present) {
      map['namespace'] = Variable<String>(namespace.value);
    }
    if (recordIdHash.present) {
      map['record_id_hash'] = Variable<String>(recordIdHash.value);
    }
    if (scopeHash.present) {
      map['scope_hash'] = Variable<String>(scopeHash.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (keyVersion.present) {
      map['key_version'] = Variable<int>(keyVersion.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (tombstone.present) {
      map['tombstone'] = Variable<bool>(tombstone.value);
    }
    if (updatedAtMicros.present) {
      map['updated_at_micros'] = Variable<int>(updatedAtMicros.value);
    }
    if (nonce.present) {
      map['nonce'] = Variable<Uint8List>(nonce.value);
    }
    if (cipherText.present) {
      map['cipher_text'] = Variable<Uint8List>(cipherText.value);
    }
    if (authenticationMac.present) {
      map['authentication_mac'] = Variable<Uint8List>(authenticationMac.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EncryptedLearnerRecordsCompanion(')
          ..write('namespace: $namespace, ')
          ..write('recordIdHash: $recordIdHash, ')
          ..write('scopeHash: $scopeHash, ')
          ..write('kind: $kind, ')
          ..write('keyVersion: $keyVersion, ')
          ..write('revision: $revision, ')
          ..write('tombstone: $tombstone, ')
          ..write('updatedAtMicros: $updatedAtMicros, ')
          ..write('nonce: $nonce, ')
          ..write('cipherText: $cipherText, ')
          ..write('authenticationMac: $authenticationMac, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LearnerDataMigrationsTable extends LearnerDataMigrations
    with TableInfo<$LearnerDataMigrationsTable, LearnerDataMigrationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LearnerDataMigrationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _migrationIdMeta = const VerificationMeta(
    'migrationId',
  );
  @override
  late final GeneratedColumn<String> migrationId = GeneratedColumn<String>(
    'migration_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceKeyHashMeta = const VerificationMeta(
    'sourceKeyHash',
  );
  @override
  late final GeneratedColumn<String> sourceKeyHash = GeneratedColumn<String>(
    'source_key_hash',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 64,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceSnapshotSha256Meta =
      const VerificationMeta('sourceSnapshotSha256');
  @override
  late final GeneratedColumn<String> sourceSnapshotSha256 =
      GeneratedColumn<String>(
        'source_snapshot_sha256',
        aliasedName,
        false,
        additionalChecks: GeneratedColumn.checkTextLength(
          minTextLength: 64,
          maxTextLength: 64,
        ),
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<int> cursor = GeneratedColumn<int>(
    'cursor',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _importedCountMeta = const VerificationMeta(
    'importedCount',
  );
  @override
  late final GeneratedColumn<int> importedCount = GeneratedColumn<int>(
    'imported_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _startedAtMicrosMeta = const VerificationMeta(
    'startedAtMicros',
  );
  @override
  late final GeneratedColumn<int> startedAtMicros = GeneratedColumn<int>(
    'started_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMicrosMeta = const VerificationMeta(
    'updatedAtMicros',
  );
  @override
  late final GeneratedColumn<int> updatedAtMicros = GeneratedColumn<int>(
    'updated_at_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMicrosMeta = const VerificationMeta(
    'completedAtMicros',
  );
  @override
  late final GeneratedColumn<int> completedAtMicros = GeneratedColumn<int>(
    'completed_at_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 80,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    migrationId,
    sourceKeyHash,
    sourceSnapshotSha256,
    state,
    cursor,
    importedCount,
    startedAtMicros,
    updatedAtMicros,
    completedAtMicros,
    errorCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'learner_data_migrations';
  @override
  VerificationContext validateIntegrity(
    Insertable<LearnerDataMigrationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('migration_id')) {
      context.handle(
        _migrationIdMeta,
        migrationId.isAcceptableOrUnknown(
          data['migration_id']!,
          _migrationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_migrationIdMeta);
    }
    if (data.containsKey('source_key_hash')) {
      context.handle(
        _sourceKeyHashMeta,
        sourceKeyHash.isAcceptableOrUnknown(
          data['source_key_hash']!,
          _sourceKeyHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceKeyHashMeta);
    }
    if (data.containsKey('source_snapshot_sha256')) {
      context.handle(
        _sourceSnapshotSha256Meta,
        sourceSnapshotSha256.isAcceptableOrUnknown(
          data['source_snapshot_sha256']!,
          _sourceSnapshotSha256Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceSnapshotSha256Meta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    }
    if (data.containsKey('imported_count')) {
      context.handle(
        _importedCountMeta,
        importedCount.isAcceptableOrUnknown(
          data['imported_count']!,
          _importedCountMeta,
        ),
      );
    }
    if (data.containsKey('started_at_micros')) {
      context.handle(
        _startedAtMicrosMeta,
        startedAtMicros.isAcceptableOrUnknown(
          data['started_at_micros']!,
          _startedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtMicrosMeta);
    }
    if (data.containsKey('updated_at_micros')) {
      context.handle(
        _updatedAtMicrosMeta,
        updatedAtMicros.isAcceptableOrUnknown(
          data['updated_at_micros']!,
          _updatedAtMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMicrosMeta);
    }
    if (data.containsKey('completed_at_micros')) {
      context.handle(
        _completedAtMicrosMeta,
        completedAtMicros.isAcceptableOrUnknown(
          data['completed_at_micros']!,
          _completedAtMicrosMeta,
        ),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {migrationId};
  @override
  LearnerDataMigrationRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LearnerDataMigrationRow(
      migrationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}migration_id'],
      )!,
      sourceKeyHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_key_hash'],
      )!,
      sourceSnapshotSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_snapshot_sha256'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cursor'],
      )!,
      importedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}imported_count'],
      )!,
      startedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_micros'],
      )!,
      updatedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_micros'],
      )!,
      completedAtMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at_micros'],
      ),
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
    );
  }

  @override
  $LearnerDataMigrationsTable createAlias(String alias) {
    return $LearnerDataMigrationsTable(attachedDatabase, alias);
  }
}

class LearnerDataMigrationRow extends DataClass
    implements Insertable<LearnerDataMigrationRow> {
  final String migrationId;
  final String sourceKeyHash;
  final String sourceSnapshotSha256;
  final String state;
  final int cursor;
  final int importedCount;
  final int startedAtMicros;
  final int updatedAtMicros;
  final int? completedAtMicros;
  final String? errorCode;
  const LearnerDataMigrationRow({
    required this.migrationId,
    required this.sourceKeyHash,
    required this.sourceSnapshotSha256,
    required this.state,
    required this.cursor,
    required this.importedCount,
    required this.startedAtMicros,
    required this.updatedAtMicros,
    this.completedAtMicros,
    this.errorCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['migration_id'] = Variable<String>(migrationId);
    map['source_key_hash'] = Variable<String>(sourceKeyHash);
    map['source_snapshot_sha256'] = Variable<String>(sourceSnapshotSha256);
    map['state'] = Variable<String>(state);
    map['cursor'] = Variable<int>(cursor);
    map['imported_count'] = Variable<int>(importedCount);
    map['started_at_micros'] = Variable<int>(startedAtMicros);
    map['updated_at_micros'] = Variable<int>(updatedAtMicros);
    if (!nullToAbsent || completedAtMicros != null) {
      map['completed_at_micros'] = Variable<int>(completedAtMicros);
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    return map;
  }

  LearnerDataMigrationsCompanion toCompanion(bool nullToAbsent) {
    return LearnerDataMigrationsCompanion(
      migrationId: Value(migrationId),
      sourceKeyHash: Value(sourceKeyHash),
      sourceSnapshotSha256: Value(sourceSnapshotSha256),
      state: Value(state),
      cursor: Value(cursor),
      importedCount: Value(importedCount),
      startedAtMicros: Value(startedAtMicros),
      updatedAtMicros: Value(updatedAtMicros),
      completedAtMicros: completedAtMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAtMicros),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
    );
  }

  factory LearnerDataMigrationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LearnerDataMigrationRow(
      migrationId: serializer.fromJson<String>(json['migrationId']),
      sourceKeyHash: serializer.fromJson<String>(json['sourceKeyHash']),
      sourceSnapshotSha256: serializer.fromJson<String>(
        json['sourceSnapshotSha256'],
      ),
      state: serializer.fromJson<String>(json['state']),
      cursor: serializer.fromJson<int>(json['cursor']),
      importedCount: serializer.fromJson<int>(json['importedCount']),
      startedAtMicros: serializer.fromJson<int>(json['startedAtMicros']),
      updatedAtMicros: serializer.fromJson<int>(json['updatedAtMicros']),
      completedAtMicros: serializer.fromJson<int?>(json['completedAtMicros']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'migrationId': serializer.toJson<String>(migrationId),
      'sourceKeyHash': serializer.toJson<String>(sourceKeyHash),
      'sourceSnapshotSha256': serializer.toJson<String>(sourceSnapshotSha256),
      'state': serializer.toJson<String>(state),
      'cursor': serializer.toJson<int>(cursor),
      'importedCount': serializer.toJson<int>(importedCount),
      'startedAtMicros': serializer.toJson<int>(startedAtMicros),
      'updatedAtMicros': serializer.toJson<int>(updatedAtMicros),
      'completedAtMicros': serializer.toJson<int?>(completedAtMicros),
      'errorCode': serializer.toJson<String?>(errorCode),
    };
  }

  LearnerDataMigrationRow copyWith({
    String? migrationId,
    String? sourceKeyHash,
    String? sourceSnapshotSha256,
    String? state,
    int? cursor,
    int? importedCount,
    int? startedAtMicros,
    int? updatedAtMicros,
    Value<int?> completedAtMicros = const Value.absent(),
    Value<String?> errorCode = const Value.absent(),
  }) => LearnerDataMigrationRow(
    migrationId: migrationId ?? this.migrationId,
    sourceKeyHash: sourceKeyHash ?? this.sourceKeyHash,
    sourceSnapshotSha256: sourceSnapshotSha256 ?? this.sourceSnapshotSha256,
    state: state ?? this.state,
    cursor: cursor ?? this.cursor,
    importedCount: importedCount ?? this.importedCount,
    startedAtMicros: startedAtMicros ?? this.startedAtMicros,
    updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
    completedAtMicros: completedAtMicros.present
        ? completedAtMicros.value
        : this.completedAtMicros,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
  );
  LearnerDataMigrationRow copyWithCompanion(
    LearnerDataMigrationsCompanion data,
  ) {
    return LearnerDataMigrationRow(
      migrationId: data.migrationId.present
          ? data.migrationId.value
          : this.migrationId,
      sourceKeyHash: data.sourceKeyHash.present
          ? data.sourceKeyHash.value
          : this.sourceKeyHash,
      sourceSnapshotSha256: data.sourceSnapshotSha256.present
          ? data.sourceSnapshotSha256.value
          : this.sourceSnapshotSha256,
      state: data.state.present ? data.state.value : this.state,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
      importedCount: data.importedCount.present
          ? data.importedCount.value
          : this.importedCount,
      startedAtMicros: data.startedAtMicros.present
          ? data.startedAtMicros.value
          : this.startedAtMicros,
      updatedAtMicros: data.updatedAtMicros.present
          ? data.updatedAtMicros.value
          : this.updatedAtMicros,
      completedAtMicros: data.completedAtMicros.present
          ? data.completedAtMicros.value
          : this.completedAtMicros,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LearnerDataMigrationRow(')
          ..write('migrationId: $migrationId, ')
          ..write('sourceKeyHash: $sourceKeyHash, ')
          ..write('sourceSnapshotSha256: $sourceSnapshotSha256, ')
          ..write('state: $state, ')
          ..write('cursor: $cursor, ')
          ..write('importedCount: $importedCount, ')
          ..write('startedAtMicros: $startedAtMicros, ')
          ..write('updatedAtMicros: $updatedAtMicros, ')
          ..write('completedAtMicros: $completedAtMicros, ')
          ..write('errorCode: $errorCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    migrationId,
    sourceKeyHash,
    sourceSnapshotSha256,
    state,
    cursor,
    importedCount,
    startedAtMicros,
    updatedAtMicros,
    completedAtMicros,
    errorCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearnerDataMigrationRow &&
          other.migrationId == this.migrationId &&
          other.sourceKeyHash == this.sourceKeyHash &&
          other.sourceSnapshotSha256 == this.sourceSnapshotSha256 &&
          other.state == this.state &&
          other.cursor == this.cursor &&
          other.importedCount == this.importedCount &&
          other.startedAtMicros == this.startedAtMicros &&
          other.updatedAtMicros == this.updatedAtMicros &&
          other.completedAtMicros == this.completedAtMicros &&
          other.errorCode == this.errorCode);
}

class LearnerDataMigrationsCompanion
    extends UpdateCompanion<LearnerDataMigrationRow> {
  final Value<String> migrationId;
  final Value<String> sourceKeyHash;
  final Value<String> sourceSnapshotSha256;
  final Value<String> state;
  final Value<int> cursor;
  final Value<int> importedCount;
  final Value<int> startedAtMicros;
  final Value<int> updatedAtMicros;
  final Value<int?> completedAtMicros;
  final Value<String?> errorCode;
  final Value<int> rowid;
  const LearnerDataMigrationsCompanion({
    this.migrationId = const Value.absent(),
    this.sourceKeyHash = const Value.absent(),
    this.sourceSnapshotSha256 = const Value.absent(),
    this.state = const Value.absent(),
    this.cursor = const Value.absent(),
    this.importedCount = const Value.absent(),
    this.startedAtMicros = const Value.absent(),
    this.updatedAtMicros = const Value.absent(),
    this.completedAtMicros = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LearnerDataMigrationsCompanion.insert({
    required String migrationId,
    required String sourceKeyHash,
    required String sourceSnapshotSha256,
    required String state,
    this.cursor = const Value.absent(),
    this.importedCount = const Value.absent(),
    required int startedAtMicros,
    required int updatedAtMicros,
    this.completedAtMicros = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : migrationId = Value(migrationId),
       sourceKeyHash = Value(sourceKeyHash),
       sourceSnapshotSha256 = Value(sourceSnapshotSha256),
       state = Value(state),
       startedAtMicros = Value(startedAtMicros),
       updatedAtMicros = Value(updatedAtMicros);
  static Insertable<LearnerDataMigrationRow> custom({
    Expression<String>? migrationId,
    Expression<String>? sourceKeyHash,
    Expression<String>? sourceSnapshotSha256,
    Expression<String>? state,
    Expression<int>? cursor,
    Expression<int>? importedCount,
    Expression<int>? startedAtMicros,
    Expression<int>? updatedAtMicros,
    Expression<int>? completedAtMicros,
    Expression<String>? errorCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (migrationId != null) 'migration_id': migrationId,
      if (sourceKeyHash != null) 'source_key_hash': sourceKeyHash,
      if (sourceSnapshotSha256 != null)
        'source_snapshot_sha256': sourceSnapshotSha256,
      if (state != null) 'state': state,
      if (cursor != null) 'cursor': cursor,
      if (importedCount != null) 'imported_count': importedCount,
      if (startedAtMicros != null) 'started_at_micros': startedAtMicros,
      if (updatedAtMicros != null) 'updated_at_micros': updatedAtMicros,
      if (completedAtMicros != null) 'completed_at_micros': completedAtMicros,
      if (errorCode != null) 'error_code': errorCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LearnerDataMigrationsCompanion copyWith({
    Value<String>? migrationId,
    Value<String>? sourceKeyHash,
    Value<String>? sourceSnapshotSha256,
    Value<String>? state,
    Value<int>? cursor,
    Value<int>? importedCount,
    Value<int>? startedAtMicros,
    Value<int>? updatedAtMicros,
    Value<int?>? completedAtMicros,
    Value<String?>? errorCode,
    Value<int>? rowid,
  }) {
    return LearnerDataMigrationsCompanion(
      migrationId: migrationId ?? this.migrationId,
      sourceKeyHash: sourceKeyHash ?? this.sourceKeyHash,
      sourceSnapshotSha256: sourceSnapshotSha256 ?? this.sourceSnapshotSha256,
      state: state ?? this.state,
      cursor: cursor ?? this.cursor,
      importedCount: importedCount ?? this.importedCount,
      startedAtMicros: startedAtMicros ?? this.startedAtMicros,
      updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
      completedAtMicros: completedAtMicros ?? this.completedAtMicros,
      errorCode: errorCode ?? this.errorCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (migrationId.present) {
      map['migration_id'] = Variable<String>(migrationId.value);
    }
    if (sourceKeyHash.present) {
      map['source_key_hash'] = Variable<String>(sourceKeyHash.value);
    }
    if (sourceSnapshotSha256.present) {
      map['source_snapshot_sha256'] = Variable<String>(
        sourceSnapshotSha256.value,
      );
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<int>(cursor.value);
    }
    if (importedCount.present) {
      map['imported_count'] = Variable<int>(importedCount.value);
    }
    if (startedAtMicros.present) {
      map['started_at_micros'] = Variable<int>(startedAtMicros.value);
    }
    if (updatedAtMicros.present) {
      map['updated_at_micros'] = Variable<int>(updatedAtMicros.value);
    }
    if (completedAtMicros.present) {
      map['completed_at_micros'] = Variable<int>(completedAtMicros.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LearnerDataMigrationsCompanion(')
          ..write('migrationId: $migrationId, ')
          ..write('sourceKeyHash: $sourceKeyHash, ')
          ..write('sourceSnapshotSha256: $sourceSnapshotSha256, ')
          ..write('state: $state, ')
          ..write('cursor: $cursor, ')
          ..write('importedCount: $importedCount, ')
          ..write('startedAtMicros: $startedAtMicros, ')
          ..write('updatedAtMicros: $updatedAtMicros, ')
          ..write('completedAtMicros: $completedAtMicros, ')
          ..write('errorCode: $errorCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LearnerDataPlaneDatabase extends GeneratedDatabase {
  _$LearnerDataPlaneDatabase(QueryExecutor e) : super(e);
  $LearnerDataPlaneDatabaseManager get managers =>
      $LearnerDataPlaneDatabaseManager(this);
  late final $EncryptedLearnerRecordsTable encryptedLearnerRecords =
      $EncryptedLearnerRecordsTable(this);
  late final $LearnerDataMigrationsTable learnerDataMigrations =
      $LearnerDataMigrationsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    encryptedLearnerRecords,
    learnerDataMigrations,
  ];
}

typedef $$EncryptedLearnerRecordsTableCreateCompanionBuilder =
    EncryptedLearnerRecordsCompanion Function({
      required String namespace,
      required String recordIdHash,
      required String scopeHash,
      required String kind,
      required int keyVersion,
      required int revision,
      required bool tombstone,
      required int updatedAtMicros,
      required Uint8List nonce,
      required Uint8List cipherText,
      required Uint8List authenticationMac,
      Value<int> rowid,
    });
typedef $$EncryptedLearnerRecordsTableUpdateCompanionBuilder =
    EncryptedLearnerRecordsCompanion Function({
      Value<String> namespace,
      Value<String> recordIdHash,
      Value<String> scopeHash,
      Value<String> kind,
      Value<int> keyVersion,
      Value<int> revision,
      Value<bool> tombstone,
      Value<int> updatedAtMicros,
      Value<Uint8List> nonce,
      Value<Uint8List> cipherText,
      Value<Uint8List> authenticationMac,
      Value<int> rowid,
    });

class $$EncryptedLearnerRecordsTableFilterComposer
    extends
        Composer<_$LearnerDataPlaneDatabase, $EncryptedLearnerRecordsTable> {
  $$EncryptedLearnerRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get namespace => $composableBuilder(
    column: $table.namespace,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordIdHash => $composableBuilder(
    column: $table.recordIdHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeHash => $composableBuilder(
    column: $table.scopeHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get keyVersion => $composableBuilder(
    column: $table.keyVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get tombstone => $composableBuilder(
    column: $table.tombstone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get nonce => $composableBuilder(
    column: $table.nonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get cipherText => $composableBuilder(
    column: $table.cipherText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get authenticationMac => $composableBuilder(
    column: $table.authenticationMac,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EncryptedLearnerRecordsTableOrderingComposer
    extends
        Composer<_$LearnerDataPlaneDatabase, $EncryptedLearnerRecordsTable> {
  $$EncryptedLearnerRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get namespace => $composableBuilder(
    column: $table.namespace,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordIdHash => $composableBuilder(
    column: $table.recordIdHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeHash => $composableBuilder(
    column: $table.scopeHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get keyVersion => $composableBuilder(
    column: $table.keyVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get tombstone => $composableBuilder(
    column: $table.tombstone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get nonce => $composableBuilder(
    column: $table.nonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get cipherText => $composableBuilder(
    column: $table.cipherText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get authenticationMac => $composableBuilder(
    column: $table.authenticationMac,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EncryptedLearnerRecordsTableAnnotationComposer
    extends
        Composer<_$LearnerDataPlaneDatabase, $EncryptedLearnerRecordsTable> {
  $$EncryptedLearnerRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get namespace =>
      $composableBuilder(column: $table.namespace, builder: (column) => column);

  GeneratedColumn<String> get recordIdHash => $composableBuilder(
    column: $table.recordIdHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scopeHash =>
      $composableBuilder(column: $table.scopeHash, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get keyVersion => $composableBuilder(
    column: $table.keyVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<bool> get tombstone =>
      $composableBuilder(column: $table.tombstone, builder: (column) => column);

  GeneratedColumn<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get nonce =>
      $composableBuilder(column: $table.nonce, builder: (column) => column);

  GeneratedColumn<Uint8List> get cipherText => $composableBuilder(
    column: $table.cipherText,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get authenticationMac => $composableBuilder(
    column: $table.authenticationMac,
    builder: (column) => column,
  );
}

class $$EncryptedLearnerRecordsTableTableManager
    extends
        RootTableManager<
          _$LearnerDataPlaneDatabase,
          $EncryptedLearnerRecordsTable,
          EncryptedLearnerRecordRow,
          $$EncryptedLearnerRecordsTableFilterComposer,
          $$EncryptedLearnerRecordsTableOrderingComposer,
          $$EncryptedLearnerRecordsTableAnnotationComposer,
          $$EncryptedLearnerRecordsTableCreateCompanionBuilder,
          $$EncryptedLearnerRecordsTableUpdateCompanionBuilder,
          (
            EncryptedLearnerRecordRow,
            BaseReferences<
              _$LearnerDataPlaneDatabase,
              $EncryptedLearnerRecordsTable,
              EncryptedLearnerRecordRow
            >,
          ),
          EncryptedLearnerRecordRow,
          PrefetchHooks Function()
        > {
  $$EncryptedLearnerRecordsTableTableManager(
    _$LearnerDataPlaneDatabase db,
    $EncryptedLearnerRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EncryptedLearnerRecordsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$EncryptedLearnerRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$EncryptedLearnerRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> namespace = const Value.absent(),
                Value<String> recordIdHash = const Value.absent(),
                Value<String> scopeHash = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> keyVersion = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<bool> tombstone = const Value.absent(),
                Value<int> updatedAtMicros = const Value.absent(),
                Value<Uint8List> nonce = const Value.absent(),
                Value<Uint8List> cipherText = const Value.absent(),
                Value<Uint8List> authenticationMac = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EncryptedLearnerRecordsCompanion(
                namespace: namespace,
                recordIdHash: recordIdHash,
                scopeHash: scopeHash,
                kind: kind,
                keyVersion: keyVersion,
                revision: revision,
                tombstone: tombstone,
                updatedAtMicros: updatedAtMicros,
                nonce: nonce,
                cipherText: cipherText,
                authenticationMac: authenticationMac,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String namespace,
                required String recordIdHash,
                required String scopeHash,
                required String kind,
                required int keyVersion,
                required int revision,
                required bool tombstone,
                required int updatedAtMicros,
                required Uint8List nonce,
                required Uint8List cipherText,
                required Uint8List authenticationMac,
                Value<int> rowid = const Value.absent(),
              }) => EncryptedLearnerRecordsCompanion.insert(
                namespace: namespace,
                recordIdHash: recordIdHash,
                scopeHash: scopeHash,
                kind: kind,
                keyVersion: keyVersion,
                revision: revision,
                tombstone: tombstone,
                updatedAtMicros: updatedAtMicros,
                nonce: nonce,
                cipherText: cipherText,
                authenticationMac: authenticationMac,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EncryptedLearnerRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$LearnerDataPlaneDatabase,
      $EncryptedLearnerRecordsTable,
      EncryptedLearnerRecordRow,
      $$EncryptedLearnerRecordsTableFilterComposer,
      $$EncryptedLearnerRecordsTableOrderingComposer,
      $$EncryptedLearnerRecordsTableAnnotationComposer,
      $$EncryptedLearnerRecordsTableCreateCompanionBuilder,
      $$EncryptedLearnerRecordsTableUpdateCompanionBuilder,
      (
        EncryptedLearnerRecordRow,
        BaseReferences<
          _$LearnerDataPlaneDatabase,
          $EncryptedLearnerRecordsTable,
          EncryptedLearnerRecordRow
        >,
      ),
      EncryptedLearnerRecordRow,
      PrefetchHooks Function()
    >;
typedef $$LearnerDataMigrationsTableCreateCompanionBuilder =
    LearnerDataMigrationsCompanion Function({
      required String migrationId,
      required String sourceKeyHash,
      required String sourceSnapshotSha256,
      required String state,
      Value<int> cursor,
      Value<int> importedCount,
      required int startedAtMicros,
      required int updatedAtMicros,
      Value<int?> completedAtMicros,
      Value<String?> errorCode,
      Value<int> rowid,
    });
typedef $$LearnerDataMigrationsTableUpdateCompanionBuilder =
    LearnerDataMigrationsCompanion Function({
      Value<String> migrationId,
      Value<String> sourceKeyHash,
      Value<String> sourceSnapshotSha256,
      Value<String> state,
      Value<int> cursor,
      Value<int> importedCount,
      Value<int> startedAtMicros,
      Value<int> updatedAtMicros,
      Value<int?> completedAtMicros,
      Value<String?> errorCode,
      Value<int> rowid,
    });

class $$LearnerDataMigrationsTableFilterComposer
    extends Composer<_$LearnerDataPlaneDatabase, $LearnerDataMigrationsTable> {
  $$LearnerDataMigrationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get migrationId => $composableBuilder(
    column: $table.migrationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKeyHash => $composableBuilder(
    column: $table.sourceKeyHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceSnapshotSha256 => $composableBuilder(
    column: $table.sourceSnapshotSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get importedCount => $composableBuilder(
    column: $table.importedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtMicros => $composableBuilder(
    column: $table.startedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAtMicros => $composableBuilder(
    column: $table.completedAtMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LearnerDataMigrationsTableOrderingComposer
    extends Composer<_$LearnerDataPlaneDatabase, $LearnerDataMigrationsTable> {
  $$LearnerDataMigrationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get migrationId => $composableBuilder(
    column: $table.migrationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKeyHash => $composableBuilder(
    column: $table.sourceKeyHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceSnapshotSha256 => $composableBuilder(
    column: $table.sourceSnapshotSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importedCount => $composableBuilder(
    column: $table.importedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtMicros => $composableBuilder(
    column: $table.startedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAtMicros => $composableBuilder(
    column: $table.completedAtMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LearnerDataMigrationsTableAnnotationComposer
    extends Composer<_$LearnerDataPlaneDatabase, $LearnerDataMigrationsTable> {
  $$LearnerDataMigrationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get migrationId => $composableBuilder(
    column: $table.migrationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceKeyHash => $composableBuilder(
    column: $table.sourceKeyHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceSnapshotSha256 => $composableBuilder(
    column: $table.sourceSnapshotSha256,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);

  GeneratedColumn<int> get importedCount => $composableBuilder(
    column: $table.importedCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startedAtMicros => $composableBuilder(
    column: $table.startedAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMicros => $composableBuilder(
    column: $table.updatedAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAtMicros => $composableBuilder(
    column: $table.completedAtMicros,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);
}

class $$LearnerDataMigrationsTableTableManager
    extends
        RootTableManager<
          _$LearnerDataPlaneDatabase,
          $LearnerDataMigrationsTable,
          LearnerDataMigrationRow,
          $$LearnerDataMigrationsTableFilterComposer,
          $$LearnerDataMigrationsTableOrderingComposer,
          $$LearnerDataMigrationsTableAnnotationComposer,
          $$LearnerDataMigrationsTableCreateCompanionBuilder,
          $$LearnerDataMigrationsTableUpdateCompanionBuilder,
          (
            LearnerDataMigrationRow,
            BaseReferences<
              _$LearnerDataPlaneDatabase,
              $LearnerDataMigrationsTable,
              LearnerDataMigrationRow
            >,
          ),
          LearnerDataMigrationRow,
          PrefetchHooks Function()
        > {
  $$LearnerDataMigrationsTableTableManager(
    _$LearnerDataPlaneDatabase db,
    $LearnerDataMigrationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LearnerDataMigrationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$LearnerDataMigrationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LearnerDataMigrationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> migrationId = const Value.absent(),
                Value<String> sourceKeyHash = const Value.absent(),
                Value<String> sourceSnapshotSha256 = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> cursor = const Value.absent(),
                Value<int> importedCount = const Value.absent(),
                Value<int> startedAtMicros = const Value.absent(),
                Value<int> updatedAtMicros = const Value.absent(),
                Value<int?> completedAtMicros = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearnerDataMigrationsCompanion(
                migrationId: migrationId,
                sourceKeyHash: sourceKeyHash,
                sourceSnapshotSha256: sourceSnapshotSha256,
                state: state,
                cursor: cursor,
                importedCount: importedCount,
                startedAtMicros: startedAtMicros,
                updatedAtMicros: updatedAtMicros,
                completedAtMicros: completedAtMicros,
                errorCode: errorCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String migrationId,
                required String sourceKeyHash,
                required String sourceSnapshotSha256,
                required String state,
                Value<int> cursor = const Value.absent(),
                Value<int> importedCount = const Value.absent(),
                required int startedAtMicros,
                required int updatedAtMicros,
                Value<int?> completedAtMicros = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LearnerDataMigrationsCompanion.insert(
                migrationId: migrationId,
                sourceKeyHash: sourceKeyHash,
                sourceSnapshotSha256: sourceSnapshotSha256,
                state: state,
                cursor: cursor,
                importedCount: importedCount,
                startedAtMicros: startedAtMicros,
                updatedAtMicros: updatedAtMicros,
                completedAtMicros: completedAtMicros,
                errorCode: errorCode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LearnerDataMigrationsTableProcessedTableManager =
    ProcessedTableManager<
      _$LearnerDataPlaneDatabase,
      $LearnerDataMigrationsTable,
      LearnerDataMigrationRow,
      $$LearnerDataMigrationsTableFilterComposer,
      $$LearnerDataMigrationsTableOrderingComposer,
      $$LearnerDataMigrationsTableAnnotationComposer,
      $$LearnerDataMigrationsTableCreateCompanionBuilder,
      $$LearnerDataMigrationsTableUpdateCompanionBuilder,
      (
        LearnerDataMigrationRow,
        BaseReferences<
          _$LearnerDataPlaneDatabase,
          $LearnerDataMigrationsTable,
          LearnerDataMigrationRow
        >,
      ),
      LearnerDataMigrationRow,
      PrefetchHooks Function()
    >;

class $LearnerDataPlaneDatabaseManager {
  final _$LearnerDataPlaneDatabase _db;
  $LearnerDataPlaneDatabaseManager(this._db);
  $$EncryptedLearnerRecordsTableTableManager get encryptedLearnerRecords =>
      $$EncryptedLearnerRecordsTableTableManager(
        _db,
        _db.encryptedLearnerRecords,
      );
  $$LearnerDataMigrationsTableTableManager get learnerDataMigrations =>
      $$LearnerDataMigrationsTableTableManager(_db, _db.learnerDataMigrations);
}
