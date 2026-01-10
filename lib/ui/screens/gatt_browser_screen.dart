import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/ble_service.dart';

class GattBrowserScreen extends StatefulWidget {
  final String deviceAddress;
  final String deviceName;

  const GattBrowserScreen({
    super.key,
    required this.deviceAddress,
    required this.deviceName,
  });

  @override
  State<GattBrowserScreen> createState() => _GattBrowserScreenState();
}

class _GattBrowserScreenState extends State<GattBrowserScreen> {
  String _connectionState = 'disconnected';
  List<BleService_Service> _services = [];
  final Set<String> _subscribedCharacteristics = {};
  final Map<String, String> _characteristicValues = {};
  StreamSubscription<Map<String, dynamic>>? _gattSubscription;

  @override
  void initState() {
    super.initState();
    _setupGattListener();
  }

  @override
  void dispose() {
    _gattSubscription?.cancel();
    _disconnect();
    super.dispose();
  }

  void _setupGattListener() {
    final bleService = context.read<BleService>();
    _gattSubscription = bleService.gattStream.listen((event) {
      final eventType = event['eventType'] as String?;

      switch (eventType) {
        case 'connectionStateChange':
          setState(() {
            _connectionState = event['state'] as String? ?? 'unknown';
          });
          if (_connectionState == 'connected') {
            _discoverServices();
          }
          break;

        case 'servicesDiscovered':
          _loadServices();
          break;

        case 'characteristicEvent':
          final charUuid = event['characteristicUuid'] as String?;
          final valueBase64 = event['valueBase64'] as String?;
          if (charUuid != null && valueBase64 != null) {
            setState(() {
              _characteristicValues[charUuid] = valueBase64;
            });
          }
          break;
      }
    });
  }

  Future<void> _connect() async {
    final bleService = context.read<BleService>();
    setState(() {
      _connectionState = 'connecting';
    });
    await bleService.connect(widget.deviceAddress);
  }

  Future<void> _disconnect() async {
    final bleService = context.read<BleService>();
    await bleService.disconnect();
    setState(() {
      _connectionState = 'disconnected';
      _services = [];
      _subscribedCharacteristics.clear();
      _characteristicValues.clear();
    });
  }

  Future<void> _discoverServices() async {
    final bleService = context.read<BleService>();
    await bleService.discoverServices();
  }

  Future<void> _loadServices() async {
    final bleService = context.read<BleService>();
    final services = await bleService.getServices();
    setState(() {
      _services = services;
    });
  }

  Future<void> _toggleSubscription(String serviceUuid, String charUuid) async {
    final bleService = context.read<BleService>();
    final key = '$serviceUuid:$charUuid';

    if (_subscribedCharacteristics.contains(key)) {
      final success = await bleService.unsubscribe(serviceUuid, charUuid);
      if (success) {
        setState(() {
          _subscribedCharacteristics.remove(key);
        });
      }
    } else {
      final success = await bleService.subscribe(serviceUuid, charUuid);
      if (success) {
        setState(() {
          _subscribedCharacteristics.add(key);
        });
      }
    }
  }

