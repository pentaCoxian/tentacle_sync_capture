import 'package:flutter/material.dart';

class DeviceTile extends StatelessWidget {
  final Map<String, dynamic> scanResult;
  final bool isPinned;
  final VoidCallback? onTap;
  final VoidCallback? onPin;
  final VoidCallback? onUnpin;

  const DeviceTile({
    super.key,
    required this.scanResult,
    this.isPinned = false,
    this.onTap,
    this.onPin,
    this.onUnpin,
  });

  String get _name =>
      scanResult['name'] as String? ?? 'Unknown Device';

  String get _address =>
      scanResult['address'] as String? ?? 'Unknown';

  int get _rssi => scanResult['rssi'] as int? ?? -100;

  bool get _isConnectable =>
      scanResult['isConnectable'] as bool? ?? true;

  List<String> get _serviceUuids =>
      (scanResult['serviceUuids'] as List<dynamic>?)?.cast<String>() ?? [];

  Color _rssiColor() {
    if (_rssi >= -50) return Colors.green;
    if (_rssi >= -70) return Colors.lightGreen;
    if (_rssi >= -80) return Colors.orange;
    return Colors.red;
  }

  IconData _rssiIcon() {
    if (_rssi >= -50) return Icons.signal_cellular_4_bar;
    if (_rssi >= -70) return Icons.signal_cellular_alt;
    if (_rssi >= -80) return Icons.signal_cellular_alt_2_bar;
    return Icons.signal_cellular_alt_1_bar;
  }

  @override
  Widget build(BuildContext context) {
    final hasName = scanResult['name'] != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: isPinned ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // RSSI indicator
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _rssiColor().withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_rssiIcon(), color: _rssiColor(), size: 20),
                    Text(
                      '${_rssi}dB',
                      style: TextStyle(
                        fontSize: 10,
                        color: _rssiColor(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Device info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isPinned)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.push_pin,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            _name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: hasName ? FontWeight.bold : FontWeight.normal,
                                  fontStyle: hasName ? null : FontStyle.italic,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _address,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                    ),
                    if (_serviceUuids.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: _serviceUuids.take(3).map((uuid) {
                          final shortUuid = uuid.length > 8
                              ? uuid.substring(0, 8)
                              : uuid;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              shortUuid,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              // Actions
              Column(
                children: [
                  if (!_isConnectable)
                    const Tooltip(
                      message: 'Not connectable',
                      child: Icon(Icons.link_off, size: 16, color: Colors.grey),
                    ),
                  IconButton(
                    icon: Icon(
                      isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      color: isPinned
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    onPressed: isPinned ? onUnpin : onPin,
                    tooltip: isPinned ? 'Unpin device' : 'Pin device',
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
