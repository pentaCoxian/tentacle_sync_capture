class CaptureSession {
  final String id;
  final DateTime startedAt;
  DateTime? endedAt;
  final String phoneModel;
  final String androidVersion;
  final String appVersion;
  final Map<String, dynamic> scanSettings;
  List<String> labels;
  String notes;
  final List<SessionMarker> markers;

  CaptureSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.phoneModel,
    required this.androidVersion,
    required this.appVersion,
    Map<String, dynamic>? scanSettings,
    List<String>? labels,
    this.notes = '',
    List<SessionMarker>? markers,
  })  : scanSettings = scanSettings ?? {},
        labels = labels ?? [],
        markers = markers ?? [];

  bool get isActive => endedAt == null;

  Duration? get duration {
    final end = endedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  void addLabel(String label) {
    if (!labels.contains(label)) {
      labels.add(label);
    }
  }

  void removeLabel(String label) {
    labels.remove(label);
  }

  void addMarker(String text) {
    markers.add(SessionMarker(
      timestamp: DateTime.now(),
      text: text,
    ));
  }

  void end() {
    endedAt = DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'phoneModel': phoneModel,
      'androidVersion': androidVersion,
      'appVersion': appVersion,
      'scanSettings': scanSettings,
      'labels': labels,
      'notes': notes,
      'markers': markers.map((m) => m.toJson()).toList(),
    };
  }

  factory CaptureSession.fromJson(Map<String, dynamic> json) {
    return CaptureSession(
      id: json['id'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] != null
          ? DateTime.parse(json['endedAt'] as String)
          : null,
      phoneModel: json['phoneModel'] as String? ?? '',
      androidVersion: json['androidVersion'] as String? ?? '',
      appVersion: json['appVersion'] as String? ?? '',
      scanSettings: (json['scanSettings'] as Map<String, dynamic>?) ?? {},
      labels: (json['labels'] as List<dynamic>?)?.cast<String>() ?? [],
      notes: json['notes'] as String? ?? '',
      markers: (json['markers'] as List<dynamic>?)
              ?.map((m) => SessionMarker.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  CaptureSession copyWith({
    String? id,
    DateTime? startedAt,
    DateTime? endedAt,
    String? phoneModel,
    String? androidVersion,
    String? appVersion,
    Map<String, dynamic>? scanSettings,
    List<String>? labels,
    String? notes,
    List<SessionMarker>? markers,
  }) {
    return CaptureSession(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      phoneModel: phoneModel ?? this.phoneModel,
      androidVersion: androidVersion ?? this.androidVersion,
      appVersion: appVersion ?? this.appVersion,
      scanSettings: scanSettings ?? this.scanSettings,
      labels: labels ?? List.from(this.labels),
      notes: notes ?? this.notes,
      markers: markers ?? List.from(this.markers),
    );
  }
}

class SessionMarker {
  final DateTime timestamp;
  final String text;

  SessionMarker({
    required this.timestamp,
    required this.text,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'text': text,
    };
  }

  factory SessionMarker.fromJson(Map<String, dynamic> json) {
    return SessionMarker(
      timestamp: DateTime.parse(json['timestamp'] as String),
      text: json['text'] as String,
    );
  }
}
