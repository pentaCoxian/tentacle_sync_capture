import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../database/database.dart';
import '../../models/pinned_device.dart' as models;
import '../../services/ble_service.dart';
import '../widgets/device_tile.dart';
import 'packet_inspector_screen.dart';

typedef PinnedDevice = models.PinnedDevice;

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

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadPinnedDevices();
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
