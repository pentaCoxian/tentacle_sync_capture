import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/capture_event.dart' as models;
import '../../models/capture_session.dart' as models;
import '../../services/export_service.dart';
import 'packet_inspector_screen.dart';

typedef CaptureEvent = models.CaptureEvent;
typedef CaptureSession = models.CaptureSession;
typedef CaptureSource = models.CaptureSource;

class SessionDetailScreen extends StatefulWidget {
  final CaptureSession session;

  const SessionDetailScreen({
    super.key,
    required this.session,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  List<CaptureEvent> _events = [];
  int _eventCount = 0;
  bool _isLoading = true;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _labelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.session.notes;
    _loadEvents();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    final notifier = context.read<SessionManagerNotifier>();
    final events = await notifier.sessionManager.getEventsForSession(
      widget.session.id,
      limit: 100,
    );
    final count = await notifier.sessionManager.getEventCountForSession(widget.session.id);

    setState(() {
      _events = events;
      _eventCount = count;
      _isLoading = false;
    });
  }

  Future<void> _saveNotes() async {
    final notifier = context.read<SessionManagerNotifier>();
    await notifier.sessionManager.updateSessionNotes(
      widget.session.id,
      _notesController.text,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes saved')),
      );
    }
  }

  Future<void> _addLabel() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Label'),
        content: TextField(
          controller: _labelController,
          decoration: const InputDecoration(
            labelText: 'Label',
            hintText: 'e.g., FPS_25, TEST_RUN',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_labelController.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final notifier = context.read<SessionManagerNotifier>();
      final labels = List<String>.from(widget.session.labels)..add(result);
      await notifier.sessionManager.updateSessionLabels(widget.session.id, labels);
      widget.session.labels = labels;
      setState(() {});
      _labelController.clear();
    }
  }

  Future<void> _removeLabel(String label) async {
    final notifier = context.read<SessionManagerNotifier>();
    final labels = List<String>.from(widget.session.labels)..remove(label);
    await notifier.sessionManager.updateSessionLabels(widget.session.id, labels);
    widget.session.labels = labels;
    setState(() {});
  }

  Future<void> _exportSession() async {
    final notifier = context.read<SessionManagerNotifier>();
    final allEvents = await notifier.sessionManager.getEventsForSession(widget.session.id);

    final exportService = ExportService();
    await exportService.exportSession(widget.session, allEvents);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session exported')),
      );
    }
  }

  void _openEventInspector(CaptureEvent event) {
    // Convert event to scan result format for packet inspector
    final scanResult = {
      'address': event.deviceAddress,
      'name': event.deviceName,
      'rssi': event.rssi,
      'payloadBase64': _encodeBase64(event.payload),
      ...event.meta,
    };

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PacketInspectorScreen(
          scanResult: scanResult,
          deviceName: event.deviceName ?? event.deviceAddress ?? 'Event',
        ),
      ),
    );
  }

  String _encodeBase64(List<int> bytes) {
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

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd().add_Hm();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _exportSession,
            tooltip: 'Export',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Session info card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Session Info',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('Started', dateFormat.format(widget.session.startedAt)),
                          if (widget.session.endedAt != null)
                            _buildInfoRow('Ended', dateFormat.format(widget.session.endedAt!)),
                          if (widget.session.duration != null)
                            _buildInfoRow(
                              'Duration',
                              '${widget.session.duration!.inMinutes}m ${widget.session.duration!.inSeconds % 60}s',
                            ),
                          _buildInfoRow('Events', '$_eventCount'),
                          _buildInfoRow('Device', widget.session.phoneModel),
                          _buildInfoRow('Android', widget.session.androidVersion),
                          _buildInfoRow('App', widget.session.appVersion),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Labels card
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
                                'Labels',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: _addLabel,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          widget.session.labels.isEmpty
                              ? Text(
                                  'No labels',
                                  style: Theme.of(context).textTheme.bodySmall,
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: widget.session.labels
                                      .map((label) => Chip(
                                            label: Text(label),
                                            onDeleted: () => _removeLabel(label),
                                          ))
                                      .toList(),
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notes card
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
                                'Notes',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              TextButton(
                                onPressed: _saveNotes,
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _notesController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: 'Add notes about this session...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Markers card
                  if (widget.session.markers.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Markers',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            ...widget.session.markers.map((marker) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.bookmark,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat.Hms().format(marker.timestamp),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(marker.text)),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Recent events card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent Events (${_events.length} of $_eventCount)',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          if (_events.isEmpty)
                            Text(
                              'No events',
                              style: Theme.of(context).textTheme.bodySmall,
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _events.length.clamp(0, 20),
                              itemBuilder: (context, index) {
                                final event = _events[index];
                                return _buildEventTile(event);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
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
            width: 80,
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
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(CaptureEvent event) {
    final timeStr = DateFormat.Hms().format(event.timestamp);

    return ListTile(
      dense: true,
      leading: Icon(
        event.source == CaptureSource.adv ? Icons.bluetooth : Icons.link,
        size: 20,
      ),
      title: Text(
        event.deviceName ?? event.deviceAddress ?? 'Unknown',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(
        '$timeStr | ${event.payload.length} bytes | RSSI: ${event.rssi ?? '-'}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openEventInspector(event),
    );
  }
}
