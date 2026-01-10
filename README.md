# Tentacle Sync Capture

A Flutter Android application for capturing, analyzing, and decoding BLE timecode packets from Tentacle Sync devices. This tool is designed for reverse engineering and understanding the timecode broadcast protocol used by Tentacle Sync hardware.

## Features

### BLE Scanning & Device Discovery
- Scan for nearby BLE devices with configurable scan modes (Low Power, Balanced, Low Latency)
- Filter devices by name pattern (e.g., "Tentacle")
- View real-time RSSI signal strength
- Pin devices for persistent tracking across address rotations
- Start/stop capture sessions with automatic event logging

### Live Timecode Monitoring
- Large, responsive timecode display (HH:MM:SS:FF format)
- **Raw Mode**: Display timecode exactly as decoded from packets
- **Interpolated Mode**: Smooth timecode display that advances at frame rate between packets
  - Automatic frame rate detection
  - Filters out invalid packets (out-of-range values, unreasonable time jumps)
  - Visual feedback showing filtered packet count
- Real-time packet rate and FPS indicators
- Confidence scoring for decode accuracy

### Packet Inspector
- Raw hex viewer with byte highlighting
- Parsed AD structure tree view showing:
  - Flags
  - Complete/Shortened Local Name
  - Service UUIDs (16-bit, 32-bit, 128-bit)
  - Manufacturer Specific Data
  - Service Data
  - TX Power Level
- Multiple timecode decode hypotheses with confidence scores
- Filter out zero timecode (00:00:00:00) hypotheses
- "Open in Monitor" to track specific decode in live view

### GATT Browser
- Connect to devices and discover services
- Browse service hierarchy with characteristics and descriptors
- View characteristic properties (Read, Write, Notify, Indicate)
- Subscribe to notifications for real-time GATT data capture
- Monitor-only mode (no writes) for safe exploration

### Session Management
- Automatic session recording with metadata:
  - Device model, Android version, app version
  - Scan settings and timestamps
  - Custom labels and notes
- Browse session history with event counts
- Export sessions as JSONL ZIP archives
- Session diff tool for comparing captures

## Architecture

```
lib/
├── main.dart                    # App entry, navigation, global state
├── database/
│   └── database.dart            # Drift ORM database definition
├── decoders/
│   ├── ad_structure_parser.dart # BLE advertisement TLV parsing
│   ├── hypothesis_decoder.dart  # Multi-strategy timecode interpretation
│   └── timecode_decoder.dart    # Core timecode data structures
├── services/
│   ├── ble_service.dart         # Platform channel wrapper for BLE
│   ├── session_manager.dart     # Capture session lifecycle
│   └── export_service.dart      # JSONL/ZIP export functionality
├── models/
│   ├── capture_event.dart       # Individual packet event
│   ├── capture_session.dart     # Session metadata
│   └── pinned_device.dart       # Persistent device tracking
└── ui/
    ├── screens/
    │   ├── scan_screen.dart           # Device discovery
    │   ├── live_monitor_screen.dart   # Real-time timecode display
    │   ├── packet_inspector_screen.dart # Hex & decode analysis
    │   ├── sessions_screen.dart       # History browser
    │   ├── session_detail_screen.dart # Session events view
    │   ├── session_diff_screen.dart   # Compare sessions
    │   └── gatt_browser_screen.dart   # GATT exploration
    └── widgets/
        ├── device_tile.dart      # Scan result list item
        ├── hex_viewer.dart       # Raw byte display
        └── timecode_display.dart # Formatted TC widget
```

### Native Android (Kotlin)

```
android/app/src/main/kotlin/.../
├── MainActivity.kt
└── ble/
    ├── BlePlugin.kt              # Flutter platform channel registration
    ├── BleScanner.kt             # Android BLE scanning implementation
    ├── GattManager.kt            # GATT connection & characteristic handling
    └── ForegroundCaptureService.kt # Background capture notification
```

## Timecode Decoding

The hypothesis decoder implements multiple interpretation strategies:

| Strategy | Description |
|----------|-------------|
| BCD Nibble | Binary-coded decimal, common in timecode hardware |
| LE 32-bit Frame Counter | Little-endian total frame count |
| BE 32-bit Frame Counter | Big-endian total frame count |
| Direct Byte Mapping | HH:MM:SS:FF as sequential bytes |
| Frames Since Midnight | Single counter divided by FPS |

Each hypothesis is scored based on:
- **Monotonic increase** at expected FPS (23.976, 24, 25, 29.97, 30)
- **Rollover patterns** (frames→seconds, seconds→minutes, etc.)
- **Value range validity** (hours 0-23, minutes 0-59, etc.)
- **Consistency** across multiple packets

## Installation

