import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../database/database.dart';
import '../../decoders/hypothesis_decoder.dart';
import '../../decoders/timecode_decoder.dart';
import '../../main.dart';
import '../../models/capture_event.dart' as models;
import '../../models/pinned_device.dart' as models;
import '../../services/ble_service.dart';
import '../../services/session_manager.dart';
import '../widgets/timecode_display.dart';

typedef CaptureEvent = models.CaptureEvent;
typedef PinnedDevice = models.PinnedDevice;

/// Configuration for direct timecode monitoring from a device
class TimecodeMonitorConfig {
  final String deviceAddress;
  final String? deviceName;
  final int byteOffset;
  final int byteLength;
  final DecodeStrategy strategy;
  final double? inferredFps;

  const TimecodeMonitorConfig({
    required this.deviceAddress,
    this.deviceName,
    required this.byteOffset,
    required this.byteLength,
    required this.strategy,
    this.inferredFps,
  });
}

class LiveMonitorScreen extends StatefulWidget {
  final TimecodeMonitorConfig? monitorConfig;

  const LiveMonitorScreen({
    super.key,
    this.monitorConfig,
  });

  @override
  State<LiveMonitorScreen> createState() => _LiveMonitorScreenState();
}

/// Display mode for timecode
enum TimecodeDisplayMode {
  raw,         // Show raw timecode from packets only
  interpolated // Smooth interpolation between packets
}

class _LiveMonitorScreenState extends State<LiveMonitorScreen> {
  final TimecodeDecoder _timecodeDecoder = TimecodeDecoder();
  TimecodeResult? _lastTimecodeResult;
  CaptureEvent? _lastEvent;
  int _packetRate = 0;
  int _lastRssi = -100;
  StreamSubscription<CaptureEvent>? _eventSubscription;
  StreamSubscription<SessionStats>? _statsSubscription;

  // Direct monitoring state
  StreamSubscription<Map<String, dynamic>>? _directScanSubscription;
  Timecode? _directTimecode;
  String _directRawBytes = '';
  int _directPacketCount = 0;
  DateTime _directPacketCountStart = DateTime.now();
  bool _isDirectMonitoring = false;

  // Display mode and interpolation state
  TimecodeDisplayMode _displayMode = TimecodeDisplayMode.raw;
  Timer? _interpolationTimer;
  Timecode? _lastRawTimecode;
  DateTime? _lastRawTimecodeTime;
  Timecode? _interpolatedTimecode;
  double _effectiveFps = 25.0; // Default FPS for interpolation
  int _filteredPacketCount = 0; // Count of packets filtered due to invalid jumps
  bool _lastPacketWasFiltered = false; // Whether the last packet was filtered

  List<PinnedDevice> _pinnedDevices = [];
  PinnedDevice? _selectedDevice;

  @override
  void initState() {
    super.initState();
    _loadPinnedDevices();

    // If we have a monitor config, start direct monitoring
    if (widget.monitorConfig != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startDirectMonitoring();
      });
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _statsSubscription?.cancel();
    _directScanSubscription?.cancel();
    _interpolationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPinnedDevices() async {
    final database = context.read<AppDatabase>();
    final devices = await database.getAllPinnedDevices();
    setState(() {
      _pinnedDevices = devices;
      if (devices.isNotEmpty && _selectedDevice == null) {
        _selectedDevice = devices.first;
      }
    });
  }

