import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../models/capture_session.dart' as models;
import '../../services/export_service.dart';
import 'session_detail_screen.dart';

typedef CaptureSession = models.CaptureSession;

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  List<CaptureSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final notifier = context.read<SessionManagerNotifier>();
    final sessions = await notifier.sessionManager.getAllSessions();
    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  Future<void> _deleteSession(CaptureSession session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text('Are you sure you want to delete the session from ${DateFormat.yMd().add_Hm().format(session.startedAt)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final notifier = context.read<SessionManagerNotifier>();
      await notifier.sessionManager.deleteSession(session.id);
      await _loadSessions();
    }
  }

  Future<void> _exportSession(CaptureSession session) async {
    final notifier = context.read<SessionManagerNotifier>();
    final events = await notifier.sessionManager.getEventsForSession(session.id);

    final exportService = ExportService();
    await exportService.exportSession(session, events);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session exported')),
      );
    }
  }

  void _openSessionDetail(CaptureSession session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SessionDetailScreen(session: session),
      ),
    ).then((_) => _loadSessions());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No capture sessions yet',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start a capture from the Monitor tab',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSessions,
                  child: ListView.builder(
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      return _buildSessionCard(session);
                    },
                  ),
                ),
    );
  }

  Widget _buildSessionCard(CaptureSession session) {
    final dateFormat = DateFormat.yMMMd().add_Hm();
    final duration = session.duration;
    final durationStr = duration != null
        ? '${duration.inMinutes}m ${duration.inSeconds % 60}s'
        : 'In progress';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => _openSessionDetail(session),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        session.isActive ? Icons.fiber_manual_record : Icons.check_circle,
                        size: 16,
                        color: session.isActive ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateFormat.format(session.startedAt),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'export':
                          _exportSession(session);
                          break;
                        case 'delete':
                          _deleteSession(session);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(Icons.share),
                            SizedBox(width: 8),
                            Text('Export'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildInfoChip(Icons.timer, durationStr),
                  const SizedBox(width: 8),
                  _buildInfoChip(Icons.smartphone, session.phoneModel),
                ],
              ),
              if (session.labels.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: session.labels
                      .map((label) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              label,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                            ),
                          ))
                      .toList(),
                ),
              ],
              if (session.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  session.notes,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
