import 'dart:typed_data';

/// Hypothesis-based timecode decoder
/// Attempts multiple interpretation strategies and scores their plausibility
class HypothesisDecoder {
  final List<TimecodeCandidate> _recentCandidates = [];
  static const int _historySize = 30; // Keep last 30 samples for analysis

  /// Standard frame rates to test against
  static const List<double> standardFps = [
    23.976,
    24.0,
    25.0,
    29.97,
    30.0,
    48.0,
    50.0,
    59.94,
    60.0,
  ];

  /// Decode all hypotheses from a payload
  List<TimecodeHypothesis> decodeAll(Uint8List payload, {int? previousTimestampMillis, int? currentTimestampMillis}) {
    final hypotheses = <TimecodeHypothesis>[];

    // Skip empty or very short payloads
    if (payload.length < 4) {
      return hypotheses;
    }

    // Try different decode strategies at different byte offsets
    for (int offset = 0; offset < payload.length - 3; offset++) {
      // BCD decode (common for timecode)
      final bcdResult = _tryBcdDecode(payload, offset);
      if (bcdResult != null) {
        hypotheses.add(bcdResult);
      }

      // 32-bit little-endian frame counter
      if (offset + 4 <= payload.length) {
        final le32Result = _tryLe32FrameCounter(payload, offset);
        if (le32Result != null) {
          hypotheses.add(le32Result);
        }

        // 32-bit big-endian frame counter
        final be32Result = _tryBe32FrameCounter(payload, offset);
        if (be32Result != null) {
          hypotheses.add(be32Result);
        }
      }

      // Direct byte mapping hh:mm:ss:ff
      if (offset + 4 <= payload.length) {
        final directResult = _tryDirectMapping(payload, offset);
        if (directResult != null) {
          hypotheses.add(directResult);
        }
      }
    }

    // Score hypotheses based on history
    if (previousTimestampMillis != null && currentTimestampMillis != null) {
      final elapsedMs = currentTimestampMillis - previousTimestampMillis;
      for (final hypothesis in hypotheses) {
        _scoreHypothesis(hypothesis, elapsedMs);
      }
    }

    // Sort by confidence
    hypotheses.sort((a, b) => b.confidence.compareTo(a.confidence));

    return hypotheses;
  }

  /// Try to decode as BCD (Binary Coded Decimal) timecode
  TimecodeHypothesis? _tryBcdDecode(Uint8List payload, int offset) {
    if (offset + 4 > payload.length) return null;

    // BCD decode 4 bytes as hh:mm:ss:ff
    final hh = _bcdToDec(payload[offset]);
    final mm = _bcdToDec(payload[offset + 1]);
    final ss = _bcdToDec(payload[offset + 2]);
    final ff = _bcdToDec(payload[offset + 3]);

    // Validate ranges
    if (hh < 0 || hh > 23) return null;
    if (mm < 0 || mm > 59) return null;
    if (ss < 0 || ss > 59) return null;
    if (ff < 0 || ff > 60) return null; // Allow up to 60 for various frame rates

    return TimecodeHypothesis(
      strategy: DecodeStrategy.bcd,
      timecode: Timecode(hours: hh, minutes: mm, seconds: ss, frames: ff),
      byteOffset: offset,
      byteLength: 4,
      confidence: 50, // Base confidence, will be adjusted
      explanation: 'BCD decode at offset $offset',
    );
  }

  /// Try to decode as 32-bit little-endian frame counter
  TimecodeHypothesis? _tryLe32FrameCounter(Uint8List payload, int offset) {
    if (offset + 4 > payload.length) return null;

    final frameCount = payload[offset] |
        (payload[offset + 1] << 8) |
        (payload[offset + 2] << 16) |
        (payload[offset + 3] << 24);

    // Skip if it looks like garbage (extremely large values)
    if (frameCount < 0 || frameCount > 86400 * 60) return null; // Max ~1 day at 60fps

    // Find best matching FPS
    double bestFps = 24.0;
    int bestConfidence = 0;

    for (final fps in standardFps) {
      final timecode = _frameCountToTimecode(frameCount, fps);
      if (timecode != null) {
        final confidence = _estimateFpsConfidence(frameCount, fps);
        if (confidence > bestConfidence) {
          bestConfidence = confidence;
          bestFps = fps;
        }
      }
    }

    final timecode = _frameCountToTimecode(frameCount, bestFps);
    if (timecode == null) return null;

    return TimecodeHypothesis(
      strategy: DecodeStrategy.le32FrameCounter,
      timecode: timecode,
      byteOffset: offset,
      byteLength: 4,
      confidence: 40 + bestConfidence,
      explanation: 'LE32 frame counter at offset $offset (${bestFps}fps)',
      frameCount: frameCount,
      inferredFps: bestFps,
    );
  }

