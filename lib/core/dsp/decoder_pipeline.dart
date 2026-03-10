import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'goertzel.dart';
import 'morse_decoder.dart';
import '../morse/morse_timing.dart';

// ── Calibration types ─────────────────────────────────────────────────────────

/// Result of a completed calibration run.
class CalibrationResult {
  /// Mean Goertzel power measured during the calibration silence.
  final double noiseFloor;

  /// Coefficient of variation (stdDev / mean) — measures environment stability.
  /// Lower is better: < 0.5 = good, < 1.0 = fair, ≥ 1.0 = poor.
  final double cv;

  /// Overall quality assessment.
  final CalibrationQuality quality;

  const CalibrationResult({
    required this.noiseFloor,
    required this.cv,
    required this.quality,
  });
}

/// Environment quality assessed after calibration.
enum CalibrationQuality {
  /// Stable, quiet environment — best decoding accuracy.
  good,

  /// Some variation present — acceptable accuracy expected.
  fair,

  /// High variation or loud environment — consider re-calibrating elsewhere.
  poor,
}

// ── Signal types ──────────────────────────────────────────────────────────────

/// Signal snapshot emitted ~10×/s for the UI signal meter.
class SignalSnapshot {
  /// Raw Goertzel power at the target frequency.
  final double power;

  /// Current adaptive noise floor.
  final double noiseFloor;

  /// Whether a tone is currently detected.
  final bool isTone;

  const SignalSnapshot({
    required this.power,
    required this.noiseFloor,
    required this.isTone,
  });

  /// Power relative to the tone threshold (1.0 = exactly at threshold).
  double get normalizedToThreshold {
    final threshold = noiseFloor * kSignalRatio;
    return threshold > 0 ? power / threshold : 0;
  }
}

/// How many times stronger than the noise floor counts as a tone.
const double kSignalRatio = 6.0;

// ── DecoderPipeline ───────────────────────────────────────────────────────────

/// Core signal-processing pipeline: Goertzel → adaptive threshold → MorseDecoder.
///
/// **Lifecycle:**
///   1. Feed audio frames via [processFrame].
///      During the first [calibrationFrames] frames the pipeline measures the
///      noise floor and emits progress on [calibrationProgress].
///      [calibrationResult] becomes non-null once calibration completes.
///   2. After calibration, [processFrame] decodes automatically.
///      Decoded text is emitted on [textStream]; signal updates on [signalStream].
///   3. Call [flush] after the final frame to commit any pending character.
///   4. Call [reset] to start over from calibration, or [resetForDecode] to
///      skip calibration using a saved [CalibrationResult].
///
/// **For unit tests**, skip streams and read [decodedText] directly.
class DecoderPipeline {
  /// Default calibration duration: ≈3 s at 512-sample frames / 44 100 Hz.
  static const int defaultCalibrationFrames = 258;

  static const int _debounceRequired = 2;
  static const int _signalEmitInterval = 8; // ~10 Hz at 86 fps
  static const int _flushSilenceMs = 2000;

  final int calibrationFrames;
  final GoertzelDetector detector;

  DecoderPipeline({
    int? calibrationFrames,
    GoertzelDetector? detector,
  })  : calibrationFrames = calibrationFrames ?? defaultCalibrationFrames,
        detector = detector ??
            GoertzelDetector(
              sampleRate: 44100,
              targetFrequency: MorseTiming.defaultFrequencyHz.toDouble(),
              frameSize: 512,
            );

  // ── Calibration state ──────────────────────────────────────────────────────

  int _calibCount = 0;
  double _calibSum = 0;
  double _calibSumSq = 0;
  CalibrationResult? _calibResult;

  /// Non-null once calibration has completed.
  CalibrationResult? get calibrationResult => _calibResult;

  /// True while still collecting calibration frames.
  bool get isCalibrating => _calibResult == null && _calibCount < calibrationFrames;

  // ── Decode state ───────────────────────────────────────────────────────────

  double _noiseFloor = 0;
  double _fastEma = 0;

  bool _toneOn = false;
  int _framesInState = 0;
  int _debounceCount = 0;

  DateTime? _silenceStart;
  int _signalFrameCount = 0;

  final MorseDecoder _decoder = MorseDecoder();

  /// Accumulated decoded text (synchronous accessor — no stream needed in tests).
  String get decodedText => _decoder.decodedText;

  // ── Streams ────────────────────────────────────────────────────────────────

  final _textController = StreamController<String>.broadcast();
  final _signalController = StreamController<SignalSnapshot>.broadcast();
  final _calibProgressController = StreamController<double>.broadcast();

  /// Emits the full decoded text whenever a new character is committed.
  Stream<String> get textStream => _textController.stream;

  /// Emits a [SignalSnapshot] ~10×/s during decoding.
  Stream<SignalSnapshot> get signalStream => _signalController.stream;

  /// Emits calibration progress 0.0–1.0 during the calibration phase.
  Stream<double> get calibrationProgress => _calibProgressController.stream;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Feed one audio frame. Automatically handles calibration then decode.
  void processFrame(Float64List frame) {
    final power = detector.computePower(frame);
    if (isCalibrating) {
      _runCalibration(power);
    } else {
      _runDecode(power);
    }
  }

