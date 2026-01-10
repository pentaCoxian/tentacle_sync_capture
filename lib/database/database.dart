import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/capture_event.dart' as models;
import '../models/capture_session.dart' as models;
import '../models/pinned_device.dart' as models;
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Sessions, CaptureEvents, PinnedDevices])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  // Session operations
  Future<void> insertSession(models.CaptureSession session) async {
    await into(sessions).insert(SessionsCompanion.insert(
      id: session.id,
      startedAt: session.startedAt,
      endedAt: Value(session.endedAt),
      phoneModel: Value(session.phoneModel),
      androidVersion: Value(session.androidVersion),
      appVersion: Value(session.appVersion),
      scanSettingsJson: Value(jsonEncode(session.scanSettings)),
      labelsJson: Value(jsonEncode(session.labels)),
      notes: Value(session.notes),
      markersJson: Value(jsonEncode(session.markers.map((m) => m.toJson()).toList())),
    ));
  }

  Future<void> updateSession(models.CaptureSession session) async {
    await (update(sessions)..where((s) => s.id.equals(session.id))).write(
      SessionsCompanion(
        endedAt: Value(session.endedAt),
        labelsJson: Value(jsonEncode(session.labels)),
        notes: Value(session.notes),
        markersJson: Value(jsonEncode(session.markers.map((m) => m.toJson()).toList())),
      ),
    );
  }

  Future<List<models.CaptureSession>> getAllSessions() async {
    final rows = await (select(sessions)
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .get();
    return rows.map(_rowToSession).toList();
  }

  Future<models.CaptureSession?> getSession(String id) async {
    final row = await (select(sessions)..where((s) => s.id.equals(id))).getSingleOrNull();
    return row != null ? _rowToSession(row) : null;
  }

  Future<void> deleteSession(String sessionId) async {
    await (delete(captureEvents)..where((e) => e.sessionId.equals(sessionId))).go();
    await (delete(sessions)..where((s) => s.id.equals(sessionId))).go();
  }

  models.CaptureSession _rowToSession(Session row) {
    return models.CaptureSession(
      id: row.id,
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      phoneModel: row.phoneModel,
      androidVersion: row.androidVersion,
      appVersion: row.appVersion,
      scanSettings: jsonDecode(row.scanSettingsJson) as Map<String, dynamic>,
      labels: (jsonDecode(row.labelsJson) as List<dynamic>).cast<String>(),
      notes: row.notes,
      markers: (jsonDecode(row.markersJson) as List<dynamic>)
          .map((m) => models.SessionMarker.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  // Capture event operations
  Future<void> insertCaptureEvent(models.CaptureEvent event) async {
    await into(captureEvents).insert(CaptureEventsCompanion.insert(
      id: event.id,
      sessionId: event.sessionId,
      source: event.source.name,
      tsMonotonicNanos: event.tsMonotonicNanos,
      tsWallMillis: event.tsWallMillis,
      deviceAddress: Value(event.deviceAddress),
      deviceName: Value(event.deviceName),
      rssi: Value(event.rssi),
      payload: event.payload,
      metaJson: Value(jsonEncode(event.meta)),
    ));
  }

  Future<void> insertCaptureEventsBatch(List<models.CaptureEvent> events) async {
    await batch((batch) {
      for (final event in events) {
        batch.insert(
          captureEvents,
          CaptureEventsCompanion.insert(
            id: event.id,
            sessionId: event.sessionId,
            source: event.source.name,
            tsMonotonicNanos: event.tsMonotonicNanos,
            tsWallMillis: event.tsWallMillis,
            deviceAddress: Value(event.deviceAddress),
            deviceName: Value(event.deviceName),
            rssi: Value(event.rssi),
            payload: event.payload,
            metaJson: Value(jsonEncode(event.meta)),
          ),
        );
      }
    });
  }

  Future<List<models.CaptureEvent>> getEventsForSession(String sessionId, {int? limit, int? offset}) async {
    var query = select(captureEvents)..where((e) => e.sessionId.equals(sessionId));
    query = query..orderBy([(e) => OrderingTerm.asc(e.tsWallMillis)]);
    if (limit != null) {
      query = query..limit(limit, offset: offset);
    }
    final rows = await query.get();
    return rows.map(_rowToEvent).toList();
  }

  Future<int> getEventCountForSession(String sessionId) async {
    final count = captureEvents.id.count();
    final query = selectOnly(captureEvents)
      ..addColumns([count])
      ..where(captureEvents.sessionId.equals(sessionId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  Future<models.CaptureEvent?> getEvent(String id) async {
    final row = await (select(captureEvents)..where((e) => e.id.equals(id))).getSingleOrNull();
    return row != null ? _rowToEvent(row) : null;
  }

  Stream<List<models.CaptureEvent>> watchEventsForSession(String sessionId) {
    return (select(captureEvents)
          ..where((e) => e.sessionId.equals(sessionId))
          ..orderBy([(e) => OrderingTerm.asc(e.tsWallMillis)]))
        .watch()
        .map((rows) => rows.map(_rowToEvent).toList());
  }

  models.CaptureEvent _rowToEvent(CaptureEvent row) {
    final source = models.CaptureSource.values.firstWhere(
      (s) => s.name == row.source,
      orElse: () => models.CaptureSource.adv,
    );
    return models.CaptureEvent(
      id: row.id,
      sessionId: row.sessionId,
      source: source,
      tsMonotonicNanos: row.tsMonotonicNanos,
      tsWallMillis: row.tsWallMillis,
      deviceAddress: row.deviceAddress,
      deviceName: row.deviceName,
      rssi: row.rssi,
      payload: Uint8List.fromList(row.payload),
      meta: jsonDecode(row.metaJson) as Map<String, dynamic>,
    );
  }

  // Pinned device operations
  Future<void> insertPinnedDevice(models.PinnedDevice device) async {
    await into(pinnedDevices).insert(PinnedDevicesCompanion.insert(
      id: device.id,
      address: Value(device.address),
      namePattern: Value(device.namePattern),
      serviceUuidsJson: Value(device.serviceUuids != null ? jsonEncode(device.serviceUuids) : null),
      manufacturerDataMarkersJson: Value(
        device.manufacturerDataMarkers != null
            ? jsonEncode(device.manufacturerDataMarkers!.map((k, v) => MapEntry(k.toString(), v)))
            : null,
      ),
      displayName: Value(device.displayName),
      pinnedAt: device.pinnedAt,
    ));
  }

  Future<void> deletePinnedDevice(String id) async {
    await (delete(pinnedDevices)..where((d) => d.id.equals(id))).go();
  }

  Future<List<models.PinnedDevice>> getAllPinnedDevices() async {
    final rows = await select(pinnedDevices).get();
    return rows.map(_rowToPinnedDevice).toList();
  }

  models.PinnedDevice _rowToPinnedDevice(PinnedDevice row) {
    Map<int, List<int>>? markers;
    if (row.manufacturerDataMarkersJson != null) {
      final decoded = jsonDecode(row.manufacturerDataMarkersJson!) as Map<String, dynamic>;
      markers = decoded.map((k, v) => MapEntry(int.parse(k), (v as List<dynamic>).cast<int>()));
    }

    return models.PinnedDevice(
      id: row.id,
      address: row.address,
      namePattern: row.namePattern,
      serviceUuids: row.serviceUuidsJson != null
          ? (jsonDecode(row.serviceUuidsJson!) as List<dynamic>).cast<String>()
          : null,
      manufacturerDataMarkers: markers,
      displayName: row.displayName,
      pinnedAt: row.pinnedAt,
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'tentacle_capture.db'));
    return NativeDatabase.createInBackground(file);
  });
}