  void _startDirectMonitoring() {
    if (widget.monitorConfig == null) return;

    final bleService = context.read<BleService>();
    final config = widget.monitorConfig!;

    // Set effective FPS from config
    _effectiveFps = config.inferredFps ?? 25.0;

    setState(() {
      _isDirectMonitoring = true;
      _directPacketCount = 0;
      _directPacketCountStart = DateTime.now();
    });

    // Start interpolation timer if in interpolated mode
    _startInterpolationTimer();

    _directScanSubscription = bleService.scanStream.listen((scanResult) {
      if (!mounted) return;

      final address = scanResult['address'] as String?;
      if (address != config.deviceAddress) return;

      // Decode payload
      final payloadBase64 = scanResult['payloadBase64'] as String?;
      if (payloadBase64 == null) return;

      final payload = _decodeBase64(payloadBase64);
      final rssi = scanResult['rssi'] as int? ?? -100;

      // Update packet rate
      _directPacketCount++;
      final elapsed = DateTime.now().difference(_directPacketCountStart).inMilliseconds;
      if (elapsed >= 1000) {
        _packetRate = (_directPacketCount * 1000 / elapsed).round();
        _directPacketCount = 0;
        _directPacketCountStart = DateTime.now();
      }

      // Decode timecode at specified offset
      Timecode? decodedTimecode;
      String rawBytes = '';

      if (config.byteOffset + config.byteLength <= payload.length) {
        rawBytes = payload
            .sublist(config.byteOffset, config.byteOffset + config.byteLength)
            .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
            .join(' ');

        if (config.byteLength >= 4) {
          if (config.strategy == DecodeStrategy.directMapping) {
            final hh = payload[config.byteOffset];
            final mm = payload[config.byteOffset + 1];
            final ss = payload[config.byteOffset + 2];
            final ff = payload[config.byteOffset + 3];
            decodedTimecode = Timecode(hours: hh, minutes: mm, seconds: ss, frames: ff);
          } else if (config.strategy == DecodeStrategy.bcd) {
            final hh = _bcdToDec(payload[config.byteOffset]);
            final mm = _bcdToDec(payload[config.byteOffset + 1]);
            final ss = _bcdToDec(payload[config.byteOffset + 2]);
            final ff = _bcdToDec(payload[config.byteOffset + 3]);
            if (hh >= 0 && mm >= 0 && ss >= 0 && ff >= 0) {
              decodedTimecode = Timecode(hours: hh, minutes: mm, seconds: ss, frames: ff);
            }
          } else if (config.strategy == DecodeStrategy.le32FrameCounter) {
            final frameCount = payload[config.byteOffset] |
                (payload[config.byteOffset + 1] << 8) |
                (payload[config.byteOffset + 2] << 16) |
                (payload[config.byteOffset + 3] << 24);
            final fps = config.inferredFps ?? 24.0;
            decodedTimecode = _frameCountToTimecode(frameCount, fps);
          } else if (config.strategy == DecodeStrategy.be32FrameCounter) {
            final frameCount = (payload[config.byteOffset] << 24) |
                (payload[config.byteOffset + 1] << 16) |
                (payload[config.byteOffset + 2] << 8) |
                payload[config.byteOffset + 3];
            final fps = config.inferredFps ?? 24.0;
            decodedTimecode = _frameCountToTimecode(frameCount, fps);
          }
        }
      }

      if (!mounted) return;

      setState(() {
        if (decodedTimecode != null) {
          // Always update raw timecode (shown in raw mode)
          _directTimecode = decodedTimecode;

          // For interpolated mode, validate the timecode before syncing
          final isValid = _isValidTimecode(decodedTimecode);
          final isReasonable = _displayMode == TimecodeDisplayMode.interpolated
              ? _isReasonableJump(_lastRawTimecode, decodedTimecode)
              : true;

          if (isValid && isReasonable) {
            // Store raw timecode info for interpolation
            _lastRawTimecode = decodedTimecode;
            _lastRawTimecodeTime = DateTime.now();
            // Sync interpolated timecode to raw when we get a valid packet
            _interpolatedTimecode = decodedTimecode;
            _lastPacketWasFiltered = false;
          } else if (_displayMode == TimecodeDisplayMode.interpolated) {
            // Track filtered packets in interpolated mode
            _filteredPacketCount++;
            _lastPacketWasFiltered = true;
          }
          // If invalid or unreasonable jump in interpolated mode,
          // we skip syncing and let interpolation continue from last known good value
        }
        _lastRssi = rssi;
        _directRawBytes = rawBytes;
      });
    });
  }

