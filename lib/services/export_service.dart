import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/capture_event.dart';
import '../models/capture_session.dart';

class ExportService {
  Future<void> exportSession(
    CaptureSession session,
    List<CaptureEvent> events,
  ) async {
    // Create JSONL content
    final jsonlContent = StringBuffer();

    // First line: session metadata
    jsonlContent.writeln(jsonEncode({
      'type': 'session',
      ...session.toJson(),
    }));

    // Event lines
    for (final event in events) {
      jsonlContent.writeln(jsonEncode({
        'type': 'event',
        ...event.toJson(),
      }));
    }

    // Create archive
    final archive = Archive();

    // Add session file
    final sessionJson = jsonEncode(session.toJson());
    archive.addFile(ArchiveFile(
      'session.json',
      sessionJson.length,
      utf8.encode(sessionJson),
    ));

    // Add events JSONL file
    final eventsJsonl = jsonlContent.toString();
    archive.addFile(ArchiveFile(
      'events.jsonl',
      eventsJsonl.length,
      utf8.encode(eventsJsonl),
    ));

    // Encode to ZIP
    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) {
      throw Exception('Failed to create ZIP archive');
    }

    // Save to temp file
    final tempDir = await getTemporaryDirectory();
    final timestamp = session.startedAt.toIso8601String().replaceAll(':', '-');
    final fileName = 'tentacle_capture_$timestamp.zip';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsBytes(zipData);

    // Share file
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Tentacle Sync Capture Session',
      text: 'Capture session from ${session.startedAt.toIso8601String()}',
    );
  }

  Future<(CaptureSession, List<CaptureEvent>)?> importSession(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    CaptureSession? session;
    final events = <CaptureEvent>[];

    for (final file in archive) {
      if (file.isFile) {
        final content = utf8.decode(file.content as List<int>);

        if (file.name == 'session.json') {
          final json = jsonDecode(content) as Map<String, dynamic>;
          session = CaptureSession.fromJson(json);
        } else if (file.name == 'events.jsonl') {
          final lines = content.split('\n');
          for (final line in lines) {
            if (line.trim().isEmpty) continue;
            final json = jsonDecode(line) as Map<String, dynamic>;
            if (json['type'] == 'event') {
              events.add(CaptureEvent.fromJson(json));
            }
          }
        }
      }
    }

    if (session == null) {
      return null;
    }

    return (session, events);
  }

  String exportToJsonl(CaptureSession session, List<CaptureEvent> events) {
    final buffer = StringBuffer();

    // Session metadata
    buffer.writeln(jsonEncode({
      'type': 'session',
      ...session.toJson(),
    }));

    // Events
    for (final event in events) {
      buffer.writeln(jsonEncode({
        'type': 'event',
        ...event.toJson(),
      }));
    }

    return buffer.toString();
  }
}
