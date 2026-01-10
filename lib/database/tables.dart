import 'package:drift/drift.dart';

class Sessions extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get phoneModel => text().withDefault(const Constant(''))();
  TextColumn get androidVersion => text().withDefault(const Constant(''))();
  TextColumn get appVersion => text().withDefault(const Constant(''))();
  TextColumn get scanSettingsJson => text().withDefault(const Constant('{}'))();
  TextColumn get labelsJson => text().withDefault(const Constant('[]'))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get markersJson => text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {id};
}

class CaptureEvents extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(Sessions, #id)();
  TextColumn get source => text()();
  IntColumn get tsMonotonicNanos => integer()();
  IntColumn get tsWallMillis => integer()();
  TextColumn get deviceAddress => text().nullable()();
  TextColumn get deviceName => text().nullable()();
  IntColumn get rssi => integer().nullable()();
  BlobColumn get payload => blob()();
  TextColumn get metaJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}

class PinnedDevices extends Table {
  TextColumn get id => text()();
  TextColumn get address => text().nullable()();
  TextColumn get namePattern => text().nullable()();
  TextColumn get serviceUuidsJson => text().nullable()();
  TextColumn get manufacturerDataMarkersJson => text().nullable()();
  TextColumn get displayName => text().nullable()();
  DateTimeColumn get pinnedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