  /// Try to decode as 32-bit big-endian frame counter
  TimecodeHypothesis? _tryBe32FrameCounter(Uint8List payload, int offset) {
    if (offset + 4 > payload.length) return null;

    final frameCount = (payload[offset] << 24) |
        (payload[offset + 1] << 16) |
        (payload[offset + 2] << 8) |
        payload[offset + 3];

    // Skip if it looks like garbage
    if (frameCount < 0 || frameCount > 86400 * 60) return null;

    double bestFps = 24.0;
    int bestConfidence = 0;

    for (final fps in standardFps) {
      final timecode = _frameCountToTimecode(frameCount, fps);
      if (timecode != null) {
        final confidence = _estimateFpsConfidence(frameCount, fps);
        if (confidence > bestConfidence) {
          bestConfidence = confidence;
          bestFps = fps;
        }
      }
    }

    final timecode = _frameCountToTimecode(frameCount, bestFps);
    if (timecode == null) return null;

    return TimecodeHypothesis(
      strategy: DecodeStrategy.be32FrameCounter,
      timecode: timecode,
      byteOffset: offset,
      byteLength: 4,
      confidence: 35 + bestConfidence,
      explanation: 'BE32 frame counter at offset $offset (${bestFps}fps)',
      frameCount: frameCount,
      inferredFps: bestFps,
    );
  }

  /// Try direct byte mapping (each byte is a component)
  TimecodeHypothesis? _tryDirectMapping(Uint8List payload, int offset) {
    if (offset + 4 > payload.length) return null;

    final hh = payload[offset];
    final mm = payload[offset + 1];
    final ss = payload[offset + 2];
    final ff = payload[offset + 3];

    // Validate ranges
    if (hh > 23) return null;
    if (mm > 59) return null;
    if (ss > 59) return null;
    if (ff > 60) return null;

    return TimecodeHypothesis(
      strategy: DecodeStrategy.directMapping,
      timecode: Timecode(hours: hh, minutes: mm, seconds: ss, frames: ff),
      byteOffset: offset,
      byteLength: 4,
      confidence: 45,
      explanation: 'Direct byte mapping at offset $offset',
    );
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

    if (hours > 23) return null;

    return Timecode(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      frames: frames,
    );
  }

  /// Estimate confidence based on FPS alignment
  int _estimateFpsConfidence(int frameCount, double fps) {
    // Check if frame count looks reasonable for this FPS
    final framesPerDay = (86400 * fps).round();
    if (frameCount > framesPerDay) return 0;

    // Higher confidence for common frame rates
    final fpsBonus = switch (fps) {
      24.0 => 5,
      25.0 => 5,
      29.97 => 5,
      30.0 => 5,
      _ => 0,
    };

    return 10 + fpsBonus;
  }

