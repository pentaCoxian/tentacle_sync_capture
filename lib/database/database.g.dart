// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endedAtMeta =
      const VerificationMeta('endedAt');
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
      'ended_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _phoneModelMeta =
      const VerificationMeta('phoneModel');
  @override
  late final GeneratedColumn<String> phoneModel = GeneratedColumn<String>(
      'phone_model', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _androidVersionMeta =
      const VerificationMeta('androidVersion');
  @override
  late final GeneratedColumn<String> androidVersion = GeneratedColumn<String>(
      'android_version', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _appVersionMeta =
      const VerificationMeta('appVersion');
  @override
  late final GeneratedColumn<String> appVersion = GeneratedColumn<String>(
      'app_version', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _scanSettingsJsonMeta =
      const VerificationMeta('scanSettingsJson');
  @override
  late final GeneratedColumn<String> scanSettingsJson = GeneratedColumn<String>(
      'scan_settings_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _labelsJsonMeta =
      const VerificationMeta('labelsJson');
  @override
  late final GeneratedColumn<String> labelsJson = GeneratedColumn<String>(
      'labels_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _markersJsonMeta =
      const VerificationMeta('markersJson');
  @override
  late final GeneratedColumn<String> markersJson = GeneratedColumn<String>(
      'markers_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        startedAt,
        endedAt,
        phoneModel,
        androidVersion,
        appVersion,
        scanSettingsJson,
        labelsJson,
        notes,
        markersJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(Insertable<Session> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(_endedAtMeta,
          endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta));
    }
    if (data.containsKey('phone_model')) {
      context.handle(
          _phoneModelMeta,
          phoneModel.isAcceptableOrUnknown(
              data['phone_model']!, _phoneModelMeta));
    }
    if (data.containsKey('android_version')) {
      context.handle(
          _androidVersionMeta,
          androidVersion.isAcceptableOrUnknown(
              data['android_version']!, _androidVersionMeta));
    }
    if (data.containsKey('app_version')) {
      context.handle(
          _appVersionMeta,
          appVersion.isAcceptableOrUnknown(
              data['app_version']!, _appVersionMeta));
    }
    if (data.containsKey('scan_settings_json')) {
      context.handle(
          _scanSettingsJsonMeta,
          scanSettingsJson.isAcceptableOrUnknown(
              data['scan_settings_json']!, _scanSettingsJsonMeta));
    }
    if (data.containsKey('labels_json')) {
      context.handle(
          _labelsJsonMeta,
          labelsJson.isAcceptableOrUnknown(
              data['labels_json']!, _labelsJsonMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('markers_json')) {
      context.handle(
          _markersJsonMeta,
          markersJson.isAcceptableOrUnknown(
              data['markers_json']!, _markersJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      endedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}ended_at']),
      phoneModel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone_model'])!,
      androidVersion: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}android_version'])!,
      appVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}app_version'])!,
      scanSettingsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}scan_settings_json'])!,
      labelsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}labels_json'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes'])!,
      markersJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}markers_json'])!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String phoneModel;
  final String androidVersion;
  final String appVersion;
  final String scanSettingsJson;
  final String labelsJson;
  final String notes;
  final String markersJson;
  const Session(
      {required this.id,
      required this.startedAt,
      this.endedAt,
      required this.phoneModel,
      required this.androidVersion,
      required this.appVersion,
      required this.scanSettingsJson,
      required this.labelsJson,
      required this.notes,
      required this.markersJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['phone_model'] = Variable<String>(phoneModel);
    map['android_version'] = Variable<String>(androidVersion);
    map['app_version'] = Variable<String>(appVersion);
    map['scan_settings_json'] = Variable<String>(scanSettingsJson);
    map['labels_json'] = Variable<String>(labelsJson);
    map['notes'] = Variable<String>(notes);
    map['markers_json'] = Variable<String>(markersJson);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      phoneModel: Value(phoneModel),
      androidVersion: Value(androidVersion),
      appVersion: Value(appVersion),
      scanSettingsJson: Value(scanSettingsJson),
      labelsJson: Value(labelsJson),
      notes: Value(notes),
      markersJson: Value(markersJson),
    );
  }

  factory Session.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<String>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      phoneModel: serializer.fromJson<String>(json['phoneModel']),
      androidVersion: serializer.fromJson<String>(json['androidVersion']),
      appVersion: serializer.fromJson<String>(json['appVersion']),
      scanSettingsJson: serializer.fromJson<String>(json['scanSettingsJson']),
      labelsJson: serializer.fromJson<String>(json['labelsJson']),
      notes: serializer.fromJson<String>(json['notes']),
      markersJson: serializer.fromJson<String>(json['markersJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'phoneModel': serializer.toJson<String>(phoneModel),
      'androidVersion': serializer.toJson<String>(androidVersion),
      'appVersion': serializer.toJson<String>(appVersion),
      'scanSettingsJson': serializer.toJson<String>(scanSettingsJson),
      'labelsJson': serializer.toJson<String>(labelsJson),
      'notes': serializer.toJson<String>(notes),
      'markersJson': serializer.toJson<String>(markersJson),
    };
  }

  Session copyWith(
          {String? id,
          DateTime? startedAt,
          Value<DateTime?> endedAt = const Value.absent(),
          String? phoneModel,
          String? androidVersion,
          String? appVersion,
          String? scanSettingsJson,
          String? labelsJson,
          String? notes,
          String? markersJson}) =>
      Session(
        id: id ?? this.id,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt.present ? endedAt.value : this.endedAt,
        phoneModel: phoneModel ?? this.phoneModel,
        androidVersion: androidVersion ?? this.androidVersion,
        appVersion: appVersion ?? this.appVersion,
        scanSettingsJson: scanSettingsJson ?? this.scanSettingsJson,
        labelsJson: labelsJson ?? this.labelsJson,
        notes: notes ?? this.notes,
        markersJson: markersJson ?? this.markersJson,
      );
  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('phoneModel: $phoneModel, ')
          ..write('androidVersion: $androidVersion, ')
          ..write('appVersion: $appVersion, ')
          ..write('scanSettingsJson: $scanSettingsJson, ')
          ..write('labelsJson: $labelsJson, ')
          ..write('notes: $notes, ')
          ..write('markersJson: $markersJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      startedAt,
      endedAt,
      phoneModel,
      androidVersion,
      appVersion,
      scanSettingsJson,
      labelsJson,
      notes,
      markersJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.phoneModel == this.phoneModel &&
          other.androidVersion == this.androidVersion &&
          other.appVersion == this.appVersion &&
          other.scanSettingsJson == this.scanSettingsJson &&
          other.labelsJson == this.labelsJson &&
          other.notes == this.notes &&
          other.markersJson == this.markersJson);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<String> id;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<String> phoneModel;
  final Value<String> androidVersion;
  final Value<String> appVersion;
  final Value<String> scanSettingsJson;
  final Value<String> labelsJson;
  final Value<String> notes;
  final Value<String> markersJson;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.phoneModel = const Value.absent(),
    this.androidVersion = const Value.absent(),
    this.appVersion = const Value.absent(),
    this.scanSettingsJson = const Value.absent(),
    this.labelsJson = const Value.absent(),
    this.notes = const Value.absent(),
    this.markersJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.phoneModel = const Value.absent(),
    this.androidVersion = const Value.absent(),
    this.appVersion = const Value.absent(),
    this.scanSettingsJson = const Value.absent(),
    this.labelsJson = const Value.absent(),
    this.notes = const Value.absent(),
    this.markersJson = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        startedAt = Value(startedAt);
  static Insertable<Session> custom({
    Expression<String>? id,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<String>? phoneModel,
    Expression<String>? androidVersion,
    Expression<String>? appVersion,
    Expression<String>? scanSettingsJson,
    Expression<String>? labelsJson,
    Expression<String>? notes,
    Expression<String>? markersJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (phoneModel != null) 'phone_model': phoneModel,
      if (androidVersion != null) 'android_version': androidVersion,
      if (appVersion != null) 'app_version': appVersion,
      if (scanSettingsJson != null) 'scan_settings_json': scanSettingsJson,
      if (labelsJson != null) 'labels_json': labelsJson,
      if (notes != null) 'notes': notes,
      if (markersJson != null) 'markers_json': markersJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? startedAt,
      Value<DateTime?>? endedAt,
      Value<String>? phoneModel,
      Value<String>? androidVersion,
      Value<String>? appVersion,
      Value<String>? scanSettingsJson,
      Value<String>? labelsJson,
      Value<String>? notes,
      Value<String>? markersJson,
      Value<int>? rowid}) {
    return SessionsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      phoneModel: phoneModel ?? this.phoneModel,
      androidVersion: androidVersion ?? this.androidVersion,
      appVersion: appVersion ?? this.appVersion,
      scanSettingsJson: scanSettingsJson ?? this.scanSettingsJson,
      labelsJson: labelsJson ?? this.labelsJson,
      notes: notes ?? this.notes,
      markersJson: markersJson ?? this.markersJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (phoneModel.present) {
      map['phone_model'] = Variable<String>(phoneModel.value);
    }
    if (androidVersion.present) {
      map['android_version'] = Variable<String>(androidVersion.value);
    }
    if (appVersion.present) {
      map['app_version'] = Variable<String>(appVersion.value);
    }
    if (scanSettingsJson.present) {
      map['scan_settings_json'] = Variable<String>(scanSettingsJson.value);
    }
    if (labelsJson.present) {
      map['labels_json'] = Variable<String>(labelsJson.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (markersJson.present) {
      map['markers_json'] = Variable<String>(markersJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('phoneModel: $phoneModel, ')
          ..write('androidVersion: $androidVersion, ')
          ..write('appVersion: $appVersion, ')
          ..write('scanSettingsJson: $scanSettingsJson, ')
          ..write('labelsJson: $labelsJson, ')
          ..write('notes: $notes, ')
          ..write('markersJson: $markersJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CaptureEventsTable extends CaptureEvents
    with TableInfo<$CaptureEventsTable, CaptureEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CaptureEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES sessions (id)'));
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tsMonotonicNanosMeta =
      const VerificationMeta('tsMonotonicNanos');
  @override
  late final GeneratedColumn<int> tsMonotonicNanos = GeneratedColumn<int>(
      'ts_monotonic_nanos', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _tsWallMillisMeta =
      const VerificationMeta('tsWallMillis');
  @override
  late final GeneratedColumn<int> tsWallMillis = GeneratedColumn<int>(
      'ts_wall_millis', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _deviceAddressMeta =
      const VerificationMeta('deviceAddress');
  @override
  late final GeneratedColumn<String> deviceAddress = GeneratedColumn<String>(
      'device_address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _deviceNameMeta =
      const VerificationMeta('deviceName');
  @override
  late final GeneratedColumn<String> deviceName = GeneratedColumn<String>(
      'device_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _rssiMeta = const VerificationMeta('rssi');
  @override
  late final GeneratedColumn<int> rssi = GeneratedColumn<int>(
      'rssi', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<Uint8List> payload = GeneratedColumn<Uint8List>(
      'payload', aliasedName, false,
      type: DriftSqlType.blob, requiredDuringInsert: true);
  static const VerificationMeta _metaJsonMeta =
      const VerificationMeta('metaJson');
  @override
  late final GeneratedColumn<String> metaJson = GeneratedColumn<String>(
      'meta_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sessionId,
        source,
        tsMonotonicNanos,
        tsWallMillis,
        deviceAddress,
        deviceName,
        rssi,
        payload,
        metaJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'capture_events';
  @override
  VerificationContext validateIntegrity(Insertable<CaptureEvent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('ts_monotonic_nanos')) {
      context.handle(
          _tsMonotonicNanosMeta,
          tsMonotonicNanos.isAcceptableOrUnknown(
              data['ts_monotonic_nanos']!, _tsMonotonicNanosMeta));
    } else if (isInserting) {
      context.missing(_tsMonotonicNanosMeta);
    }
    if (data.containsKey('ts_wall_millis')) {
      context.handle(
          _tsWallMillisMeta,
          tsWallMillis.isAcceptableOrUnknown(
              data['ts_wall_millis']!, _tsWallMillisMeta));
    } else if (isInserting) {
      context.missing(_tsWallMillisMeta);
    }
    if (data.containsKey('device_address')) {
      context.handle(
          _deviceAddressMeta,
          deviceAddress.isAcceptableOrUnknown(
              data['device_address']!, _deviceAddressMeta));
    }
    if (data.containsKey('device_name')) {
      context.handle(
          _deviceNameMeta,
          deviceName.isAcceptableOrUnknown(
              data['device_name']!, _deviceNameMeta));
    }
    if (data.containsKey('rssi')) {
      context.handle(
          _rssiMeta, rssi.isAcceptableOrUnknown(data['rssi']!, _rssiMeta));
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('meta_json')) {
      context.handle(_metaJsonMeta,
          metaJson.isAcceptableOrUnknown(data['meta_json']!, _metaJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CaptureEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CaptureEvent(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      tsMonotonicNanos: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}ts_monotonic_nanos'])!,
      tsWallMillis: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ts_wall_millis'])!,
      deviceAddress: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_address']),
      deviceName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}device_name']),
      rssi: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rssi']),
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}payload'])!,
      metaJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}meta_json'])!,
    );
  }

  @override
  $CaptureEventsTable createAlias(String alias) {
    return $CaptureEventsTable(attachedDatabase, alias);
  }
}

class CaptureEvent extends DataClass implements Insertable<CaptureEvent> {
  final String id;
  final String sessionId;
  final String source;
  final int tsMonotonicNanos;
  final int tsWallMillis;
  final String? deviceAddress;
  final String? deviceName;
  final int? rssi;
  final Uint8List payload;
  final String metaJson;
  const CaptureEvent(
      {required this.id,
      required this.sessionId,
      required this.source,
      required this.tsMonotonicNanos,
      required this.tsWallMillis,
      this.deviceAddress,
      this.deviceName,
      this.rssi,
      required this.payload,
      required this.metaJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['source'] = Variable<String>(source);
    map['ts_monotonic_nanos'] = Variable<int>(tsMonotonicNanos);
    map['ts_wall_millis'] = Variable<int>(tsWallMillis);
    if (!nullToAbsent || deviceAddress != null) {
      map['device_address'] = Variable<String>(deviceAddress);
    }
    if (!nullToAbsent || deviceName != null) {
      map['device_name'] = Variable<String>(deviceName);
    }
    if (!nullToAbsent || rssi != null) {
      map['rssi'] = Variable<int>(rssi);
    }
    map['payload'] = Variable<Uint8List>(payload);
    map['meta_json'] = Variable<String>(metaJson);
    return map;
  }

  CaptureEventsCompanion toCompanion(bool nullToAbsent) {
    return CaptureEventsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      source: Value(source),
      tsMonotonicNanos: Value(tsMonotonicNanos),
      tsWallMillis: Value(tsWallMillis),
      deviceAddress: deviceAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceAddress),
      deviceName: deviceName == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceName),
      rssi: rssi == null && nullToAbsent ? const Value.absent() : Value(rssi),
      payload: Value(payload),
      metaJson: Value(metaJson),
    );
  }

  factory CaptureEvent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CaptureEvent(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      source: serializer.fromJson<String>(json['source']),
      tsMonotonicNanos: serializer.fromJson<int>(json['tsMonotonicNanos']),
      tsWallMillis: serializer.fromJson<int>(json['tsWallMillis']),
      deviceAddress: serializer.fromJson<String?>(json['deviceAddress']),
      deviceName: serializer.fromJson<String?>(json['deviceName']),
      rssi: serializer.fromJson<int?>(json['rssi']),
      payload: serializer.fromJson<Uint8List>(json['payload']),
      metaJson: serializer.fromJson<String>(json['metaJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'source': serializer.toJson<String>(source),
      'tsMonotonicNanos': serializer.toJson<int>(tsMonotonicNanos),
      'tsWallMillis': serializer.toJson<int>(tsWallMillis),
      'deviceAddress': serializer.toJson<String?>(deviceAddress),
      'deviceName': serializer.toJson<String?>(deviceName),
      'rssi': serializer.toJson<int?>(rssi),
      'payload': serializer.toJson<Uint8List>(payload),
      'metaJson': serializer.toJson<String>(metaJson),
    };
  }

  CaptureEvent copyWith(
          {String? id,
          String? sessionId,
          String? source,
          int? tsMonotonicNanos,
          int? tsWallMillis,
          Value<String?> deviceAddress = const Value.absent(),
          Value<String?> deviceName = const Value.absent(),
          Value<int?> rssi = const Value.absent(),
          Uint8List? payload,
          String? metaJson}) =>
      CaptureEvent(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        source: source ?? this.source,
        tsMonotonicNanos: tsMonotonicNanos ?? this.tsMonotonicNanos,
        tsWallMillis: tsWallMillis ?? this.tsWallMillis,
        deviceAddress:
            deviceAddress.present ? deviceAddress.value : this.deviceAddress,
        deviceName: deviceName.present ? deviceName.value : this.deviceName,
        rssi: rssi.present ? rssi.value : this.rssi,
        payload: payload ?? this.payload,
        metaJson: metaJson ?? this.metaJson,
      );
  @override
  String toString() {
    return (StringBuffer('CaptureEvent(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('source: $source, ')
          ..write('tsMonotonicNanos: $tsMonotonicNanos, ')
          ..write('tsWallMillis: $tsWallMillis, ')
          ..write('deviceAddress: $deviceAddress, ')
          ..write('deviceName: $deviceName, ')
          ..write('rssi: $rssi, ')
          ..write('payload: $payload, ')
          ..write('metaJson: $metaJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      sessionId,
      source,
      tsMonotonicNanos,
      tsWallMillis,
      deviceAddress,
      deviceName,
      rssi,
      $driftBlobEquality.hash(payload),
      metaJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CaptureEvent &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.source == this.source &&
          other.tsMonotonicNanos == this.tsMonotonicNanos &&
          other.tsWallMillis == this.tsWallMillis &&
          other.deviceAddress == this.deviceAddress &&
          other.deviceName == this.deviceName &&
          other.rssi == this.rssi &&
          $driftBlobEquality.equals(other.payload, this.payload) &&
          other.metaJson == this.metaJson);
}

class CaptureEventsCompanion extends UpdateCompanion<CaptureEvent> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> source;
  final Value<int> tsMonotonicNanos;
  final Value<int> tsWallMillis;
  final Value<String?> deviceAddress;
  final Value<String?> deviceName;
  final Value<int?> rssi;
  final Value<Uint8List> payload;
  final Value<String> metaJson;
  final Value<int> rowid;
  const CaptureEventsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.source = const Value.absent(),
    this.tsMonotonicNanos = const Value.absent(),
    this.tsWallMillis = const Value.absent(),
    this.deviceAddress = const Value.absent(),
    this.deviceName = const Value.absent(),
    this.rssi = const Value.absent(),
    this.payload = const Value.absent(),
    this.metaJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CaptureEventsCompanion.insert({
    required String id,
    required String sessionId,
    required String source,
    required int tsMonotonicNanos,
    required int tsWallMillis,
    this.deviceAddress = const Value.absent(),
    this.deviceName = const Value.absent(),
    this.rssi = const Value.absent(),
    required Uint8List payload,
    this.metaJson = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionId = Value(sessionId),
        source = Value(source),
        tsMonotonicNanos = Value(tsMonotonicNanos),
        tsWallMillis = Value(tsWallMillis),
        payload = Value(payload);
  static Insertable<CaptureEvent> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? source,
    Expression<int>? tsMonotonicNanos,
    Expression<int>? tsWallMillis,
    Expression<String>? deviceAddress,
    Expression<String>? deviceName,
    Expression<int>? rssi,
    Expression<Uint8List>? payload,
    Expression<String>? metaJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (source != null) 'source': source,
      if (tsMonotonicNanos != null) 'ts_monotonic_nanos': tsMonotonicNanos,
      if (tsWallMillis != null) 'ts_wall_millis': tsWallMillis,
      if (deviceAddress != null) 'device_address': deviceAddress,
      if (deviceName != null) 'device_name': deviceName,
      if (rssi != null) 'rssi': rssi,
      if (payload != null) 'payload': payload,
      if (metaJson != null) 'meta_json': metaJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CaptureEventsCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionId,
      Value<String>? source,
      Value<int>? tsMonotonicNanos,
      Value<int>? tsWallMillis,
      Value<String?>? deviceAddress,
      Value<String?>? deviceName,
      Value<int?>? rssi,
      Value<Uint8List>? payload,
      Value<String>? metaJson,
      Value<int>? rowid}) {
    return CaptureEventsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      source: source ?? this.source,
      tsMonotonicNanos: tsMonotonicNanos ?? this.tsMonotonicNanos,
      tsWallMillis: tsWallMillis ?? this.tsWallMillis,
      deviceAddress: deviceAddress ?? this.deviceAddress,
      deviceName: deviceName ?? this.deviceName,
      rssi: rssi ?? this.rssi,
      payload: payload ?? this.payload,
      metaJson: metaJson ?? this.metaJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (tsMonotonicNanos.present) {
      map['ts_monotonic_nanos'] = Variable<int>(tsMonotonicNanos.value);
    }
    if (tsWallMillis.present) {
      map['ts_wall_millis'] = Variable<int>(tsWallMillis.value);
    }
    if (deviceAddress.present) {
      map['device_address'] = Variable<String>(deviceAddress.value);
    }
    if (deviceName.present) {
      map['device_name'] = Variable<String>(deviceName.value);
    }
    if (rssi.present) {
      map['rssi'] = Variable<int>(rssi.value);
    }
    if (payload.present) {
      map['payload'] = Variable<Uint8List>(payload.value);
    }
    if (metaJson.present) {
      map['meta_json'] = Variable<String>(metaJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CaptureEventsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('source: $source, ')
          ..write('tsMonotonicNanos: $tsMonotonicNanos, ')
          ..write('tsWallMillis: $tsWallMillis, ')
          ..write('deviceAddress: $deviceAddress, ')
          ..write('deviceName: $deviceName, ')
          ..write('rssi: $rssi, ')
          ..write('payload: $payload, ')
          ..write('metaJson: $metaJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PinnedDevicesTable extends PinnedDevices
    with TableInfo<$PinnedDevicesTable, PinnedDevice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PinnedDevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _addressMeta =
      const VerificationMeta('address');
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
      'address', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _namePatternMeta =
      const VerificationMeta('namePattern');
  @override
  late final GeneratedColumn<String> namePattern = GeneratedColumn<String>(
      'name_pattern', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _serviceUuidsJsonMeta =
      const VerificationMeta('serviceUuidsJson');
  @override
  late final GeneratedColumn<String> serviceUuidsJson = GeneratedColumn<String>(
      'service_uuids_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _manufacturerDataMarkersJsonMeta =
      const VerificationMeta('manufacturerDataMarkersJson');
  @override
  late final GeneratedColumn<String> manufacturerDataMarkersJson =
      GeneratedColumn<String>(
          'manufacturer_data_markers_json', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
      'display_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pinnedAtMeta =
      const VerificationMeta('pinnedAt');
  @override
  late final GeneratedColumn<DateTime> pinnedAt = GeneratedColumn<DateTime>(
      'pinned_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        address,
        namePattern,
        serviceUuidsJson,
        manufacturerDataMarkersJson,
        displayName,
        pinnedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pinned_devices';
  @override
  VerificationContext validateIntegrity(Insertable<PinnedDevice> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('address')) {
      context.handle(_addressMeta,
          address.isAcceptableOrUnknown(data['address']!, _addressMeta));
    }
    if (data.containsKey('name_pattern')) {
      context.handle(
          _namePatternMeta,
          namePattern.isAcceptableOrUnknown(
              data['name_pattern']!, _namePatternMeta));
    }
    if (data.containsKey('service_uuids_json')) {
      context.handle(
          _serviceUuidsJsonMeta,
          serviceUuidsJson.isAcceptableOrUnknown(
              data['service_uuids_json']!, _serviceUuidsJsonMeta));
    }
    if (data.containsKey('manufacturer_data_markers_json')) {
      context.handle(
          _manufacturerDataMarkersJsonMeta,
          manufacturerDataMarkersJson.isAcceptableOrUnknown(
              data['manufacturer_data_markers_json']!,
              _manufacturerDataMarkersJsonMeta));
    }
    if (data.containsKey('display_name')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['display_name']!, _displayNameMeta));
    }
    if (data.containsKey('pinned_at')) {
      context.handle(_pinnedAtMeta,
          pinnedAt.isAcceptableOrUnknown(data['pinned_at']!, _pinnedAtMeta));
    } else if (isInserting) {
      context.missing(_pinnedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PinnedDevice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PinnedDevice(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      address: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}address']),
      namePattern: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name_pattern']),
      serviceUuidsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}service_uuids_json']),
      manufacturerDataMarkersJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}manufacturer_data_markers_json']),
      displayName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}display_name']),
      pinnedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}pinned_at'])!,
    );
  }

  @override
  $PinnedDevicesTable createAlias(String alias) {
    return $PinnedDevicesTable(attachedDatabase, alias);
  }
}

class PinnedDevice extends DataClass implements Insertable<PinnedDevice> {
  final String id;
  final String? address;
  final String? namePattern;
  final String? serviceUuidsJson;
  final String? manufacturerDataMarkersJson;
  final String? displayName;
  final DateTime pinnedAt;
  const PinnedDevice(
      {required this.id,
      this.address,
      this.namePattern,
      this.serviceUuidsJson,
      this.manufacturerDataMarkersJson,
      this.displayName,
      required this.pinnedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || namePattern != null) {
      map['name_pattern'] = Variable<String>(namePattern);
    }
    if (!nullToAbsent || serviceUuidsJson != null) {
      map['service_uuids_json'] = Variable<String>(serviceUuidsJson);
    }
    if (!nullToAbsent || manufacturerDataMarkersJson != null) {
      map['manufacturer_data_markers_json'] =
          Variable<String>(manufacturerDataMarkersJson);
    }
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    map['pinned_at'] = Variable<DateTime>(pinnedAt);
    return map;
  }

  PinnedDevicesCompanion toCompanion(bool nullToAbsent) {
    return PinnedDevicesCompanion(
      id: Value(id),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      namePattern: namePattern == null && nullToAbsent
          ? const Value.absent()
          : Value(namePattern),
      serviceUuidsJson: serviceUuidsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(serviceUuidsJson),
      manufacturerDataMarkersJson:
          manufacturerDataMarkersJson == null && nullToAbsent
              ? const Value.absent()
              : Value(manufacturerDataMarkersJson),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      pinnedAt: Value(pinnedAt),
    );
  }

  factory PinnedDevice.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PinnedDevice(
      id: serializer.fromJson<String>(json['id']),
      address: serializer.fromJson<String?>(json['address']),
      namePattern: serializer.fromJson<String?>(json['namePattern']),
      serviceUuidsJson: serializer.fromJson<String?>(json['serviceUuidsJson']),
      manufacturerDataMarkersJson:
          serializer.fromJson<String?>(json['manufacturerDataMarkersJson']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      pinnedAt: serializer.fromJson<DateTime>(json['pinnedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'address': serializer.toJson<String?>(address),
      'namePattern': serializer.toJson<String?>(namePattern),
      'serviceUuidsJson': serializer.toJson<String?>(serviceUuidsJson),
      'manufacturerDataMarkersJson':
          serializer.toJson<String?>(manufacturerDataMarkersJson),
      'displayName': serializer.toJson<String?>(displayName),
      'pinnedAt': serializer.toJson<DateTime>(pinnedAt),
    };
  }

  PinnedDevice copyWith(
          {String? id,
          Value<String?> address = const Value.absent(),
          Value<String?> namePattern = const Value.absent(),
          Value<String?> serviceUuidsJson = const Value.absent(),
          Value<String?> manufacturerDataMarkersJson = const Value.absent(),
          Value<String?> displayName = const Value.absent(),
          DateTime? pinnedAt}) =>
      PinnedDevice(
        id: id ?? this.id,
        address: address.present ? address.value : this.address,
        namePattern: namePattern.present ? namePattern.value : this.namePattern,
        serviceUuidsJson: serviceUuidsJson.present
            ? serviceUuidsJson.value
            : this.serviceUuidsJson,
        manufacturerDataMarkersJson: manufacturerDataMarkersJson.present
            ? manufacturerDataMarkersJson.value
            : this.manufacturerDataMarkersJson,
        displayName: displayName.present ? displayName.value : this.displayName,
        pinnedAt: pinnedAt ?? this.pinnedAt,
      );
  @override
  String toString() {
    return (StringBuffer('PinnedDevice(')
          ..write('id: $id, ')
          ..write('address: $address, ')
          ..write('namePattern: $namePattern, ')
          ..write('serviceUuidsJson: $serviceUuidsJson, ')
          ..write('manufacturerDataMarkersJson: $manufacturerDataMarkersJson, ')
          ..write('displayName: $displayName, ')
          ..write('pinnedAt: $pinnedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, address, namePattern, serviceUuidsJson,
      manufacturerDataMarkersJson, displayName, pinnedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PinnedDevice &&
          other.id == this.id &&
          other.address == this.address &&
          other.namePattern == this.namePattern &&
          other.serviceUuidsJson == this.serviceUuidsJson &&
          other.manufacturerDataMarkersJson ==
              this.manufacturerDataMarkersJson &&
          other.displayName == this.displayName &&
          other.pinnedAt == this.pinnedAt);
}

class PinnedDevicesCompanion extends UpdateCompanion<PinnedDevice> {
  final Value<String> id;
  final Value<String?> address;
  final Value<String?> namePattern;
  final Value<String?> serviceUuidsJson;
  final Value<String?> manufacturerDataMarkersJson;
  final Value<String?> displayName;
  final Value<DateTime> pinnedAt;
  final Value<int> rowid;
  const PinnedDevicesCompanion({
    this.id = const Value.absent(),
    this.address = const Value.absent(),
    this.namePattern = const Value.absent(),
    this.serviceUuidsJson = const Value.absent(),
    this.manufacturerDataMarkersJson = const Value.absent(),
    this.displayName = const Value.absent(),
    this.pinnedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PinnedDevicesCompanion.insert({
    required String id,
    this.address = const Value.absent(),
    this.namePattern = const Value.absent(),
    this.serviceUuidsJson = const Value.absent(),
    this.manufacturerDataMarkersJson = const Value.absent(),
    this.displayName = const Value.absent(),
    required DateTime pinnedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        pinnedAt = Value(pinnedAt);
  static Insertable<PinnedDevice> custom({
    Expression<String>? id,
    Expression<String>? address,
    Expression<String>? namePattern,
    Expression<String>? serviceUuidsJson,
    Expression<String>? manufacturerDataMarkersJson,
    Expression<String>? displayName,
    Expression<DateTime>? pinnedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (address != null) 'address': address,
      if (namePattern != null) 'name_pattern': namePattern,
      if (serviceUuidsJson != null) 'service_uuids_json': serviceUuidsJson,
      if (manufacturerDataMarkersJson != null)
        'manufacturer_data_markers_json': manufacturerDataMarkersJson,
      if (displayName != null) 'display_name': displayName,
      if (pinnedAt != null) 'pinned_at': pinnedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PinnedDevicesCompanion copyWith(
      {Value<String>? id,
      Value<String?>? address,
      Value<String?>? namePattern,
      Value<String?>? serviceUuidsJson,
      Value<String?>? manufacturerDataMarkersJson,
      Value<String?>? displayName,
      Value<DateTime>? pinnedAt,
      Value<int>? rowid}) {
    return PinnedDevicesCompanion(
      id: id ?? this.id,
      address: address ?? this.address,
      namePattern: namePattern ?? this.namePattern,
      serviceUuidsJson: serviceUuidsJson ?? this.serviceUuidsJson,
      manufacturerDataMarkersJson:
          manufacturerDataMarkersJson ?? this.manufacturerDataMarkersJson,
      displayName: displayName ?? this.displayName,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (namePattern.present) {
      map['name_pattern'] = Variable<String>(namePattern.value);
    }
    if (serviceUuidsJson.present) {
      map['service_uuids_json'] = Variable<String>(serviceUuidsJson.value);
    }
    if (manufacturerDataMarkersJson.present) {
      map['manufacturer_data_markers_json'] =
          Variable<String>(manufacturerDataMarkersJson.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (pinnedAt.present) {
      map['pinned_at'] = Variable<DateTime>(pinnedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PinnedDevicesCompanion(')
          ..write('id: $id, ')
          ..write('address: $address, ')
          ..write('namePattern: $namePattern, ')
          ..write('serviceUuidsJson: $serviceUuidsJson, ')
          ..write('manufacturerDataMarkersJson: $manufacturerDataMarkersJson, ')
          ..write('displayName: $displayName, ')
          ..write('pinnedAt: $pinnedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $CaptureEventsTable captureEvents = $CaptureEventsTable(this);
  late final $PinnedDevicesTable pinnedDevices = $PinnedDevicesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [sessions, captureEvents, pinnedDevices];
}
