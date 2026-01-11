import 'dart:async';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class BleService {
  static const _methodChannel = MethodChannel('com.example.tentacle_sync_capture/ble_method');
  static const _scanEventChannel = EventChannel('com.example.tentacle_sync_capture/ble_scan_events');
  static const _gattEventChannel = EventChannel('com.example.tentacle_sync_capture/ble_gatt_events');

  Stream<Map<String, dynamic>>? _scanStream;
  Stream<Map<String, dynamic>>? _gattStream;
  StreamController<Map<String, dynamic>>? _scanStreamController;
  StreamSubscription? _scanEventSubscription;

  // Scan mode constants (match Android ScanSettings)
  static const int scanModeLowPower = 0;
  static const int scanModeBalanced = 1;
  static const int scanModeLowLatency = 2;

  // Permission handling
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((status) =>
        status.isGranted || status.isLimited);
  }

  Future<bool> hasPermissions() async {
    final bluetoothScan = await Permission.bluetoothScan.status;
    final bluetoothConnect = await Permission.bluetoothConnect.status;
    final location = await Permission.location.status;

    return (bluetoothScan.isGranted || bluetoothScan.isLimited) &&
        (bluetoothConnect.isGranted || bluetoothConnect.isLimited) &&
        (location.isGranted || location.isLimited);
  }

  // Scanning - use a broadcast StreamController for multiple listeners
  Stream<Map<String, dynamic>> get scanStream {
    if (_scanStreamController == null) {
      _scanStreamController = StreamController<Map<String, dynamic>>.broadcast();
      _scanEventSubscription = _scanEventChannel
          .receiveBroadcastStream()
          .listen((event) {
        if (!_scanStreamController!.isClosed) {
          _scanStreamController!.add(Map<String, dynamic>.from(event as Map));
        }
      });
    }
    return _scanStreamController!.stream;
  }

  Future<void> startScan({
    int scanMode = scanModeLowLatency,
    String? filterByName,
    String? filterByServiceUuid,
  }) async {
    await _methodChannel.invokeMethod('startScan', {
      'scanMode': scanMode,
      'filterByName': filterByName,
      'filterByServiceUuid': filterByServiceUuid,
    });
  }

  Future<void> stopScan() async {
    await _methodChannel.invokeMethod('stopScan');
  }

  Future<bool> isScanning() async {
    final result = await _methodChannel.invokeMethod<bool>('isScanning');
    return result ?? false;
  }

  // GATT operations
  Stream<Map<String, dynamic>> get gattStream {
    _gattStream ??= _gattEventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _gattStream!;
  }

  Future<void> connect(String address) async {
    await _methodChannel.invokeMethod('connect', {'address': address});
  }

  Future<void> disconnect() async {
    await _methodChannel.invokeMethod('disconnect');
  }

  Future<void> discoverServices() async {
    await _methodChannel.invokeMethod('discoverServices');
  }

  Future<List<BleService_Service>> getServices() async {
    final result = await _methodChannel.invokeMethod<String>('getServices');
    if (result == null || result == '[]') return [];

    // Parse JSON string from Kotlin
    // The Kotlin side returns a JSON string, so we need to decode it
    final List<dynamic> servicesJson = _parseJsonArray(result);
    return servicesJson.map((s) => BleService_Service.fromJson(s as Map<String, dynamic>)).toList();
  }

  Future<bool> subscribe(String serviceUuid, String characteristicUuid) async {
    final result = await _methodChannel.invokeMethod<bool>('subscribe', {
      'serviceUuid': serviceUuid,
      'characteristicUuid': characteristicUuid,
    });
    return result ?? false;
  }

  Future<bool> unsubscribe(String serviceUuid, String characteristicUuid) async {
    final result = await _methodChannel.invokeMethod<bool>('unsubscribe', {
      'serviceUuid': serviceUuid,
      'characteristicUuid': characteristicUuid,
    });
    return result ?? false;
  }

  Future<void> readCharacteristic(String serviceUuid, String characteristicUuid) async {
    await _methodChannel.invokeMethod('readCharacteristic', {
      'serviceUuid': serviceUuid,
      'characteristicUuid': characteristicUuid,
    });
  }

  Future<bool> isConnected() async {
    final result = await _methodChannel.invokeMethod<bool>('isConnected');
    return result ?? false;
  }

  Future<String> getConnectionState() async {
    final result = await _methodChannel.invokeMethod<String>('getConnectionState');
    return result ?? 'unknown';
  }

  // IPC methods for broadcasting timecode to other apps
  Future<void> setIpcEnabled(bool enabled) async {
    await _methodChannel.invokeMethod('setIpcEnabled', {'enabled': enabled});
  }

  Future<bool> isIpcEnabled() async {
    final result = await _methodChannel.invokeMethod<bool>('isIpcEnabled');
    return result ?? false;
  }

  /// Broadcast timecode to other Android apps via broadcast intent.
  ///
  /// Other apps can receive by registering a BroadcastReceiver for action:
  /// "com.example.tentacle_sync_capture.TIMECODE_UPDATE"
  ///
  /// Intent extras:
  /// - hours, minutes, seconds, frames (Int)
  /// - timecode (String, formatted HH:MM:SS:FF)
  /// - fps (Double)
  /// - dropFrame (Boolean)
  /// - timestamp (Long, system time in millis)
  /// - deviceAddress (String)
  /// - deviceName (String, optional)
  Future<void> broadcastTimecode({
    required int hours,
    required int minutes,
    required int seconds,
    required int frames,
    required double fps,
    bool dropFrame = false,
    required String deviceAddress,
    String? deviceName,
  }) async {
    await _methodChannel.invokeMethod('broadcastTimecode', {
      'hours': hours,
      'minutes': minutes,
      'seconds': seconds,
      'frames': frames,
      'fps': fps,
      'dropFrame': dropFrame,
      'deviceAddress': deviceAddress,
      'deviceName': deviceName,
    });
  }

  List<dynamic> _parseJsonArray(String json) {
    // Simple JSON array parser
    if (json.isEmpty || json == '[]') return [];

    try {
      // Use dart:convert for proper JSON parsing
      return _decodeJson(json) as List<dynamic>;
    } catch (e) {
      return [];
    }
  }

  dynamic _decodeJson(String json) {
    // Simple recursive JSON decoder
    json = json.trim();

    if (json.startsWith('[')) {
      return _parseArray(json);
    } else if (json.startsWith('{')) {
      return _parseObject(json);
    } else if (json.startsWith('"')) {
      return json.substring(1, json.length - 1);
    } else if (json == 'true') {
      return true;
    } else if (json == 'false') {
      return false;
    } else if (json == 'null') {
      return null;
    } else {
      return num.tryParse(json) ?? json;
    }
  }

  List<dynamic> _parseArray(String json) {
    final result = <dynamic>[];
    var depth = 0;
    var start = 1;
    var inString = false;

    for (var i = 1; i < json.length - 1; i++) {
      final c = json[i];

      if (c == '"' && json[i - 1] != '\\') {
        inString = !inString;
      } else if (!inString) {
        if (c == '[' || c == '{') {
          depth++;
        } else if (c == ']' || c == '}') {
          depth--;
        } else if (c == ',' && depth == 0) {
          final item = json.substring(start, i).trim();
          if (item.isNotEmpty) {
            result.add(_decodeJson(item));
          }
          start = i + 1;
        }
      }
    }

    final lastItem = json.substring(start, json.length - 1).trim();
    if (lastItem.isNotEmpty) {
      result.add(_decodeJson(lastItem));
    }

    return result;
  }

  Map<String, dynamic> _parseObject(String json) {
    final result = <String, dynamic>{};
    var depth = 0;
    var start = 1;
    var inString = false;
    String? currentKey;

    for (var i = 1; i < json.length - 1; i++) {
      final c = json[i];

      if (c == '"' && json[i - 1] != '\\') {
        inString = !inString;
      } else if (!inString) {
        if (c == '[' || c == '{') {
          depth++;
        } else if (c == ']' || c == '}') {
          depth--;
        } else if (c == ':' && depth == 0 && currentKey == null) {
          currentKey = json.substring(start, i).trim();
          if (currentKey.startsWith('"')) {
            currentKey = currentKey.substring(1, currentKey.length - 1);
          }
          start = i + 1;
        } else if (c == ',' && depth == 0) {
          if (currentKey != null) {
            final value = json.substring(start, i).trim();
            result[currentKey] = _decodeJson(value);
          }
          currentKey = null;
          start = i + 1;
        }
      }
    }

    if (currentKey != null) {
      final value = json.substring(start, json.length - 1).trim();
      result[currentKey] = _decodeJson(value);
    }

    return result;
  }
}

