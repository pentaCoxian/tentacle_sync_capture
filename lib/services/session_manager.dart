import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../models/capture_event.dart' as models;
import '../models/capture_session.dart' as models;
import '../models/pinned_device.dart' as models;
import 'ble_service.dart';

typedef CaptureEvent = models.CaptureEvent;
typedef CaptureSession = models.CaptureSession;
typedef PinnedDevice = models.PinnedDevice;

class SessionManager {
  final AppDatabase _database;
  final BleService _bleService;
  final Uuid _uuid = const Uuid();

  CaptureSession? _activeSession;
  StreamSubscription<Map<String, dynamic>>? _scanSubscription;
  StreamSubscription<Map<String, dynamic>>? _gattSubscription;

  final List<CaptureEvent> _eventBuffer = [];
  static const int _bufferFlushThreshold = 50;
  Timer? _flushTimer;

  int _eventCount = 0;
  int _eventsPerSecond = 0;
  DateTime _lastRateUpdate = DateTime.now();
  int _eventsSinceLastUpdate = 0;

  final _sessionStreamController = StreamController<CaptureSession?>.broadcast();
  final _eventStreamController = StreamController<CaptureEvent>.broadcast();
  final _statsStreamController = StreamController<SessionStats>.broadcast();

  Stream<CaptureSession?> get sessionStream => _sessionStreamController.stream;
  Stream<CaptureEvent> get eventStream => _eventStreamController.stream;
  Stream<SessionStats> get statsStream => _statsStreamController.stream;

  CaptureSession? get activeSession => _activeSession;
  bool get isCapturing => _activeSession != null;
  int get eventCount => _eventCount;

  SessionManager({
    required AppDatabase database,
    required BleService bleService,
  })  : _database = database,
        _bleService = bleService;

