import 'dart:typed_data';

/// BLE Advertisement Data Structure Parser
/// Parses the raw advertisement data into structured AD elements
class AdStructureParser {
  /// Parse raw advertisement bytes into a list of AD structures
  static List<AdStructure> parse(Uint8List data) {
    final structures = <AdStructure>[];
    int offset = 0;

    while (offset < data.length) {
      // Get the length byte
      final length = data[offset];
      if (length == 0) {
        // Zero length indicates end of significant data
        break;
      }

      // Check if we have enough data
      if (offset + length >= data.length) {
        break;
      }

      // Get the type byte
      final type = data[offset + 1];

      // Get the value bytes (length includes the type byte)
      final valueLength = length - 1;
      final value = valueLength > 0
          ? Uint8List.sublistView(data, offset + 2, offset + 1 + length)
          : Uint8List(0);

      structures.add(AdStructure(
        type: type,
        typeName: _getTypeName(type),
        value: value,
        offset: offset,
        length: length + 1, // Include the length byte itself
      ));

      offset += length + 1;
    }

    return structures;
  }

  /// Get human-readable name for AD type
  static String _getTypeName(int type) {
    return switch (type) {
      0x01 => 'Flags',
      0x02 => 'Incomplete 16-bit UUIDs',
      0x03 => 'Complete 16-bit UUIDs',
      0x04 => 'Incomplete 32-bit UUIDs',
      0x05 => 'Complete 32-bit UUIDs',
      0x06 => 'Incomplete 128-bit UUIDs',
      0x07 => 'Complete 128-bit UUIDs',
      0x08 => 'Shortened Local Name',
      0x09 => 'Complete Local Name',
      0x0A => 'Tx Power Level',
      0x0D => 'Class of Device',
      0x0E => 'Simple Pairing Hash C',
      0x0F => 'Simple Pairing Randomizer R',
      0x10 => 'Device ID / Security Manager TK',
      0x11 => 'Security Manager OOB Flags',
      0x12 => 'Peripheral Connection Interval Range',
      0x14 => 'Service Solicitation 16-bit UUIDs',
      0x15 => 'Service Solicitation 128-bit UUIDs',
      0x16 => 'Service Data - 16-bit UUID',
      0x17 => 'Public Target Address',
      0x18 => 'Random Target Address',
      0x19 => 'Appearance',
      0x1A => 'Advertising Interval',
      0x1B => 'LE Bluetooth Device Address',
      0x1C => 'LE Role',
      0x1D => 'Simple Pairing Hash C-256',
      0x1E => 'Simple Pairing Randomizer R-256',
      0x1F => 'Service Solicitation 32-bit UUIDs',
      0x20 => 'Service Data - 32-bit UUID',
      0x21 => 'Service Data - 128-bit UUID',
      0x22 => 'LE Secure Connections Confirmation',
      0x23 => 'LE Secure Connections Random',
      0x24 => 'URI',
      0x25 => 'Indoor Positioning',
      0x26 => 'Transport Discovery Data',
      0x27 => 'LE Supported Features',
      0x28 => 'Channel Map Update Indication',
      0x29 => 'PB-ADV',
      0x2A => 'Mesh Message',
      0x2B => 'Mesh Beacon',
      0x2C => 'BIGInfo',
      0x2D => 'Broadcast_Code',
      0x3D => '3D Information Data',
      0xFF => 'Manufacturer Specific Data',
      _ => 'Unknown (0x${type.toRadixString(16).padLeft(2, '0').toUpperCase()})',
    };
  }

  /// Parse flags byte
  static List<String> parseFlags(int flags) {
    final result = <String>[];
    if (flags & 0x01 != 0) result.add('LE Limited Discoverable');
    if (flags & 0x02 != 0) result.add('LE General Discoverable');
    if (flags & 0x04 != 0) result.add('BR/EDR Not Supported');
    if (flags & 0x08 != 0) result.add('LE + BR/EDR Controller');
    if (flags & 0x10 != 0) result.add('LE + BR/EDR Host');
    return result;
  }

  /// Parse 16-bit UUIDs from value
  static List<String> parse16BitUuids(Uint8List value) {
    final uuids = <String>[];
    for (int i = 0; i + 1 < value.length; i += 2) {
      final uuid = (value[i + 1] << 8) | value[i];
      uuids.add('0000${uuid.toRadixString(16).padLeft(4, '0')}-0000-1000-8000-00805f9b34fb');
    }
    return uuids;
  }