### Prerequisites
- Flutter SDK 3.x
- Android SDK with API level 21+ (minSdk) and 34 (targetSdk)
- Android device with BLE support

### Build & Run

```bash
# Clone the repository
cd /path/to/tentacle_sync_capture

# Get dependencies
flutter pub get

# Generate database code
dart run build_runner build

# Run on connected device
flutter run

# Build release APK
flutter build apk --release
```

### Permissions

The app requires the following Android permissions:
- `BLUETOOTH_SCAN` - Discover nearby BLE devices
- `BLUETOOTH_CONNECT` - Connect to GATT services
- `ACCESS_FINE_LOCATION` - Required for BLE scanning on Android
- `FOREGROUND_SERVICE` - Background capture capability
- `FOREGROUND_SERVICE_CONNECTED_DEVICE` - Maintain BLE connection in background

## Usage

### Quick Start

1. **Launch the app** and grant Bluetooth/Location permissions
2. **Scan tab**: Tap "Start Scan" to discover devices
3. **Filter**: Enter "Tentacle" in the filter field to find Tentacle Sync devices
4. **Pin**: Long-press a device to pin it for tracking
5. **Capture**: Tap "Start Session" to begin recording packets
6. **Inspect**: Tap a device tile to open the Packet Inspector
7. **Monitor**: Use "Open in Monitor" to track timecode in real-time

### Display Modes

In the Monitor tab:
- **Raw**: Shows timecode only when packets arrive (may appear jumpy)
- **Smooth (Interpolated)**: Advances timecode at detected frame rate between packets
  - Automatically filters invalid packets
  - Shows filtered count with orange indicator when packets are rejected

### Analyzing Packets

The Packet Inspector shows:
1. **Hex View**: Raw bytes with offset, hex values, and ASCII representation
2. **AD Structures**: Parsed BLE advertisement fields in tree format
3. **Timecode Tab**: Multiple decode interpretations ranked by confidence
   - Toggle "Show All" to include zero timecode hypotheses
   - Tap a hypothesis to open it in the live monitor

## Database Schema

| Table | Purpose |
|-------|---------|
| `sessions` | Capture session metadata (id, timestamps, device info, labels) |
| `capture_events` | Individual packets (session_id, source, timestamp, payload, meta) |
| `pinned_devices` | User-pinned devices for persistent tracking |

Events are stored with:
- Monotonic timestamp (nanos) for ordering
- Wall-clock timestamp (millis) for display
- Source type: `ADV`, `GATT_NOTIFY`, `GATT_READ`
- Raw payload as binary blob
- Metadata JSON (RSSI, characteristic UUID, etc.)

## Dependencies

```yaml
dependencies:
  drift: ^2.14.0           # SQLite ORM
  sqlite3_flutter_libs     # Native SQLite bindings
  path_provider            # App directories
  permission_handler       # Runtime permissions
  provider                 # State management
  intl                     # Date/time formatting
  uuid                     # Session ID generation
  archive                  # ZIP export
  share_plus               # Share sheet integration
  device_info_plus         # Device metadata
  package_info_plus        # App version info

dev_dependencies:
  drift_dev                # Database code generation
  build_runner             # Code generation runner
```

## Export Format

Sessions export as ZIP archives containing:

```
session_<uuid>.zip
├── session.json          # Session metadata
└── events.jsonl          # One event per line
```

Event JSONL format:
```json
{"id":"...","sessionId":"...","source":"ADV","tsMonotonicNanos":123456789,"tsWallMillis":1234567890123,"deviceAddress":"AA:BB:CC:DD:EE:FF","rssi":-65,"payload":"base64...","meta":{}}
```

## Development Notes

### Adding New Decode Strategies

1. Add strategy to `HypothesisDecoder._generateHypotheses()`
2. Implement decode logic returning `Timecode` object
3. Add scoring criteria in `_scoreHypothesis()`
4. Test with known packet captures

### Platform Channel Protocol

The Dart/Kotlin bridge uses:
- `MethodChannel` for request/response (start scan, connect, etc.)
- `EventChannel` for streams (scan results, GATT notifications)

Events are serialized as `Map<String, dynamic>` with keys:
- `type`: Event type (scan_result, gatt_notification, etc.)
- `address`: Device MAC address
- `name`: Device name (if available)
- `rssi`: Signal strength
- `payload`: Base64-encoded bytes or byte list
- `timestampNanos`: System monotonic time

## License

This project is intended for research and reverse engineering purposes. Use responsibly and in accordance with applicable laws and regulations.

## Acknowledgments

- Built for analyzing Tentacle Sync timecode broadcast protocol
- Uses the Drift database library for robust local storage
- Implements BLE best practices for Android 12+ compatibility
