import 'dart:typed_data';

enum CaptureSource {
  adv,
  gattNotify,
  gattRead,
  gattWrite,
}

class CaptureEvent {
  final String id;
  final String sessionId;
  final CaptureSource source;
  final int tsMonotonicNanos;
  final int tsWallMillis;
  final String? deviceAddress;
  final String? deviceName;
  final int? rssi;
  final Uint8List payload;
  final Map<String, dynamic> meta;

  CaptureEvent({
    required this.id,
    required this.sessionId,
    required this.source,
    required this.tsMonotonicNanos,
    required this.tsWallMillis,
    this.deviceAddress,
    this.deviceName,
    this.rssi,
    required this.payload,
    Map<String, dynamic>? meta,
  }) : meta = meta ?? {};

  factory CaptureEvent.fromScanResult({
    required String id,
    required String sessionId,
    required Map<String, dynamic> scanResult,
  }) {
    final payloadBase64 = scanResult['payloadBase64'] as String?;
    final payload = payloadBase64 != null
        ? Uint8List.fromList(_decodeBase64(payloadBase64))
        : Uint8List(0);

    // Convert manufacturerData keys to strings for JSON compatibility
    // Platform channel may send Map<int, String> which jsonEncode doesn't support
    final rawManufacturerData = scanResult['manufacturerData'];
    final manufacturerData = <String, dynamic>{};
    if (rawManufacturerData is Map) {
      rawManufacturerData.forEach((key, value) {
        manufacturerData[key.toString()] = value;
      });
    }

    // Convert serviceData keys to strings for JSON compatibility
    final rawServiceData = scanResult['serviceData'];
    final serviceData = <String, dynamic>{};
    if (rawServiceData is Map) {
      rawServiceData.forEach((key, value) {
        serviceData[key.toString()] = value;
      });
    }

    return CaptureEvent(
      id: id,
      sessionId: sessionId,
      source: CaptureSource.adv,
      tsMonotonicNanos: scanResult['timestampNanos'] as int? ?? 0,
      tsWallMillis: scanResult['timestampMillis'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      deviceAddress: scanResult['address'] as String?,
      deviceName: scanResult['name'] as String?,
      rssi: scanResult['rssi'] as int?,
      payload: payload,
      meta: {
        'serviceUuids': scanResult['serviceUuids'] ?? [],
        'manufacturerData': manufacturerData,
        'serviceData': serviceData,
        'txPowerLevel': scanResult['txPowerLevel'],
        'isConnectable': scanResult['isConnectable'],
      },
    );
  }

  factory CaptureEvent.fromGattEvent({
    required String id,
    required String sessionId,
    required Map<String, dynamic> gattEvent,
  }) {
    final operation = gattEvent['operation'] as String? ?? 'notify';
    final source = switch (operation) {
      'read' => CaptureSource.gattRead,
      'write' => CaptureSource.gattWrite,
      _ => CaptureSource.gattNotify,
    };

    final valueBase64 = gattEvent['valueBase64'] as String?;
    final payload = valueBase64 != null
        ? Uint8List.fromList(_decodeBase64(valueBase64))
        : Uint8List(0);

    return CaptureEvent(
      id: id,
      sessionId: sessionId,
      source: source,
      tsMonotonicNanos: gattEvent['timestampNanos'] as int? ?? 0,
      tsWallMillis: gattEvent['timestampMillis'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      deviceAddress: gattEvent['address'] as String?,
      deviceName: null,
      rssi: null,
      payload: payload,
      meta: {
        'serviceUuid': gattEvent['serviceUuid'],
        'characteristicUuid': gattEvent['characteristicUuid'],
        'status': gattEvent['status'],
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'source': source.name,
      'tsMonotonicNanos': tsMonotonicNanos,
      'tsWallMillis': tsWallMillis,
      'deviceAddress': deviceAddress,
      'deviceName': deviceName,
      'rssi': rssi,
      'payloadBase64': _encodeBase64(payload),
      'meta': meta,
    };
  }

  factory CaptureEvent.fromJson(Map<String, dynamic> json) {
    final sourceStr = json['source'] as String? ?? 'adv';
    final source = CaptureSource.values.firstWhere(
      (s) => s.name == sourceStr,
      orElse: () => CaptureSource.adv,
    );

    final payloadBase64 = json['payloadBase64'] as String?;
    final payload = payloadBase64 != null
        ? Uint8List.fromList(_decodeBase64(payloadBase64))
        : Uint8List(0);

    return CaptureEvent(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      source: source,
      tsMonotonicNanos: json['tsMonotonicNanos'] as int? ?? 0,
      tsWallMillis: json['tsWallMillis'] as int? ?? 0,
      deviceAddress: json['deviceAddress'] as String?,
      deviceName: json['deviceName'] as String?,
      rssi: json['rssi'] as int?,
      payload: payload,
      meta: (json['meta'] as Map<String, dynamic>?) ?? {},
    );
  }

  String get payloadHex {
    return payload.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }

  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch(tsWallMillis);

  static List<int> _decodeBase64(String base64) {
    const lookup = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final input = base64.replaceAll(RegExp(r'[^A-Za-z0-9+/]'), '');
    final output = <int>[];

    for (int i = 0; i < input.length; i += 4) {
      final chunk = input.substring(i, i + 4 > input.length ? input.length : i + 4);
      if (chunk.length < 2) break;

      final a = lookup.indexOf(chunk[0]);
      final b = lookup.indexOf(chunk[1]);
      final c = chunk.length > 2 ? lookup.indexOf(chunk[2]) : 0;
      final d = chunk.length > 3 ? lookup.indexOf(chunk[3]) : 0;

      output.add((a << 2) | (b >> 4));
      if (chunk.length > 2 && chunk[2] != '=') {
        output.add(((b & 0x0F) << 4) | (c >> 2));
      }
      if (chunk.length > 3 && chunk[3] != '=') {
        output.add(((c & 0x03) << 6) | d);
      }
    }

    return output;
  }

  static String _encodeBase64(Uint8List bytes) {
    const lookup = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final output = StringBuffer();

    for (int i = 0; i < bytes.length; i += 3) {
      final remaining = bytes.length - i;
      final a = bytes[i];
      final b = remaining > 1 ? bytes[i + 1] : 0;
      final c = remaining > 2 ? bytes[i + 2] : 0;

      output.write(lookup[a >> 2]);
      output.write(lookup[((a & 0x03) << 4) | (b >> 4)]);
      output.write(remaining > 1 ? lookup[((b & 0x0F) << 2) | (c >> 6)] : '=');
      output.write(remaining > 2 ? lookup[c & 0x3F] : '=');
    }

    return output.toString();
  }
}
