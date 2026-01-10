import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../database/database.dart';
import '../../models/pinned_device.dart' as models;
import '../../services/ble_service.dart';
import '../widgets/device_tile.dart';
import 'packet_inspector_screen.dart';

typedef PinnedDevice = models.PinnedDevice;

const String _quickstartShownKey = 'quickstart_dialog_dismissed';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final Map<String, Map<String, dynamic>> _discoveredDevices = {};
  final List<PinnedDevice> _pinnedDevices = [];
  StreamSubscription<Map<String, dynamic>>? _scanSubscription;
  bool _isScanning = false;
  bool _hasPermissions = false;
  bool _quickstartChecked = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadPinnedDevices();
    _checkQuickstartDialog();
  }

  Future<void> _checkQuickstartDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_quickstartShownKey) ?? false;
    if (!dismissed && mounted) {
      setState(() {
        _quickstartChecked = true;
      });
      // Show dialog after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showQuickstartDialog();
        }
      });
    } else {
      setState(() {
        _quickstartChecked = true;
      });
    }
  }

  Future<void> _showQuickstartDialog() async {
    final dontShowAgain = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const QuickstartDialog(),
    );

    if (dontShowAgain == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_quickstartShownKey, true);
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final bleService = context.read<BleService>();
    final hasPermissions = await bleService.hasPermissions();
    setState(() {
      _hasPermissions = hasPermissions;
    });
  }

  Future<void> _requestPermissions() async {
    final bleService = context.read<BleService>();
    final granted = await bleService.requestPermissions();
    setState(() {
      _hasPermissions = granted;
    });
    if (granted) {
      _startScan();
    }
  }

  Future<void> _loadPinnedDevices() async {
    final database = context.read<AppDatabase>();
    final devices = await database.getAllPinnedDevices();
    setState(() {
      _pinnedDevices.clear();
      _pinnedDevices.addAll(devices);
    });
  }

  Future<void> _startScan() async {
    if (!_hasPermissions) {
      _requestPermissions();
      return;
    }

    final bleService = context.read<BleService>();

    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
    });

    _scanSubscription?.cancel();
    _scanSubscription = bleService.scanStream.listen((result) {
      final address = result['address'] as String?;
      if (address != null) {
        setState(() {
          _discoveredDevices[address] = result;
        });
      }
    });

    await bleService.startScan(scanMode: BleService.scanModeLowLatency);
  }

  Future<void> _stopScan() async {
    final bleService = context.read<BleService>();
    await bleService.stopScan();
    _scanSubscription?.cancel();
    _scanSubscription = null;
    setState(() {
      _isScanning = false;
    });
  }

  bool _isPinned(String address) {
    return _pinnedDevices.any((d) => d.address == address);
  }

  Future<void> _pinDevice(Map<String, dynamic> scanResult) async {
    final database = context.read<AppDatabase>();
    final device = PinnedDevice.fromScanResult(
      id: const Uuid().v4(),
      scanResult: scanResult,
    );
    await database.insertPinnedDevice(device);
    await _loadPinnedDevices();
  }

  Future<void> _unpinDevice(String address) async {
    final database = context.read<AppDatabase>();
    final device = _pinnedDevices.firstWhere((d) => d.address == address);
    await database.deletePinnedDevice(device.id);
    await _loadPinnedDevices();
  }

  void _openPacketInspector(Map<String, dynamic> scanResult) {
    final bleService = context.read<BleService>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PacketInspectorScreen(
          scanResult: scanResult,
          deviceName: scanResult['name'] as String? ?? scanResult['address'] as String? ?? 'Unknown',
          bleService: bleService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedDevices = _discoveredDevices.values.toList()
      ..sort((a, b) {
        // Pinned devices first
        final aPinned = _isPinned(a['address'] as String? ?? '');
        final bPinned = _isPinned(b['address'] as String? ?? '');
        if (aPinned && !bPinned) return -1;
        if (!aPinned && bPinned) return 1;

        // Then by RSSI (stronger signal first)
        final aRssi = a['rssi'] as int? ?? -100;
        final bRssi = b['rssi'] as int? ?? -100;
        return bRssi.compareTo(aRssi);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showQuickstartDialog,
            tooltip: 'Quick Start Guide',
          ),
          if (_isScanning)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopScan,
              tooltip: 'Stop Scan',
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _startScan,
              tooltip: 'Start Scan',
            ),
        ],
      ),
      body: !_hasPermissions
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bluetooth_disabled, size: 64),
                  const SizedBox(height: 16),
                  const Text('Bluetooth permissions required'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _requestPermissions,
                    child: const Text('Grant Permissions'),
                  ),
                ],
              ),
            )
          : sortedDevices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isScanning ? 'Scanning for devices...' : 'No devices found',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (!_isScanning) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _startScan,
                          icon: const Icon(Icons.bluetooth_searching),
                          label: const Text('Start Scan'),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: sortedDevices.length,
                  itemBuilder: (context, index) {
                    final device = sortedDevices[index];
                    final address = device['address'] as String? ?? '';
                    final isPinned = _isPinned(address);

                    return DeviceTile(
                      scanResult: device,
                      isPinned: isPinned,
                      onTap: () => _openPacketInspector(device),
                      onPin: () => _pinDevice(device),
                      onUnpin: () => _unpinDevice(address),
                    );
                  },
                ),
      floatingActionButton: _isScanning
          ? FloatingActionButton.extended(
              onPressed: _stopScan,
              icon: const Icon(Icons.stop),
              label: Text('${sortedDevices.length} devices'),
              backgroundColor: Colors.red,
            )
          : FloatingActionButton.extended(
              onPressed: _startScan,
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('Scan'),
            ),
    );
  }
}

/// Quickstart dialog explaining the workflow
class QuickstartDialog extends StatefulWidget {
  const QuickstartDialog({super.key});

  @override
  State<QuickstartDialog> createState() => _QuickstartDialogState();
}

class _QuickstartDialogState extends State<QuickstartDialog> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          const Text('Quick Start'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to Tentacle Sync Capture!',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Follow these steps to capture and monitor timecode:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildStep(
              context,
              number: 1,
              icon: Icons.bluetooth_searching,
              title: 'Start BLE Scan',
              description: 'Tap the Scan button to discover nearby Tentacle Sync devices.',
            ),
            const SizedBox(height: 12),
            _buildStep(
              context,
              number: 2,
              icon: Icons.touch_app,
              title: 'Select Device',
              description: 'Tap on a device to open the Packet Inspector and view raw BLE data.',
            ),
            const SizedBox(height: 12),
            _buildStep(
              context,
              number: 3,
              icon: Icons.access_time,
              title: 'Choose Timecode Offset',
              description: 'In the Timecode tab, select the decode hypothesis that shows valid timecode values.',
            ),
            const SizedBox(height: 12),
            _buildStep(
              context,
              number: 4,
              icon: Icons.monitor,
              title: 'Send to Monitor',
              description: 'Tap "Open in Monitor" to watch the timecode live in the Monitor tab.',
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withAlpha(100),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tips_and_updates,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tip: Use "Smooth" mode in the Monitor tab for interpolated display between packets.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _dontShowAgain,
                  onChanged: (value) {
                    setState(() {
                      _dontShowAgain = value ?? false;
                    });
                  },
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _dontShowAgain = !_dontShowAgain;
                      });
                    },
                    child: Text(
                      "Don't show this again",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_dontShowAgain),
          child: const Text('Get Started'),
        ),
      ],
    );
  }

  Widget _buildStep(
    BuildContext context, {
    required int number,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