  /// Score a hypothesis based on temporal consistency
  void _scoreHypothesis(TimecodeHypothesis hypothesis, int elapsedMs) {
    if (_recentCandidates.isEmpty) return;

    // Find previous candidate with same strategy and offset
    final previous = _recentCandidates.reversed.firstWhere(
      (c) => c.strategy == hypothesis.strategy && c.byteOffset == hypothesis.byteOffset,
      orElse: () => TimecodeCandidate(
        strategy: hypothesis.strategy,
        byteOffset: hypothesis.byteOffset,
        frameValue: 0,
        timestampMs: 0,
      ),
    );

    if (previous.timestampMs == 0) return;

    // Calculate expected frame delta
    final fps = hypothesis.inferredFps ?? 24.0;
    final expectedFrameDelta = (elapsedMs / 1000.0 * fps).round();
    final actualFrameDelta = hypothesis.timecode.totalFrames(fps) -
        _recentCandidates.last.frameValue;

    // Score based on how close actual is to expected
    final deltaError = (actualFrameDelta - expectedFrameDelta).abs();
    if (deltaError <= 2) {
      hypothesis.confidence += 20; // Strong match
    } else if (deltaError <= 5) {
      hypothesis.confidence += 10; // Weak match
    } else {
      hypothesis.confidence -= 10; // Poor match
    }

    // Bonus for monotonic increase
    if (actualFrameDelta > 0 && actualFrameDelta < expectedFrameDelta * 2) {
      hypothesis.confidence += 5;
    }
  }

  /// Record a candidate for future scoring
  void recordCandidate(TimecodeHypothesis hypothesis, int timestampMs) {
    _recentCandidates.add(TimecodeCandidate(
      strategy: hypothesis.strategy,
      byteOffset: hypothesis.byteOffset,
      frameValue: hypothesis.timecode.totalFrames(hypothesis.inferredFps ?? 24.0),
      timestampMs: timestampMs,
    ));

    // Trim history
    while (_recentCandidates.length > _historySize) {
      _recentCandidates.removeAt(0);
    }
  }

  /// Clear history
  void reset() {
    _recentCandidates.clear();
  }
}

/// Decode strategy enum
enum DecodeStrategy {
  bcd,
  le32FrameCounter,
  be32FrameCounter,
  directMapping,
  framesSinceMidnight,
}

/// Represents a decoded timecode
class Timecode {
  final int hours;
  final int minutes;
  final int seconds;
  final int frames;
  final bool dropFrame;

  Timecode({
    required this.hours,
    required this.minutes,
    required this.seconds,
    required this.frames,
    this.dropFrame = false,
  });

  @override
  String toString() {
    final separator = dropFrame ? ';' : ':';
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}'
        '$separator${frames.toString().padLeft(2, '0')}';
  }

  int totalFrames(double fps) {
    return (hours * 3600 + minutes * 60 + seconds) * fps.round() + frames;
  }

  int totalSeconds() {
    return hours * 3600 + minutes * 60 + seconds;
  }

  Map<String, dynamic> toJson() {
    return {
      'hours': hours,
      'minutes': minutes,
      'seconds': seconds,
      'frames': frames,
      'dropFrame': dropFrame,
      'display': toString(),
    };
  }
}

/// A timecode hypothesis with confidence score
class TimecodeHypothesis {
  final DecodeStrategy strategy;
  final Timecode timecode;
  final int byteOffset;
  final int byteLength;
  int confidence;
  final String explanation;
  final int? frameCount;
  final double? inferredFps;

  TimecodeHypothesis({
    required this.strategy,
    required this.timecode,
    required this.byteOffset,
    required this.byteLength,
    required this.confidence,
    required this.explanation,
    this.frameCount,
    this.inferredFps,
  });

  String get strategyName => switch (strategy) {
        DecodeStrategy.bcd => 'BCD',
        DecodeStrategy.le32FrameCounter => 'LE32 Frame Counter',
        DecodeStrategy.be32FrameCounter => 'BE32 Frame Counter',
        DecodeStrategy.directMapping => 'Direct Mapping',
        DecodeStrategy.framesSinceMidnight => 'Frames Since Midnight',
      };

  Map<String, dynamic> toJson() {
    return {
      'strategy': strategyName,
      'timecode': timecode.toJson(),
      'byteOffset': byteOffset,
      'byteLength': byteLength,
      'confidence': confidence,
      'explanation': explanation,
      'frameCount': frameCount,
      'inferredFps': inferredFps,
    };
  }
}

/// Internal candidate for tracking
class TimecodeCandidate {
  final DecodeStrategy strategy;
  final int byteOffset;
  final int frameValue;
  final int timestampMs;

  TimecodeCandidate({
    required this.strategy,
    required this.byteOffset,
    required this.frameValue,
    required this.timestampMs,
  });
}