class BleService_Service {
  final String uuid;
  final bool isPrimary;
  final List<BleService_Characteristic> characteristics;

  BleService_Service({
    required this.uuid,
    required this.isPrimary,
    required this.characteristics,
  });

  factory BleService_Service.fromJson(Map<String, dynamic> json) {
    return BleService_Service(
      uuid: json['uuid'] as String,
      isPrimary: json['isPrimary'] as bool? ?? true,
      characteristics: (json['characteristics'] as List<dynamic>?)
              ?.map((c) => BleService_Characteristic.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class BleService_Characteristic {
  final String uuid;
  final int properties;
  final bool isReadable;
  final bool isWritable;
  final bool isWritableNoResponse;
  final bool isNotifiable;
  final bool isIndicatable;
  final List<BleService_Descriptor> descriptors;

  BleService_Characteristic({
    required this.uuid,
    required this.properties,
    required this.isReadable,
    required this.isWritable,
    required this.isWritableNoResponse,
    required this.isNotifiable,
    required this.isIndicatable,
    required this.descriptors,
  });

  factory BleService_Characteristic.fromJson(Map<String, dynamic> json) {
    return BleService_Characteristic(
      uuid: json['uuid'] as String,
      properties: json['properties'] as int? ?? 0,
      isReadable: json['isReadable'] as bool? ?? false,
      isWritable: json['isWritable'] as bool? ?? false,
      isWritableNoResponse: json['isWritableNoResponse'] as bool? ?? false,
      isNotifiable: json['isNotifiable'] as bool? ?? false,
      isIndicatable: json['isIndicatable'] as bool? ?? false,
      descriptors: (json['descriptors'] as List<dynamic>?)
              ?.map((d) => BleService_Descriptor.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class BleService_Descriptor {
  final String uuid;

  BleService_Descriptor({required this.uuid});

  factory BleService_Descriptor.fromJson(Map<String, dynamic> json) {
    return BleService_Descriptor(
      uuid: json['uuid'] as String,
    );
  }
}
