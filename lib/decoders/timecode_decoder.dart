import 'dart:typed_data';

import 'hypothesis_decoder.dart';

/// Confirmed timecode decoder for Tentacle Sync devices
/// This class will be updated as the protocol is reverse-engineered
class TimecodeDecoder {
  final HypothesisDecoder _hypothesisDecoder = HypothesisDecoder();

  // Tentacle Sync company ID (placeholder - needs verification)
  static const int tentacleCompanyId = 0x02E5;

  // Known byte offsets for Tentacle timecode (to be discovered)
  int? _confirmedOffset;
  DecodeStrategy? _confirmedStrategy;
  double? _confirmedFps;

  /// Decode timecode from raw payload
  /// Returns the best hypothesis or confirmed decode
  TimecodeResult decode(Uint8List payload, {int? previousTimestampMillis, int? currentTimestampMillis}) {
    // If we have a confirmed decode strategy, use it
    if (_confirmedOffset != null && _confirmedStrategy != null) {
      final confirmedResult = _decodeWithConfirmedStrategy(payload);
      if (confirmedResult != null) {
        return confirmedResult;
      }
    }

    // Otherwise, use hypothesis decoder
    final hypotheses = _hypothesisDecoder.decodeAll(
      payload,
      previousTimestampMillis: previousTimestampMillis,
      currentTimestampMillis: currentTimestampMillis,
    );

    if (hypotheses.isEmpty) {
      return TimecodeResult(
        timecode: null,
        confidence: 0,
        isConfirmed: false,
        hypotheses: [],
        explanation: 'No valid timecode hypotheses found',
      );
    }

    final bestHypothesis = hypotheses.first;

    // Record for future scoring
    if (currentTimestampMillis != null) {
      _hypothesisDecoder.recordCandidate(bestHypothesis, currentTimestampMillis);
    }

    return TimecodeResult(
      timecode: bestHypothesis.timecode,
      confidence: bestHypothesis.confidence,
      isConfirmed: false,
      hypotheses: hypotheses,
      explanation: bestHypothesis.explanation,
      inferredFps: bestHypothesis.inferredFps,
    );
  }

  /// Decode using confirmed strategy
  TimecodeResult? _decodeWithConfirmedStrategy(Uint8List payload) {
    if (_confirmedOffset == null || _confirmedStrategy == null) return null;
    if (_confirmedOffset! + 4 > payload.length) return null;

    Timecode? timecode;

    switch (_confirmedStrategy!) {
      case DecodeStrategy.bcd:
        timecode = _decodeBcd(payload, _confirmedOffset!);
        break;
      case DecodeStrategy.le32FrameCounter:
        timecode = _decodeLe32(payload, _confirmedOffset!, _confirmedFps ?? 24.0);
        break;
      case DecodeStrategy.be32FrameCounter:
        timecode = _decodeBe32(payload, _confirmedOffset!, _confirmedFps ?? 24.0);
        break;
      case DecodeStrategy.directMapping:
        timecode = _decodeDirect(payload, _confirmedOffset!);
        break;
      default:
        return null;
    }

    if (timecode == null) return null;

    return TimecodeResult(
      timecode: timecode,
      confidence: 100,
      isConfirmed: true,
      hypotheses: [],
      explanation: 'Confirmed decode at offset $_confirmedOffset using ${_confirmedStrategy!.name}',
      inferredFps: _confirmedFps,
    );
  }

  Timecode? _decodeBcd(Uint8List payload, int offset) {
    if (offset + 4 > payload.length) return null;

    int bcdToDec(int bcd) {
      final high = (bcd >> 4) & 0x0F;
      final low = bcd & 0x0F;
      if (high > 9 || low > 9) return -1;
      return high * 10 + low;
    }

    final hh = bcdToDec(payload[offset]);
    final mm = bcdToDec(payload[offset + 1]);
    final ss = bcdToDec(payload[offset + 2]);
    final ff = bcdToDec(payload[offset + 3]);

    if (hh < 0 || hh > 23) return null;
    if (mm < 0 || mm > 59) return null;
    if (ss < 0 || ss > 59) return null;
    if (ff < 0 || ff > 60) return null;

    return Timecode(hours: hh, minutes: mm, seconds: ss, frames: ff);
  }

  Timecode? _decodeLe32(Uint8List payload, int offset, double fps) {
    if (offset + 4 > payload.length) return null;

    final frameCount = payload[offset] |
        (payload[offset + 1] << 8) |
        (payload[offset + 2] << 16) |
        (payload[offset + 3] << 24);

    return _frameCountToTimecode(frameCount, fps);
  }

  Timecode? _decodeBe32(Uint8List payload, int offset, double fps) {
    if (offset + 4 > payload.length) return null;

    final frameCount = (payload[offset] << 24) |
        (payload[offset + 1] << 16) |
        (payload[offset + 2] << 8) |
        payload[offset + 3];

    return _frameCountToTimecode(frameCount, fps);
  }

  Timecode? _decodeDirect(Uint8List payload, int offset) {
    if (offset + 4 > payload.length) return null;

    final hh = payload[offset];
    final mm = payload[offset + 1];
    final ss = payload[offset + 2];
    final ff = payload[offset + 3];

    if (hh > 23 || mm > 59 || ss > 59 || ff > 60) return null;

    return Timecode(hours: hh, minutes: mm, seconds: ss, frames: ff);
  }

  Timecode? _frameCountToTimecode(int frameCount, double fps) {
    if (frameCount < 0) return null;

    final totalSeconds = frameCount / fps;
    final hours = (totalSeconds / 3600).floor();
    final minutes = ((totalSeconds % 3600) / 60).floor();
    final seconds = (totalSeconds % 60).floor();
    final frames = (frameCount % fps.round()).floor();

    if (hours > 23) return null;

    return Timecode(hours: hours, minutes: minutes, seconds: seconds, frames: frames);
  }

  /// Confirm a decode strategy based on user verification
  void confirmStrategy({
    required int offset,
    required DecodeStrategy strategy,
    double? fps,
  }) {
    _confirmedOffset = offset;
    _confirmedStrategy = strategy;
    _confirmedFps = fps;
  }

  /// Reset confirmed strategy
  void resetConfirmation() {
    _confirmedOffset = null;
    _confirmedStrategy = null;
    _confirmedFps = null;
    _hypothesisDecoder.reset();
  }

  /// Check if strategy is confirmed
  bool get isConfirmed => _confirmedOffset != null && _confirmedStrategy != null;

  /// Get current confirmed configuration
  Map<String, dynamic>? get confirmedConfig {
    if (!isConfirmed) return null;
    return {
      'offset': _confirmedOffset,
      'strategy': _confirmedStrategy?.name,
      'fps': _confirmedFps,
    };
  }
}

/// Result of timecode decoding
class TimecodeResult {
  final Timecode? timecode;
  final int confidence;
  final bool isConfirmed;
  final List<TimecodeHypothesis> hypotheses;
  final String explanation;
  final double? inferredFps;

  TimecodeResult({
    required this.timecode,
    required this.confidence,
    required this.isConfirmed,
    required this.hypotheses,
    required this.explanation,
    this.inferredFps,
  });

  bool get hasTimecode => timecode != null;

  String get displayTimecode => timecode?.toString() ?? '--:--:--:--';

  Map<String, dynamic> toJson() {
    return {
      'timecode': timecode?.toJson(),
      'confidence': confidence,
      'isConfirmed': isConfirmed,
      'explanation': explanation,
      'inferredFps': inferredFps,
      'hypotheses': hypotheses.map((h) => h.toJson()).toList(),
    };
  }
}