  /// Parse 128-bit UUIDs from value
  static List<String> parse128BitUuids(Uint8List value) {
    final uuids = <String>[];
    for (int i = 0; i + 15 < value.length; i += 16) {
      final bytes = value.sublist(i, i + 16);
      // UUID is stored in little-endian format
      final uuid = StringBuffer();
      for (int j = 15; j >= 0; j--) {
        uuid.write(bytes[j].toRadixString(16).padLeft(2, '0'));
        if (j == 12 || j == 10 || j == 8 || j == 6) {
          uuid.write('-');
        }
      }
      uuids.add(uuid.toString());
    }
    return uuids;
  }

  /// Parse manufacturer specific data
  static ManufacturerData? parseManufacturerData(Uint8List value) {
    if (value.length < 2) return null;
    final companyId = (value[1] << 8) | value[0];
    final data = value.length > 2 ? value.sublist(2) : Uint8List(0);
    return ManufacturerData(
      companyId: companyId,
      companyName: _getCompanyName(companyId),
      data: data,
    );
  }

  /// Parse service data (16-bit UUID)
  static ServiceData? parseServiceData16(Uint8List value) {
    if (value.length < 2) return null;
    final uuid = (value[1] << 8) | value[0];
    final fullUuid = '0000${uuid.toRadixString(16).padLeft(4, '0')}-0000-1000-8000-00805f9b34fb';
    final data = value.length > 2 ? value.sublist(2) : Uint8List(0);
    return ServiceData(uuid: fullUuid, data: data);
  }

  /// Get company name from Bluetooth Company ID
  static String _getCompanyName(int companyId) {
    return switch (companyId) {
      0x0000 => 'Ericsson Technology Licensing',
      0x0001 => 'Nokia Mobile Phones',
      0x0002 => 'Intel Corp.',
      0x0003 => 'IBM Corp.',
      0x0004 => 'Toshiba Corp.',
      0x0005 => '3Com',
      0x0006 => 'Microsoft',
      0x004C => 'Apple, Inc.',
      0x0059 => 'Nordic Semiconductor ASA',
      0x00E0 => 'Google',
      0x0075 => 'Samsung Electronics',
      0x00D2 => 'Sennheiser Communications',
      0x0157 => 'Huawei Technologies',
      0x02E5 => 'Tentacle Sync GmbH',
      _ => 'Unknown (0x${companyId.toRadixString(16).padLeft(4, '0').toUpperCase()})',
    };
  }
}

/// Represents a single AD structure element
class AdStructure {
  final int type;
  final String typeName;
  final Uint8List value;
  final int offset;
  final int length;

  AdStructure({
    required this.type,
    required this.typeName,
    required this.value,
    required this.offset,
    required this.length,
  });

  String get valueHex {
    return value.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }

  String get valueAscii {
    return String.fromCharCodes(value.where((b) => b >= 32 && b < 127));
  }

  /// Get a parsed representation of the value based on type
  dynamic get parsedValue {
    switch (type) {
      case 0x01: // Flags
        return value.isNotEmpty ? AdStructureParser.parseFlags(value[0]) : [];
      case 0x02:
      case 0x03: // 16-bit UUIDs
        return AdStructureParser.parse16BitUuids(value);
      case 0x06:
      case 0x07: // 128-bit UUIDs
        return AdStructureParser.parse128BitUuids(value);
      case 0x08:
      case 0x09: // Local Name
        return valueAscii;
      case 0x0A: // Tx Power Level
        return value.isNotEmpty ? value[0].toSigned(8) : null;
      case 0x16: // Service Data - 16-bit UUID
        return AdStructureParser.parseServiceData16(value);
      case 0xFF: // Manufacturer Specific Data
        return AdStructureParser.parseManufacturerData(value);
      default:
        return valueHex;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'typeName': typeName,
      'valueHex': valueHex,
      'parsedValue': _serializeParsedValue(parsedValue),
      'offset': offset,
      'length': length,
    };
  }

  dynamic _serializeParsedValue(dynamic value) {
    if (value is ManufacturerData) {
      return value.toJson();
    } else if (value is ServiceData) {
      return value.toJson();
    } else {
      return value;
    }
  }
}

/// Manufacturer specific data
class ManufacturerData {
  final int companyId;
  final String companyName;
  final Uint8List data;

  ManufacturerData({
    required this.companyId,
    required this.companyName,
    required this.data,
  });

  String get dataHex {
    return data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }

  Map<String, dynamic> toJson() {
    return {
      'companyId': companyId,
      'companyName': companyName,
      'dataHex': dataHex,
    };
  }
}

/// Service data
class ServiceData {
  final String uuid;
  final Uint8List data;

  ServiceData({
    required this.uuid,
    required this.data,
  });

  String get dataHex {
    return data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'dataHex': dataHex,
    };
  }
}