  /// Feed a precomputed Goertzel power value directly (offline analysis).
  ///
  /// Identical to [processFrame] but skips the Goertzel computation step.
  /// Only valid after [resetForDecode] has been called.
  void processPower(double power) {
    if (isCalibrating) return;
    _runDecode(power);
  }

  /// Finalise the character currently being decoded. Call after the last frame.
  void flush() {
    _decoder.flush();
    _emitText();
  }

  /// Reset everything — goes back to calibration mode.
  void reset() {
    _calibCount = 0;
    _calibSum = 0;
    _calibSumSq = 0;
    _calibResult = null;
    _noiseFloor = 0;
    _fastEma = 0;
    _decoder.reset();
    _resetDecodeState();
  }

  /// Skip calibration — apply a saved [CalibrationResult] and start decoding.
  void resetForDecode(CalibrationResult result) {
    _calibResult = result;
    _calibCount = calibrationFrames;
    _calibSum = 0;
    _calibSumSq = 0;
    _noiseFloor = result.noiseFloor;
    _fastEma = result.noiseFloor;
    _decoder.reset();
    _resetDecodeState();
  }

  /// Pre-seed dot/dash durations into the decoder's adaptive timing.
  ///
  /// Must be called *after* [resetForDecode]. Bypasses the bootstrap phase so
  /// the very first ON event is classified correctly.
  void seedTiming(double dotMs, double dashMs) {
    _decoder.timing.seed(dotMs, dashMs);
  }

  /// Release stream controllers. Call once when done with this pipeline.
  Future<void> dispose() async {
    await _textController.close();
    await _signalController.close();
    await _calibProgressController.close();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _runCalibration(double power) {
    _calibSum += power;
    _calibSumSq += power * power;
    _calibCount++;

    final progress = _calibCount / calibrationFrames;
    if (!_calibProgressController.isClosed) {
      _calibProgressController.add(progress);
    }

    if (_calibCount == calibrationFrames) {
      _finishCalibration();
    }
  }

  void _finishCalibration() {
    final mean = max(_calibSum / calibrationFrames, 1e-10);
    final variance = (_calibSumSq / calibrationFrames) - (mean * mean);
    final stdDev = sqrt(max(variance, 0.0));
    final cv = stdDev / mean;

    final quality = cv < 0.5
        ? CalibrationQuality.good
        : cv < 1.0
            ? CalibrationQuality.fair
            : CalibrationQuality.poor;

    _calibResult = CalibrationResult(noiseFloor: mean, cv: cv, quality: quality);
    _noiseFloor = mean;
    _fastEma = mean;
    // ignore: avoid_print
    print('[MorseDbg] Calibration done:'
        ' noiseFloor=${mean.toStringAsFixed(4)}'
        ' cv=${cv.toStringAsFixed(3)}'
        ' quality=$quality');
  }

  void _runDecode(double power) {
    final isTone = _classifyPower(power);
    _emitSignal(power: power, isTone: isTone);

    // ── Long-silence flush ─────────────────────────────────────────────────
    if (!isTone) {
      _silenceStart ??= DateTime.now();
      if (DateTime.now().difference(_silenceStart!).inMilliseconds >
          _flushSilenceMs) {
        final prev = _decoder.decodedText;
        _decoder.flush();
        _silenceStart = null;
        if (_decoder.decodedText != prev) _emitText();
      }
    } else {
      _silenceStart = null;
    }

    // ── ON/OFF state machine (2-frame debounce) ────────────────────────────
    if (isTone == _toneOn) {
      _framesInState += _debounceCount + 1;
      _debounceCount = 0;
    } else {
      _debounceCount++;
      if (_debounceCount >= _debounceRequired) {
        final durationMs = (_framesInState * detector.frameDurationMs).round();
        if (durationMs > 0) {
          // ignore: avoid_print
          print('[MorseDbg] transition: ${_toneOn ? "ON " : "OFF"} ${durationMs}ms');
          final prev = _decoder.decodedText;
          _decoder.processEvent(on: _toneOn, durationMs: durationMs);
          if (_decoder.decodedText != prev) _emitText();
        }
        _toneOn = isTone;
        _framesInState = _debounceCount;
        _debounceCount = 0;
      }
    }
  }

  bool _classifyPower(double power) {
    _fastEma = _fastEma * 0.5 + power * 0.5;
    if (_fastEma < _noiseFloor * 3) {
      _noiseFloor = _noiseFloor * 0.999 + power * 0.001;
      _noiseFloor = max(_noiseFloor, 1e-10);
    }
    // Raw power for fast release; single-frame glitches absorbed by debounce.
    return power > _noiseFloor * kSignalRatio;
  }

  void _emitText() {
    if (!_textController.isClosed) {
      _textController.add(_decoder.decodedText);
    }
  }

  void _emitSignal({required double power, required bool isTone}) {
    _signalFrameCount++;
    if (_signalFrameCount % _signalEmitInterval == 0 &&
        !_signalController.isClosed) {
      _signalController.add(SignalSnapshot(
        power: power,
        noiseFloor: _noiseFloor,
        isTone: isTone,
      ));
    }
  }

  void _resetDecodeState() {
    _toneOn = false;
    _framesInState = 0;
    _debounceCount = 0;
    _silenceStart = null;
    _signalFrameCount = 0;
  }
}
