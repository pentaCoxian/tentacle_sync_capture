import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../decoders/ad_structure_parser.dart';
import '../../decoders/hypothesis_decoder.dart';
import '../../main.dart';
import '../../services/ble_service.dart';
import '../widgets/hex_viewer.dart';
import 'live_monitor_screen.dart';

class PacketInspectorScreen extends StatefulWidget {
  final Map<String, dynamic> scanResult;
  final String deviceName;
  final BleService? bleService;

  const PacketInspectorScreen({
    super.key,
    required this.scanResult,
    required this.deviceName,
    this.bleService,
  });

  @override
  State<PacketInspectorScreen> createState() => _PacketInspectorScreenState();
}

class _PacketInspectorScreenState extends State<PacketInspectorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Uint8List _payload;
  late List<AdStructure> _adStructures;
  late List<TimecodeHypothesis> _hypotheses;

  // Live update state
  TimecodeHypothesis? _selectedHypothesis;
  StreamSubscription<Map<String, dynamic>>? _scanSubscription;
  Timecode? _liveTimecode;
  int _liveRssi = -100;
  int _packetsPerSecond = 0;
  int _packetCount = 0;
  DateTime _packetCountStart = DateTime.now();
  bool _isLiveUpdating = false;
  String _liveRawBytes = ''; // Raw bytes at selected offset for debugging
  int _livePayloadLength = 0;
  Uint8List? _livePayload; // Full live payload for hex viewer

  // Filter state for hypotheses
  bool _showAllHypotheses = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _parsePayload();
    _autoSelectTentacleHypothesis();
  }

  /// Check if this device has Tentacle Sync manufacturer ID
  bool _isTentacleSyncDevice() {
    // Tentacle Sync manufacturer ID is 0x0944 (2372 decimal)
    const tentacleManufacturerId = 2372;
    const tentacleManufacturerIdHex = '944'; // Without leading zero

    final manufacturerData = widget.scanResult['manufacturerData'];
    if (manufacturerData is Map) {
      for (final key in manufacturerData.keys) {
        final keyInt = key is int ? key : int.tryParse(key.toString());
        if (keyInt == tentacleManufacturerId) {
          return true;
        }
        // Also check string representation
        final keyStr = key.toString().toLowerCase();
        if (keyStr == tentacleManufacturerIdHex || keyStr == '0x$tentacleManufacturerIdHex') {
          return true;
        }
      }
    }
    return false;
  }

  /// Auto-select hypothesis at offset 14, length 4 for Tentacle Sync devices
  void _autoSelectTentacleHypothesis() {
    final isTentacle = _isTentacleSyncDevice();

    if (!isTentacle) return;

    // For Tentacle Sync devices, always use offset 14, length 4
    // Create a direct mapping hypothesis if none exists at that offset
    TimecodeHypothesis? targetHypothesis;

    // First try to find an existing hypothesis at offset 14
    for (final h in _hypotheses) {
      if (h.byteOffset == 14 && h.byteLength == 4) {
        targetHypothesis = h;
        break;
      }
    }

    // If no hypothesis exists at offset 14, create a direct mapping one
    if (targetHypothesis == null && _payload.length >= 18) {
      // Manually decode bytes at offset 14-17 as direct mapping
      final hh = _payload[14];
      final mm = _payload[15];
      final ss = _payload[16];
      final ff = _payload[17];

      targetHypothesis = TimecodeHypothesis(
        strategy: DecodeStrategy.directMapping,
        timecode: Timecode(
          hours: hh <= 23 ? hh : 0,
          minutes: mm <= 59 ? mm : 0,
          seconds: ss <= 59 ? ss : 0,
          frames: ff <= 60 ? ff : 0,
        ),
        byteOffset: 14,
        byteLength: 4,
        confidence: 100, // Force high confidence for Tentacle
        explanation: 'Tentacle Sync timecode at offset 14 (auto-detected)',
        inferredFps: 25.0, // Default to 25fps for Tentacle
      );

      // Add to hypotheses list
      _hypotheses.insert(0, targetHypothesis);
    }

    if (targetHypothesis != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectHypothesis(targetHypothesis!);
          // Switch to timecode tab
          _tabController.animateTo(2);
        }
      });
    }
  }

  void _parsePayload() {
    final payloadBase64 = widget.scanResult['payloadBase64'] as String?;
    if (payloadBase64 != null && payloadBase64.isNotEmpty) {
      _payload = _decodeBase64(payloadBase64);
    } else {
      _payload = Uint8List(0);
    }

    _adStructures = AdStructureParser.parse(_payload);

    final hypothesisDecoder = HypothesisDecoder();
    _hypotheses = hypothesisDecoder.decodeAll(_payload);
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

  @override
  void dispose() {
    // Cancel subscription directly without setState
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _tabController.dispose();
    super.dispose();
  }

  void _selectHypothesis(TimecodeHypothesis hypothesis) {
    setState(() {
      _selectedHypothesis = hypothesis;
      _liveTimecode = hypothesis.timecode;
    });

    if (widget.bleService != null) {
      _startLiveUpdates();
    }
  }

  void _startLiveUpdates() {
    if (_scanSubscription != null || widget.bleService == null) return;

    final deviceAddress = widget.scanResult['address'] as String?;
    if (deviceAddress == null) return;

    setState(() {
      _isLiveUpdating = true;
      _packetCount = 0;
      _packetCountStart = DateTime.now();
    });

    _scanSubscription = widget.bleService!.scanStream.listen((scanResult) {
      // Check if widget is still mounted before processing
      if (!mounted) return;

      final address = scanResult['address'] as String?;
      if (address != deviceAddress) return;

      // Decode the payload
      final payloadBase64 = scanResult['payloadBase64'] as String?;
      if (payloadBase64 == null) return;

      final payload = _decodeBase64(payloadBase64);
      final rssi = scanResult['rssi'] as int? ?? -100;

      // Apply the selected hypothesis decoder to extract timecode
      if (_selectedHypothesis != null) {
        final offset = _selectedHypothesis!.byteOffset;
        final length = _selectedHypothesis!.byteLength;

        // Update packet rate
        _packetCount++;
        final elapsed = DateTime.now().difference(_packetCountStart).inMilliseconds;
        if (elapsed >= 1000) {
          _packetsPerSecond = (_packetCount * 1000 / elapsed).round();
          _packetCount = 0;
          _packetCountStart = DateTime.now();
        }

        // Extract raw bytes at the selected offset for debugging
        String rawBytes = '';
        Timecode? decodedTimecode;

        if (offset + length <= payload.length) {
          rawBytes = payload
              .sublist(offset, offset + length)
              .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
              .join(' ');

          // Directly decode bytes at the selected offset based on strategy
          // This avoids relying on hypothesis matching which may fail validation
          if (length >= 4) {
            final strategy = _selectedHypothesis!.strategy;

            if (strategy == DecodeStrategy.directMapping) {
              // Direct byte mapping: each byte is hh, mm, ss, ff
              final hh = payload[offset];
              final mm = payload[offset + 1];
              final ss = payload[offset + 2];
              final ff = payload[offset + 3];
              decodedTimecode = Timecode(hours: hh, minutes: mm, seconds: ss, frames: ff);
            } else if (strategy == DecodeStrategy.bcd) {
              // BCD decode
              final hh = _bcdToDec(payload[offset]);
              final mm = _bcdToDec(payload[offset + 1]);
              final ss = _bcdToDec(payload[offset + 2]);
              final ff = _bcdToDec(payload[offset + 3]);
              if (hh >= 0 && mm >= 0 && ss >= 0 && ff >= 0) {
                decodedTimecode = Timecode(hours: hh, minutes: mm, seconds: ss, frames: ff);
              }
            } else if (strategy == DecodeStrategy.le32FrameCounter) {
              // Little-endian 32-bit frame counter
              final frameCount = payload[offset] |
                  (payload[offset + 1] << 8) |
                  (payload[offset + 2] << 16) |
                  (payload[offset + 3] << 24);
              final fps = _selectedHypothesis!.inferredFps ?? 24.0;
              decodedTimecode = _frameCountToTimecode(frameCount, fps);
            } else if (strategy == DecodeStrategy.be32FrameCounter) {
              // Big-endian 32-bit frame counter
              final frameCount = (payload[offset] << 24) |
                  (payload[offset + 1] << 16) |
                  (payload[offset + 2] << 8) |
                  payload[offset + 3];
              final fps = _selectedHypothesis!.inferredFps ?? 24.0;
              decodedTimecode = _frameCountToTimecode(frameCount, fps);
            }
          }
        } else {
          rawBytes = 'offset out of range (payload: ${payload.length} bytes)';
        }

        // Check mounted again before setState
        if (!mounted) return;

        setState(() {
          if (decodedTimecode != null) {
            _liveTimecode = decodedTimecode;
          }
          _liveRssi = rssi;
          _liveRawBytes = rawBytes;
          _livePayloadLength = payload.length;
          _livePayload = payload;
        });
      }
    });
  }

  void _stopLiveUpdates() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    if (mounted) {
      setState(() {
        _isLiveUpdating = false;
      });
    }
  }

  /// Convert BCD byte to decimal
  int _bcdToDec(int bcd) {
    final high = (bcd >> 4) & 0x0F;
    final low = bcd & 0x0F;
    if (high > 9 || low > 9) return -1;
    return high * 10 + low;
  }

  /// Convert frame count to timecode
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

  void _deselectHypothesis() {
    _stopLiveUpdates();
    setState(() {
      _selectedHypothesis = null;
      _liveTimecode = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceName),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Raw Hex'),
            Tab(text: 'AD Structures'),
            Tab(text: 'Timecode'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRawHexTab(),
          _buildAdStructuresTab(),
          _buildTimecodeTab(),
        ],
      ),
    );
  }

  Widget _buildRawHexTab() {
    // Use live payload if available, otherwise use initial payload
    final displayPayload = _livePayload ?? _payload;

    if (displayPayload.isEmpty) {
      return const Center(
        child: Text('No payload data'),
      );
    }

    // Highlight the selected hypothesis bytes
    Set<int>? highlightedBytes;
    if (_selectedHypothesis != null) {
      final offset = _selectedHypothesis!.byteOffset;
      final length = _selectedHypothesis!.byteLength;
      highlightedBytes = Set<int>.from(
        List.generate(length, (i) => offset + i),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Raw Payload (${displayPayload.length} bytes)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_isLiveUpdating)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Colors.white, size: 8),
                              SizedBox(width: 4),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  HexViewer(
                    data: displayPayload,
                    highlightedBytes: highlightedBytes,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    // Use live RSSI if available
    final rssi = _isLiveUpdating ? _liveRssi : (widget.scanResult['rssi'] as int? ?? -100);
    final txPower = widget.scanResult['txPowerLevel'] as int?;
    final isConnectable = widget.scanResult['isConnectable'] as bool? ?? true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Device Info',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_isLiveUpdating)
                  Text(
                    '$_packetsPerSecond pkt/s',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Address', widget.scanResult['address'] as String? ?? 'Unknown'),
            _buildInfoRow('RSSI', '$rssi dBm'),
            if (txPower != null && txPower != -2147483648)
              _buildInfoRow('TX Power', '$txPower dBm'),
            _buildInfoRow('Connectable', isConnectable ? 'Yes' : 'No'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdStructuresTab() {
    if (_adStructures.isEmpty) {
      return const Center(
        child: Text('No AD structures found'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _adStructures.length,
      itemBuilder: (context, index) {
        final structure = _adStructures[index];
        return _buildAdStructureCard(structure);
      },
    );
  }

  Widget _buildAdStructureCard(AdStructure structure) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(structure.typeName),
        subtitle: Text(
          'Type: 0x${structure.type.toRadixString(16).padLeft(2, '0').toUpperCase()} | ${structure.value.length} bytes',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '0x${structure.type.toRadixString(16).toUpperCase()}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Raw Value',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    structure.valueHex,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Parsed Value',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                _buildParsedValue(structure.parsedValue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParsedValue(dynamic value) {
    if (value == null) {
      return const Text('(null)');
    }

    if (value is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: value.map((item) => Text('- $item')).toList(),
      );
    }

    if (value is ManufacturerData) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Company: ${value.companyName} (0x${value.companyId.toRadixString(16).padLeft(4, '0')})'),
          const SizedBox(height: 4),
          Text('Data: ${value.dataHex}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ],
      );
    }

    if (value is ServiceData) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('UUID: ${value.uuid}'),
          const SizedBox(height: 4),
          Text('Data: ${value.dataHex}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ],
      );
    }

    return Text('$value');
  }

  /// Check if a timecode is all zeros (00:00:00:00)
  bool _isZeroTimecode(Timecode tc) {
    return tc.hours == 0 && tc.minutes == 0 && tc.seconds == 0 && tc.frames == 0;
  }

  /// Get filtered hypotheses based on show all setting
  List<TimecodeHypothesis> get _filteredHypotheses {
    if (_showAllHypotheses) {
      return _hypotheses;
    }
    // Filter out hypotheses with 00:00:00:00 timecode
    return _hypotheses.where((h) => !_isZeroTimecode(h.timecode)).toList();
  }

  /// Count of hidden hypotheses (those with 00:00:00:00)
  int get _hiddenHypothesesCount {
    return _hypotheses.where((h) => _isZeroTimecode(h.timecode)).length;
  }

  Widget _buildTimecodeTab() {
    if (_hypotheses.isEmpty) {
      return const Center(
        child: Text('No timecode hypotheses found'),
      );
    }

    final filtered = _filteredHypotheses;
    final hiddenCount = _hiddenHypothesesCount;

    return Column(
      children: [
        // Live timecode display when a hypothesis is selected
        if (_selectedHypothesis != null) _buildLiveTimecodeDisplay(),

        // Filter toggle bar
        if (hiddenCount > 0 || _showAllHypotheses)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  _showAllHypotheses ? Icons.visibility : Icons.visibility_off,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _showAllHypotheses
                        ? 'Showing all ${_hypotheses.length} hypotheses'
                        : 'Hiding $hiddenCount with 00:00:00:00',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAllHypotheses = !_showAllHypotheses;
                    });
                  },
                  icon: Icon(
                    _showAllHypotheses ? Icons.filter_list : Icons.filter_list_off,
                    size: 16,
                  ),
                  label: Text(_showAllHypotheses ? 'Hide Zeros' : 'Show All'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),

        // Hypothesis list
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.filter_list_off,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'All hypotheses show 00:00:00:00',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showAllHypotheses = true;
                          });
                        },
                        child: const Text('Show All'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final hypothesis = filtered[index];
                    // Compare both strategy AND offset to determine if this is the selected hypothesis
                    final isSelected = _selectedHypothesis != null &&
                        _selectedHypothesis!.strategy == hypothesis.strategy &&
                        _selectedHypothesis!.byteOffset == hypothesis.byteOffset;
                    // Check if this is the best in the filtered list
                    final isBest = index == 0;
                    return _buildTimecodeCard(hypothesis, isBest, isSelected);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLiveTimecodeDisplay() {
    final timecodeStr = _liveTimecode?.toString() ?? '--:--:--:--';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(50),
          ),
        ),
      ),
      child: Column(
        children: [
          // Live indicator and close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (_isLiveUpdating)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    _isLiveUpdating ? 'LIVE' : 'SELECT TO GO LIVE',
                    style: TextStyle(
                      color: _isLiveUpdating ? Colors.green : Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    _selectedHypothesis?.strategyName ?? '',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _deselectHypothesis,
                    tooltip: 'Stop live updates',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Large timecode display
          Text(
            timecodeStr,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  letterSpacing: 4,
                ),
          ),
          const SizedBox(height: 12),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatChip('RSSI', '$_liveRssi dBm'),
              const SizedBox(width: 16),
              _buildStatChip('Rate', '$_packetsPerSecond pkt/s'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatChip('Offset', '${_selectedHypothesis!.byteOffset}'),
              const SizedBox(width: 16),
              _buildStatChip('Payload', '$_livePayloadLength B'),
              if (_selectedHypothesis?.inferredFps != null) ...[
                const SizedBox(width: 16),
                _buildStatChip('FPS', '${_selectedHypothesis!.inferredFps}'),
              ],
            ],
          ),

          // Raw bytes at offset for debugging
          if (_liveRawBytes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withAlpha(200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Raw: $_liveRawBytes',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
              ),
            ),
          ],

          // No BLE service warning
          if (widget.bleService == null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Live updates unavailable - no BLE service provided',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.orange,
                    ),
              ),
            ),

          // Open in Monitor button
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _openInMonitor,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Open in Monitor'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  void _openInMonitor() {
    if (_selectedHypothesis == null) return;

    final deviceAddress = widget.scanResult['address'] as String?;
    if (deviceAddress == null) return;

    final config = TimecodeMonitorConfig(
      deviceAddress: deviceAddress,
      deviceName: widget.deviceName,
      byteOffset: _selectedHypothesis!.byteOffset,
      byteLength: _selectedHypothesis!.byteLength,
      strategy: _selectedHypothesis!.strategy,
      inferredFps: _selectedHypothesis!.inferredFps,
    );

    // Set the config in the global notifier
    context.read<MonitorConfigNotifier>().setConfig(config);

    // Switch to monitor tab using the global navigation key
    mainNavigationKey.currentState?.switchToMonitorTab();

    // Pop back to the main screen
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimecodeCard(TimecodeHypothesis hypothesis, bool isBest, bool isSelected) {
    final confidenceColor = hypothesis.confidence >= 70
        ? Colors.green
        : hypothesis.confidence >= 50
            ? Colors.orange
            : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected
          ? Theme.of(context).colorScheme.secondaryContainer
          : (isBest ? Theme.of(context).colorScheme.primaryContainer : null),
      child: InkWell(
        onTap: () => _selectHypothesis(hypothesis),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_arrow, color: Colors.white, size: 12),
                                SizedBox(width: 2),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (isBest)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'BEST',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Flexible(
                          child: Text(
                            hypothesis.strategyName,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: confidenceColor.withAlpha(50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${hypothesis.confidence}%',
                      style: TextStyle(
                        color: confidenceColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  hypothesis.timecode.toString(),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                hypothesis.explanation,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (hypothesis.inferredFps != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Inferred FPS: ${hypothesis.inferredFps}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bytes: offset ${hypothesis.byteOffset}, length ${hypothesis.byteLength}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                  ),
                  if (!isSelected && widget.bleService != null)
                    Text(
                      'Tap to select',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
