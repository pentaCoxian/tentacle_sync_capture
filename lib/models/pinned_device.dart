class PinnedDevice {
  final String id;
  final String? address;
  final String? namePattern;
  final List<String>? serviceUuids;
  final Map<int, List<int>>? manufacturerDataMarkers;
  final String? displayName;
  final DateTime pinnedAt;

  PinnedDevice({
    required this.id,
    this.address,
    this.namePattern,
    this.serviceUuids,
    this.manufacturerDataMarkers,
    this.displayName,
    required this.pinnedAt,
  });

  bool matches(Map<String, dynamic> scanResult) {
    // Check address match
    if (address != null && scanResult['address'] == address) {
      return true;
    }

    // Check name pattern match
    final deviceName = scanResult['name'] as String?;
    if (namePattern != null && deviceName != null) {
      if (namePattern!.contains('*')) {
        final regex = RegExp(namePattern!.replaceAll('*', '.*'), caseSensitive: false);
        if (regex.hasMatch(deviceName)) {
          return true;
        }
      } else if (deviceName.toLowerCase().contains(namePattern!.toLowerCase())) {
        return true;
      }
    }

    // Check service UUID match
    final deviceServiceUuids = scanResult['serviceUuids'] as List<dynamic>?;
    if (serviceUuids != null && deviceServiceUuids != null) {
      for (final uuid in serviceUuids!) {
        if (deviceServiceUuids.any((u) => u.toString().toLowerCase() == uuid.toLowerCase())) {
          return true;
        }
      }
    }

    // Check manufacturer data markers
    final deviceManufacturerData = scanResult['manufacturerData'] as Map<dynamic, dynamic>?;
    if (manufacturerDataMarkers != null && deviceManufacturerData != null) {
      for (final entry in manufacturerDataMarkers!.entries) {
        final manufacturerId = entry.key;
        final expectedBytes = entry.value;
        final actualData = deviceManufacturerData[manufacturerId.toString()];
        if (actualData != null) {
          // Check if expected bytes are a prefix of actual data
          final actualBytes = _decodeBase64(actualData as String);
          if (_bytesMatch(expectedBytes, actualBytes)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  bool _bytesMatch(List<int> expected, List<int> actual) {
    if (expected.length > actual.length) return false;
    for (int i = 0; i < expected.length; i++) {
      if (expected[i] != actual[i]) return false;
    }
    return true;
  }

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'address': address,
      'namePattern': namePattern,
      'serviceUuids': serviceUuids,
      'manufacturerDataMarkers': manufacturerDataMarkers?.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'displayName': displayName,
      'pinnedAt': pinnedAt.toIso8601String(),
    };
  }

  factory PinnedDevice.fromJson(Map<String, dynamic> json) {
    Map<int, List<int>>? markers;
    final markersJson = json['manufacturerDataMarkers'];
    if (markersJson != null) {
      markers = {};
      (markersJson as Map<String, dynamic>).forEach((key, value) {
        markers![int.parse(key)] = (value as List<dynamic>).cast<int>();
      });
    }

    return PinnedDevice(
      id: json['id'] as String,
      address: json['address'] as String?,
      namePattern: json['namePattern'] as String?,
      serviceUuids: (json['serviceUuids'] as List<dynamic>?)?.cast<String>(),
      manufacturerDataMarkers: markers,
      displayName: json['displayName'] as String?,
      pinnedAt: DateTime.parse(json['pinnedAt'] as String),
    );
  }

  factory PinnedDevice.fromScanResult({
    required String id,
    required Map<String, dynamic> scanResult,
    String? displayName,
  }) {
    return PinnedDevice(
      id: id,
      address: scanResult['address'] as String?,
      namePattern: scanResult['name'] as String?,
      serviceUuids: (scanResult['serviceUuids'] as List<dynamic>?)?.cast<String>(),
      displayName: displayName ?? scanResult['name'] as String? ?? scanResult['address'] as String?,
      pinnedAt: DateTime.now(),
    );
  }

  PinnedDevice copyWith({
    String? id,
    String? address,
    String? namePattern,
    List<String>? serviceUuids,
    Map<int, List<int>>? manufacturerDataMarkers,
    String? displayName,
    DateTime? pinnedAt,
  }) {
    return PinnedDevice(
      id: id ?? this.id,
      address: address ?? this.address,
      namePattern: namePattern ?? this.namePattern,
      serviceUuids: serviceUuids ?? this.serviceUuids,
      manufacturerDataMarkers: manufacturerDataMarkers ?? this.manufacturerDataMarkers,
      displayName: displayName ?? this.displayName,
      pinnedAt: pinnedAt ?? this.pinnedAt,
    );
  }
}