  void _stopDirectMonitoring() {
    _directScanSubscription?.cancel();
    _directScanSubscription = null;
    _interpolationTimer?.cancel();
    _interpolationTimer = null;
    if (mounted) {
      setState(() {
        _isDirectMonitoring = false;
      });
    }
  }

  /// Start the interpolation timer for smooth timecode display
  void _startInterpolationTimer() {
    _interpolationTimer?.cancel();
    // Update at frame rate for smooth display
    final intervalMs = (1000 / _effectiveFps).round();
    _interpolationTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (!mounted || _displayMode != TimecodeDisplayMode.interpolated) return;
      if (_interpolatedTimecode == null) return;

      // Advance by one frame
      setState(() {
        _interpolatedTimecode = _advanceTimecode(_interpolatedTimecode!, 1);
      });
    });
  }

  /// Advance a timecode by the specified number of frames
  Timecode _advanceTimecode(Timecode tc, int frames) {
    final fps = _effectiveFps.round();
    int totalFrames = tc.hours * 3600 * fps +
        tc.minutes * 60 * fps +
        tc.seconds * fps +
        tc.frames +
        frames;

    // Handle wrap around at 24 hours
    final maxFrames = 24 * 3600 * fps;
    if (totalFrames >= maxFrames) {
      totalFrames = totalFrames % maxFrames;
    }

    final newFrames = totalFrames % fps;
    final totalSeconds = totalFrames ~/ fps;
    final newSeconds = totalSeconds % 60;
    final totalMinutes = totalSeconds ~/ 60;
    final newMinutes = totalMinutes % 60;
    final newHours = totalMinutes ~/ 60;

    return Timecode(
      hours: newHours % 24,
      minutes: newMinutes,
      seconds: newSeconds,
      frames: newFrames,
    );
  }

  /// Toggle display mode between raw and interpolated
  void _toggleDisplayMode() {
    setState(() {
      if (_displayMode == TimecodeDisplayMode.raw) {
        _displayMode = TimecodeDisplayMode.interpolated;
        // Sync interpolated to current raw timecode
        _interpolatedTimecode = _directTimecode;
        _startInterpolationTimer();
      } else {
        _displayMode = TimecodeDisplayMode.raw;
        _interpolationTimer?.cancel();
        _interpolationTimer = null;
      }
    });
  }

  /// Check if a timecode has valid ranges (hours 0-23, minutes 0-59, seconds 0-59, frames 0-fps)
  bool _isValidTimecode(Timecode tc) {
    final maxFrames = _effectiveFps.round();
    return tc.hours >= 0 && tc.hours <= 23 &&
           tc.minutes >= 0 && tc.minutes <= 59 &&
           tc.seconds >= 0 && tc.seconds <= 59 &&
           tc.frames >= 0 && tc.frames < maxFrames + 5; // Allow small tolerance for frame count
  }

  /// Convert timecode to total frames for comparison
  int _timecodeToTotalFrames(Timecode tc) {
    final fps = _effectiveFps.round();
    return tc.hours * 3600 * fps +
           tc.minutes * 60 * fps +
           tc.seconds * fps +
           tc.frames;
  }

  /// Check if a new timecode represents a reasonable jump from the previous one
  /// Returns true if the jump is acceptable (within ~2 seconds of expected value)
  bool _isReasonableJump(Timecode? previous, Timecode newTc) {
    if (previous == null) return true;

    final fps = _effectiveFps.round();
    final previousFrames = _timecodeToTotalFrames(previous);
    final newFrames = _timecodeToTotalFrames(newTc);

    // Calculate expected frames based on elapsed time since last raw packet
    final elapsed = _lastRawTimecodeTime != null
        ? DateTime.now().difference(_lastRawTimecodeTime!).inMilliseconds
        : 0;
    final expectedAdvance = (elapsed * fps / 1000).round();

    // The new timecode should be within a reasonable range of what we expect
    // Allow for some jitter: expected advance +/- 2 seconds worth of frames
    final tolerance = fps * 2; // 2 seconds tolerance

    // Handle wrap around at 24 hours
    final maxFrames = 24 * 3600 * fps;
    var expectedFrames = (previousFrames + expectedAdvance) % maxFrames;

    // Check forward direction (normal case)
    var diff = (newFrames - expectedFrames).abs();
    if (diff > maxFrames ~/ 2) {
      // Handle wrap-around
      diff = maxFrames - diff;
    }

    return diff <= tolerance;
  }

  Uint8List _decodeBase64(String base64) {
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

    return Uint8List.fromList(output);
  }

  int _bcdToDec(int bcd) {
    final high = (bcd >> 4) & 0x0F;
    final low = bcd & 0x0F;
    if (high > 9 || low > 9) return -1;
    return high * 10 + low;
  }

  Timecode? _frameCountToTimecode(int frameCount, double fps) {
    if (frameCount < 0) return null;

    final totalSeconds = frameCount / fps;
    final hours = (totalSeconds / 3600).floor();
    final minutes = ((totalSeconds % 3600) / 60).floor();
    final seconds = (totalSeconds % 60).floor();
    final frames = (frameCount % fps.round()).floor();

    return Timecode(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      frames: frames,
    );
  }

  void _subscribeToEvents() {
    final notifier = context.read<SessionManagerNotifier>();
    final sessionManager = notifier.sessionManager;

    _eventSubscription?.cancel();
    _eventSubscription = sessionManager.eventStream.listen((event) {
      _processEvent(event);
    });

    _statsSubscription?.cancel();
    _statsSubscription = sessionManager.statsStream.listen((stats) {
      setState(() {
        _packetRate = stats.eventsPerSecond;
      });
    });
  }

  void _processEvent(CaptureEvent event) {
    final previousTimestamp = _lastEvent?.tsWallMillis;
    final result = _timecodeDecoder.decode(
      event.payload,
      previousTimestampMillis: previousTimestamp,
      currentTimestampMillis: event.tsWallMillis,
    );

    setState(() {
      _lastEvent = event;
      _lastTimecodeResult = result;
      _lastRssi = event.rssi ?? -100;
    });
  }

  Future<void> _startCapture() async {
    final notifier = context.read<SessionManagerNotifier>();
    final sessionManager = notifier.sessionManager;

    await sessionManager.startSession(
      pinnedDevice: _selectedDevice,
    );

    _subscribeToEvents();
  }

  Future<void> _stopCapture() async {
    final notifier = context.read<SessionManagerNotifier>();
    final sessionManager = notifier.sessionManager;

    await sessionManager.stopSession();

    _eventSubscription?.cancel();
    _statsSubscription?.cancel();
  }

  Future<void> _addMarker() async {
    final notifier = context.read<SessionManagerNotifier>();
    final sessionManager = notifier.sessionManager;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => _MarkerDialog(),
    );

    if (result != null && result.isNotEmpty) {
      await sessionManager.addMarker(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marker added: $result')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we have a direct monitor config, show the direct monitoring UI
    if (widget.monitorConfig != null) {
      return _buildDirectMonitorUI();
    }

    // Otherwise show the original session-based UI
    return _buildSessionMonitorUI();
  }

  Widget _buildDirectMonitorUI() {
    final config = widget.monitorConfig!;
    // Choose timecode based on display mode
    final displayTimecode = _displayMode == TimecodeDisplayMode.interpolated
        ? _interpolatedTimecode
        : _directTimecode;
    final timecodeStr = displayTimecode?.toString() ?? '--:--:--:--';

    return Scaffold(
      appBar: AppBar(
        title: Text(config.deviceName ?? 'Live Monitor'),
        actions: [
          if (_isDirectMonitoring)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('LIVE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Device info bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const Icon(Icons.bluetooth, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    config.deviceAddress,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                  ),
                ),
                Text(
                  'Offset ${config.byteOffset}, ${config.byteLength} bytes',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          // Display mode toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<TimecodeDisplayMode>(
              segments: const [
                ButtonSegment(
                  value: TimecodeDisplayMode.raw,
                  label: Text('Raw'),
                  icon: Icon(Icons.raw_on, size: 18),
                ),
                ButtonSegment(
                  value: TimecodeDisplayMode.interpolated,
                  label: Text('Smooth'),
                  icon: Icon(Icons.auto_fix_high, size: 18),
                ),
              ],
              selected: {_displayMode},
              onSelectionChanged: (selected) {
                if (selected.isNotEmpty) {
                  setState(() {
                    _displayMode = selected.first;
                    if (_displayMode == TimecodeDisplayMode.interpolated) {
                      _interpolatedTimecode = _directTimecode;
                      _lastRawTimecode = _directTimecode;
                      _lastRawTimecodeTime = DateTime.now();
                      _filteredPacketCount = 0;
                      _lastPacketWasFiltered = false;
                      _startInterpolationTimer();
                    } else {
                      _interpolationTimer?.cancel();
                      _interpolationTimer = null;
                    }
                  });
                }
              },
            ),
          ),

          // Large timecode display
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Mode indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _displayMode == TimecodeDisplayMode.interpolated
                          ? Colors.blue.withAlpha(50)
                          : Colors.grey.withAlpha(50),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _displayMode == TimecodeDisplayMode.interpolated
                          ? 'INTERPOLATED'
                          : 'RAW PACKET',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _displayMode == TimecodeDisplayMode.interpolated
                            ? Colors.blue
                            : Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Timecode - use FittedBox to scale to fit screen width
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        timecodeStr,
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 72,
                              letterSpacing: 4,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Raw bytes (always shows raw packet data)
                  if (_directRawBytes.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _lastPacketWasFiltered && _displayMode == TimecodeDisplayMode.interpolated
                            ? Colors.orange.withAlpha(30)
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: _lastPacketWasFiltered && _displayMode == TimecodeDisplayMode.interpolated
                            ? Border.all(color: Colors.orange.withAlpha(100))
                            : null,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_lastPacketWasFiltered && _displayMode == TimecodeDisplayMode.interpolated)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(Icons.filter_alt, size: 14, color: Colors.orange),
                                ),
                              Text(
                                _directRawBytes,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontFamily: 'monospace',
                                      letterSpacing: 2,
                                      color: _lastPacketWasFiltered && _displayMode == TimecodeDisplayMode.interpolated
                                          ? Colors.orange
                                          : null,
                                    ),
                              ),
                            ],
                          ),
                          if (_displayMode == TimecodeDisplayMode.interpolated &&
                              _directTimecode != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _lastPacketWasFiltered
                                  ? 'Filtered: ${_directTimecode} (invalid jump)'
                                  : 'Last raw: ${_directTimecode}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                    color: _lastPacketWasFiltered
                                        ? Colors.orange
                                        : Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                          if (_filteredPacketCount > 0 && _displayMode == TimecodeDisplayMode.interpolated) ...[
                            const SizedBox(height: 4),
                            Text(
                              '$_filteredPacketCount packets filtered',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    color: Colors.orange.withAlpha(180),
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),

                  // Stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildInfoChip(
                        'Packets/s',
                        '$_packetRate',
                        Icons.stacked_line_chart,
                      ),
                      const SizedBox(width: 16),
                      _buildInfoChip(
                        'RSSI',
                        '$_lastRssi dB',
                        _getRssiIcon(_lastRssi),
                        color: _getRssiColor(_lastRssi),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (config.inferredFps != null)
                    _buildInfoChip(
                      'FPS',
                      '${config.inferredFps}',
                      Icons.speed,
                    ),
                ],
              ),
            ),
          ),

          // Stop button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isDirectMonitoring ? _stopDirectMonitoring : _startDirectMonitoring,
                    icon: Icon(_isDirectMonitoring ? Icons.stop : Icons.play_arrow),
                    label: Text(_isDirectMonitoring ? 'Stop Monitoring' : 'Start Monitoring'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: _isDirectMonitoring
                          ? Colors.red
                          : Theme.of(context).colorScheme.primary,
                      foregroundColor: _isDirectMonitoring
                          ? Colors.white
                          : Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionMonitorUI() {
    final notifier = context.watch<SessionManagerNotifier>();
    final sessionManager = notifier.sessionManager;
    final isCapturing = sessionManager.isCapturing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Monitor'),
        actions: [
          if (isCapturing)
            IconButton(
              icon: const Icon(Icons.bookmark_add),
              onPressed: _addMarker,
              tooltip: 'Add Marker',
            ),
        ],
      ),
      body: Column(
        children: [
          // Device selector
          if (!isCapturing && _pinnedDevices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<PinnedDevice>(
                value: _selectedDevice,
                decoration: const InputDecoration(
                  labelText: 'Select Device',
                  border: OutlineInputBorder(),
                ),
                items: _pinnedDevices
                    .map((device) => DropdownMenuItem(
                          value: device,
                          child: Text(device.displayName ?? device.address ?? 'Unknown'),
                        ))
                    .toList(),
                onChanged: (device) {
                  setState(() {
                    _selectedDevice = device;
                  });
                },
              ),
            ),

          // Timecode display
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TimecodeDisplay(
                    timecode: _lastTimecodeResult?.displayTimecode ?? '--:--:--:--',
                    confidence: _lastTimecodeResult?.confidence ?? 0,
                    isConfirmed: _lastTimecodeResult?.isConfirmed ?? false,
                  ),
                  const SizedBox(height: 32),
                  if (_lastTimecodeResult?.inferredFps != null)
                    _buildInfoChip(
                      'FPS',
                      '${_lastTimecodeResult!.inferredFps}',
                      Icons.speed,
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildInfoChip(
                        'Packets/s',
                        '$_packetRate',
                        Icons.stacked_line_chart,
                      ),
                      const SizedBox(width: 16),
                      _buildInfoChip(
                        'RSSI',
                        '$_lastRssi dB',
                        _getRssiIcon(_lastRssi),
                        color: _getRssiColor(_lastRssi),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  if (isCapturing && sessionManager.activeSession != null) ...[
                    Text(
                      '${sessionManager.eventCount} events captured',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Duration: ${_formatDuration(DateTime.now().difference(sessionManager.activeSession!.startedAt))}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Control buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isCapturing ? _stopCapture : _startCapture,
                    icon: Icon(isCapturing ? Icons.stop : Icons.play_arrow),
                    label: Text(isCapturing ? 'Stop Capture' : 'Start Capture'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor:
                          isCapturing ? Colors.red : Theme.of(context).colorScheme.primary,
                      foregroundColor:
                          isCapturing ? Colors.white : Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, IconData icon, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getRssiIcon(int rssi) {
    if (rssi >= -50) return Icons.signal_cellular_4_bar;
    if (rssi >= -70) return Icons.signal_cellular_alt;
    if (rssi >= -80) return Icons.signal_cellular_alt_2_bar;
    return Icons.signal_cellular_alt_1_bar;
  }

  Color _getRssiColor(int rssi) {
    if (rssi >= -50) return Colors.green;
    if (rssi >= -70) return Colors.lightGreen;
    if (rssi >= -80) return Colors.orange;
    return Colors.red;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class _MarkerDialog extends StatefulWidget {
  @override
  State<_MarkerDialog> createState() => _MarkerDialogState();
}

class _MarkerDialogState extends State<_MarkerDialog> {
  final _controller = TextEditingController();
  final _presets = [
    'FPS_24',
    'FPS_25',
    'FPS_29.97',
    'FPS_30',
    'SET_TC',
    'CHARGING_ON',
    'CHARGING_OFF',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Marker'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Marker text',
              hintText: 'e.g., FPS_25, SET_TC_01020304',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets
                .map((preset) => ActionChip(
                      label: Text(preset),
                      onPressed: () {
                        _controller.text = preset;
                      },
                    ))
                .toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