  Future<void> _readCharacteristic(String serviceUuid, String charUuid) async {
    final bleService = context.read<BleService>();
    await bleService.readCharacteristic(serviceUuid, charUuid);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceName),
        actions: [
          _buildConnectionButton(),
        ],
      ),
      body: Column(
        children: [
          // Connection status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: _getStatusColor().withAlpha(50),
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(),
                  color: _getStatusColor(),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _connectionState.toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  widget.deviceAddress,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                ),
              ],
            ),
          ),

          // Services list
          Expanded(
            child: _services.isEmpty
                ? Center(
                    child: _connectionState == 'connected'
                        ? const CircularProgressIndicator()
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.bluetooth_disabled, size: 64),
                              const SizedBox(height: 16),
                              const Text('Not connected'),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _connect,
                                icon: const Icon(Icons.bluetooth_connected),
                                label: const Text('Connect'),
                              ),
                            ],
                          ),
                  )
                : ListView.builder(
                    itemCount: _services.length,
                    itemBuilder: (context, index) {
                      final service = _services[index];
                      return _buildServiceCard(service);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionButton() {
    if (_connectionState == 'connecting' || _connectionState == 'disconnecting') {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_connectionState == 'connected') {
      return IconButton(
        icon: const Icon(Icons.bluetooth_disabled),
        onPressed: _disconnect,
        tooltip: 'Disconnect',
      );
    }

    return IconButton(
      icon: const Icon(Icons.bluetooth_connected),
      onPressed: _connect,
      tooltip: 'Connect',
    );
  }

  Color _getStatusColor() {
    return switch (_connectionState) {
      'connected' => Colors.green,
      'connecting' => Colors.orange,
      'disconnecting' => Colors.orange,
      _ => Colors.grey,
    };
  }

  IconData _getStatusIcon() {
    return switch (_connectionState) {
      'connected' => Icons.bluetooth_connected,
      'connecting' => Icons.bluetooth_searching,
      'disconnecting' => Icons.bluetooth_searching,
      _ => Icons.bluetooth_disabled,
    };
  }

  Widget _buildServiceCard(BleService_Service service) {
    final shortUuid = _shortUuid(service.uuid);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        title: Text(
          _getServiceName(service.uuid),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          shortUuid,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
        ),
        leading: Icon(
          service.isPrimary ? Icons.star : Icons.star_border,
          color: service.isPrimary ? Colors.amber : null,
        ),
        children: service.characteristics
            .map((char) => _buildCharacteristicTile(service.uuid, char))
            .toList(),
      ),
    );
  }

  Widget _buildCharacteristicTile(String serviceUuid, BleService_Characteristic char) {
    final key = '$serviceUuid:${char.uuid}';
    final isSubscribed = _subscribedCharacteristics.contains(key);
    final value = _characteristicValues[char.uuid];

    return ListTile(
      title: Text(
        _getCharacteristicName(char.uuid),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _shortUuid(char.uuid),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
          ),
          const SizedBox(height: 4),
          _buildPropertiesRow(char),
          if (value != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _hexFromBase64(value),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (char.isReadable)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _readCharacteristic(serviceUuid, char.uuid),
              tooltip: 'Read',
            ),
          if (char.isNotifiable || char.isIndicatable)
            IconButton(
              icon: Icon(
                isSubscribed ? Icons.notifications_active : Icons.notifications_outlined,
                color: isSubscribed ? Colors.green : null,
              ),
              onPressed: () => _toggleSubscription(serviceUuid, char.uuid),
              tooltip: isSubscribed ? 'Unsubscribe' : 'Subscribe',
            ),
        ],
      ),
    );
  }

  Widget _buildPropertiesRow(BleService_Characteristic char) {
    final properties = <Widget>[];

    if (char.isReadable) {
      properties.add(_buildPropertyChip('R'));
    }
    if (char.isWritable) {
      properties.add(_buildPropertyChip('W'));
    }
    if (char.isWritableNoResponse) {
      properties.add(_buildPropertyChip('WNR'));
    }
    if (char.isNotifiable) {
      properties.add(_buildPropertyChip('N'));
    }
    if (char.isIndicatable) {
      properties.add(_buildPropertyChip('I'));
    }

    return Row(children: properties);
  }

  Widget _buildPropertyChip(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  String _shortUuid(String uuid) {
    if (uuid.length == 36 &&
        uuid.substring(8, 36) == '-0000-1000-8000-00805f9b34fb') {
      return '0x${uuid.substring(4, 8).toUpperCase()}';
    }
    return uuid.substring(0, 8).toUpperCase();
  }

  String _getServiceName(String uuid) {
    final shortId = uuid.substring(4, 8).toLowerCase();
    return switch (shortId) {
      '1800' => 'Generic Access',
      '1801' => 'Generic Attribute',
      '180a' => 'Device Information',
      '180f' => 'Battery Service',
      '1812' => 'Human Interface Device',
      _ => 'Unknown Service',
    };
  }

  String _getCharacteristicName(String uuid) {
    final shortId = uuid.substring(4, 8).toLowerCase();
    return switch (shortId) {
      '2a00' => 'Device Name',
      '2a01' => 'Appearance',
      '2a19' => 'Battery Level',
      '2a29' => 'Manufacturer Name',
      '2a24' => 'Model Number',
      '2a25' => 'Serial Number',
      '2a26' => 'Firmware Revision',
      '2a27' => 'Hardware Revision',
      '2a28' => 'Software Revision',
      _ => 'Unknown',
    };
  }

  String _hexFromBase64(String base64) {
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

    return output.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
  }
}