  Future<CaptureSession> startSession({
    int scanMode = BleService.scanModeLowLatency,
    String? filterByName,
    String? filterByServiceUuid,
    PinnedDevice? pinnedDevice,
  }) async {
    if (_activeSession != null) {
      await stopSession();
    }

    // Get device info
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    final packageInfo = await PackageInfo.fromPlatform();

    final session = CaptureSession(
      id: _uuid.v4(),
      startedAt: DateTime.now(),
      phoneModel: '${androidInfo.manufacturer} ${androidInfo.model}',
      androidVersion: 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})',
      appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
      scanSettings: {
        'scanMode': scanMode,
        'filterByName': filterByName,
        'filterByServiceUuid': filterByServiceUuid,
        'pinnedDeviceId': pinnedDevice?.id,
      },
    );

    await _database.insertSession(session);
    _activeSession = session;
    _eventCount = 0;
    _eventsPerSecond = 0;
    _lastRateUpdate = DateTime.now();
    _eventsSinceLastUpdate = 0;

    _sessionStreamController.add(session);

    // Start scanning
    await _bleService.startScan(
      scanMode: scanMode,
      filterByName: filterByName ?? pinnedDevice?.namePattern,
      filterByServiceUuid: filterByServiceUuid,
    );

    // Subscribe to scan events
    _scanSubscription = _bleService.scanStream.listen((scanResult) {
      if (_activeSession != null) {
        // If we have a pinned device, filter by it
        if (pinnedDevice != null && !pinnedDevice.matches(scanResult)) {
          return;
        }

        final event = CaptureEvent.fromScanResult(
          id: _uuid.v4(),
          sessionId: _activeSession!.id,
          scanResult: scanResult,
        );
        _handleEvent(event);
      }
    });

    // Subscribe to GATT events
    _gattSubscription = _bleService.gattStream.listen((gattEvent) {
      if (_activeSession != null) {
        final eventType = gattEvent['eventType'] as String?;
        if (eventType == 'characteristicEvent') {
          final event = CaptureEvent.fromGattEvent(
            id: _uuid.v4(),
            sessionId: _activeSession!.id,
            gattEvent: gattEvent,
          );
          _handleEvent(event);
        }
      }
    });

    // Start flush timer
    _flushTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _flushBuffer();
      _updateStats();
    });

    return session;
  }

  void _handleEvent(CaptureEvent event) {
    _eventBuffer.add(event);
    _eventCount++;
    _eventsSinceLastUpdate++;
    _eventStreamController.add(event);

    if (_eventBuffer.length >= _bufferFlushThreshold) {
      _flushBuffer();
    }
  }

  Future<void> _flushBuffer() async {
    if (_eventBuffer.isEmpty) return;

    final events = List<CaptureEvent>.from(_eventBuffer);
    _eventBuffer.clear();

    await _database.insertCaptureEventsBatch(events);
  }

  void _updateStats() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRateUpdate).inMilliseconds;
    if (elapsed > 0) {
      _eventsPerSecond = (_eventsSinceLastUpdate * 1000 / elapsed).round();
      _eventsSinceLastUpdate = 0;
      _lastRateUpdate = now;

      _statsStreamController.add(SessionStats(
        eventCount: _eventCount,
        eventsPerSecond: _eventsPerSecond,
        duration: _activeSession != null
            ? now.difference(_activeSession!.startedAt)
            : Duration.zero,
      ));
    }
  }

  Future<void> addMarker(String text) async {
    if (_activeSession != null) {
      _activeSession!.addMarker(text);
      await _database.updateSession(_activeSession!);
    }
  }

  Future<void> addLabel(String label) async {
    if (_activeSession != null) {
      _activeSession!.addLabel(label);
      await _database.updateSession(_activeSession!);
      _sessionStreamController.add(_activeSession);
    }
  }

  Future<CaptureSession?> stopSession() async {
    if (_activeSession == null) return null;

    // Stop scanning
    await _bleService.stopScan();

    // Cancel subscriptions
    await _scanSubscription?.cancel();
    await _gattSubscription?.cancel();
    _scanSubscription = null;
    _gattSubscription = null;

    // Cancel flush timer
    _flushTimer?.cancel();
    _flushTimer = null;

    // Flush remaining events
    await _flushBuffer();

    // End the session
    _activeSession!.end();
    await _database.updateSession(_activeSession!);

    final session = _activeSession;
    _activeSession = null;
    _sessionStreamController.add(null);

    return session;
  }

  Future<List<CaptureSession>> getAllSessions() async {
    return _database.getAllSessions();
  }

  Future<CaptureSession?> getSession(String id) async {
    return _database.getSession(id);
  }

  Future<List<CaptureEvent>> getEventsForSession(String sessionId,
      {int? limit, int? offset}) async {
    return _database.getEventsForSession(sessionId, limit: limit, offset: offset);
  }

  Future<int> getEventCountForSession(String sessionId) async {
    return _database.getEventCountForSession(sessionId);
  }

  Stream<List<CaptureEvent>> watchEventsForSession(String sessionId) {
    return _database.watchEventsForSession(sessionId);
  }

  Future<void> deleteSession(String sessionId) async {
    await _database.deleteSession(sessionId);
  }

  Future<void> updateSessionNotes(String sessionId, String notes) async {
    final session = await _database.getSession(sessionId);
    if (session != null) {
      final updated = session.copyWith(notes: notes);
      await _database.updateSession(updated);
    }
  }

  Future<void> updateSessionLabels(String sessionId, List<String> labels) async {
    final session = await _database.getSession(sessionId);
    if (session != null) {
      final updated = session.copyWith(labels: labels);
      await _database.updateSession(updated);
    }
  }

  void dispose() {
    _scanSubscription?.cancel();
    _gattSubscription?.cancel();
    _flushTimer?.cancel();
    _sessionStreamController.close();
    _eventStreamController.close();
    _statsStreamController.close();
  }
}

class SessionStats {
  final int eventCount;
  final int eventsPerSecond;
  final Duration duration;

  SessionStats({
    required this.eventCount,
    required this.eventsPerSecond,
    required this.duration,
  });
}
