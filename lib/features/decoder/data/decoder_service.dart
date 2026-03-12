import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/dsp/decoder_pipeline.dart';
import '../../../core/dsp/goertzel.dart';
import '../../../core/dsp/offline_analyzer.dart';
import '../../../core/morse/morse_timing.dart';

// Re-export so callers only need to import decoder_service.dart.
export '../../../core/dsp/decoder_pipeline.dart'
    show SignalSnapshot, kSignalRatio;

/// Audio capture service for the record-then-analyze decoder flow.
///
/// Responsibilities:
///   - Mic permission check
///   - AudioRecorder lifecycle
///   - Byte-to-frame conversion + Goertzel power computation
///   - Magnitude accumulation for offline analysis
///   - Raw PCM accumulation for WAV export
///   - Live [signalStream] for the signal meter during recording
///
/// Typical usage:
///   1. `await service.startListening()` — mic opens; monitor [signalStream].
///   2. `await service.stopListening()` — mic closes; returns frame count.
///   3. `await service.analyzeRecording()` — offline decode on a background isolate.
///   4. `await service.saveRecording(filename)` — write WAV to app documents dir.
class DecoderService {
  static const int _sampleRate = 44100;
  static const int _frameSize = 512;

  /// Optional callback invoked when the detected tone state changes.
  ///
  /// Called with `true` when a tone starts and `false` when it ends.
  /// Used by the decoder screen to drive side-tone audio feedback.
  final void Function(bool isTone)? onSideTone;

  DecoderService({this.onSideTone});

  final _recorder = AudioRecorder();
  final _detector = GoertzelDetector(
    sampleRate: _sampleRate,
    targetFrequency: MorseTiming.defaultFrequencyHz.toDouble(),
    frameSize: _frameSize,
  );

  StreamSubscription<Uint8List>? _audioSub;
  bool _isAudioRunning = false;

  final _byteBuffer = <int>[];
  final _magnitudes = <double>[];
  final _pcmBytes = <int>[];

  // Slow EMA for the live signal meter (no real threshold during recording).
  double _signalEma = 1e-10;
  int _signalFrameCount = 0;
  bool _prevIsTone = false;

  final _signalController = StreamController<SignalSnapshot>.broadcast();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Emits a [SignalSnapshot] ~10×/s during recording for the live signal meter.
  Stream<SignalSnapshot> get signalStream => _signalController.stream;

  /// Number of Goertzel frames accumulated so far.
  int get recordedFrameCount => _magnitudes.length;

  /// Returns true if the app has microphone permission.
  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Open the microphone and start buffering audio.
  ///
  /// Clears any previous recording. Monitor [signalStream] for live signal
  /// level. Call [stopListening] when done.
  Future<void> startListening() async {
    await _stopAudio();
    _byteBuffer.clear();
    _magnitudes.clear();
    _pcmBytes.clear();
    _signalEma = 1e-10;
    _signalFrameCount = 0;
    _prevIsTone = false;
    await _startAudio();
  }

  /// Close the microphone. Returns the number of frames captured.
  Future<int> stopListening() async {
    await _stopAudio();
    return _magnitudes.length;
  }

  /// Decode the recorded audio offline on a background isolate.
  ///
  /// Call after [stopListening]. Returns `(decodedText, confidence)`.
  ///
  /// Routes through [OfflineAnalyzer.analyzeWav] so the live recording path
  /// benefits from tone-frequency auto-detection (same as the file-open path).
  Future<(String, double)> analyzeRecording() {
    final wavBytes = buildRecordingWav();
    // 44 bytes = WAV header with no audio data.
    if (wavBytes.length <= 44) return Future.value(('', 0.0));
    return compute(runOfflineWavAnalysisIsolate, (wavBytes, null));
  }

  /// Build a WAV from the current recording buffer and return the raw bytes.
  ///
  /// Returns an empty [Uint8List] if nothing has been recorded yet.
  Uint8List buildRecordingWav() {
    if (_pcmBytes.isEmpty) return Uint8List(0);
    return _buildWav(Uint8List.fromList(_pcmBytes));
  }

  /// Write the recorded audio as a 16-bit mono PCM WAV to the temp directory
  /// and return the full file path, ready to be passed to [shareRecording].
  ///
  /// [filename] must not include the `.wav` extension or path separators.
  Future<String> saveRecording(String filename) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$filename.wav';
    final wav = _buildWav(Uint8List.fromList(_pcmBytes));
    await File(path).writeAsBytes(wav);
    return path;
  }

  /// Share a WAV file via the platform share sheet.
  ///
  /// [path] is the full file path returned by [saveRecording].
  /// On Android the user can choose Downloads / My Files; on iOS they can
  /// choose Files or AirDrop — the share sheet is the correct store-safe API
  /// for saving to a user-visible location.
  Future<void> shareRecording(String path) async {
    await Share.shareXFiles(
      [XFile(path, mimeType: 'audio/wav')],
      subject: 'Morse Recording',
    );
  }

  /// Decode Morse from a WAV file's raw bytes.
  ///
  /// Delegates all parsing (mono/stereo, any sample rate) and analysis to
  /// [OfflineAnalyzer.analyzeWav] running on a background isolate.
  /// Tone frequency is auto-detected — no need to know the recording's CW
  /// frequency in advance.
  /// Returns `(decodedText, confidence)`.
  Future<(String, double)> analyzeWavFile(Uint8List wavBytes) {
    // ignore: avoid_print
    print('[MorseDbg] analyzeWavFile: ${wavBytes.length} bytes');
    return compute(runOfflineWavAnalysisIsolate, (wavBytes, null));
  }

  /// Release all resources. Call once when this service is no longer needed.
  Future<void> dispose() async {
    await _stopAudio();
    await _signalController.close();
    await _recorder.dispose();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _startAudio() async {
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
        // Use the unprocessed audio source on Android to bypass the system's
        // Noise Suppressor (NS) and Automatic Gain Control (AGC).  These
        // voice-optimised effects suppress periodic tones (treating them as
        // "noise") and pump gain during silence, both of which corrupt Morse
        // timing and amplitude — making calibration and threshold detection
        // unreliable.  Requires Android N (API 24+).
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.unprocessed,
        ),
      ),
    );
    _audioSub = stream.listen(_onBytes);
    _isAudioRunning = true;
  }

  Future<void> _stopAudio() async {
    if (!_isAudioRunning) return;
    _isAudioRunning = false;
    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder.stop();
    // If the tone was active when recording stopped, explicitly signal its end
    // so the side-tone player is stopped rather than left buzzing.
    if (_prevIsTone && onSideTone != null) {
      _prevIsTone = false;
      onSideTone!(false);
    }
  }

  void _onBytes(Uint8List bytes) {
    _pcmBytes.addAll(bytes);
    _byteBuffer.addAll(bytes);
    const bytesPerFrame = _frameSize * 2; // 16-bit = 2 bytes/sample
    while (_byteBuffer.length >= bytesPerFrame) {
      final chunk =
          Uint8List.fromList(_byteBuffer.sublist(0, bytesPerFrame));
      _byteBuffer.removeRange(0, bytesPerFrame);
      final frames = GoertzelDetector.framesFromPcm16(
          chunk.buffer.asInt16List(), _frameSize);
      if (frames.isNotEmpty) {
        final power = _detector.computePower(frames.first);
        _magnitudes.add(power);
        _emitSignal(power);
      }
    }
  }

  void _emitSignal(double power) {
    _signalEma = _signalEma * 0.97 + power * 0.03;
    _signalFrameCount++;
    final ref = max(_signalEma, 1e-10);
    final isTone = power > ref * 3;

    // Side-tone: notify on tone state change every frame.
    if (onSideTone != null && isTone != _prevIsTone) {
      _prevIsTone = isTone;
      onSideTone!(isTone);
    }

    if (_signalFrameCount % 8 == 0 && !_signalController.isClosed) {
      _signalController.add(SignalSnapshot(
        power: power,
        noiseFloor: ref,
        isTone: isTone,
      ));
    }
  }

  // ── WAV parser ─────────────────────────────────────────────────────────────

  // ── WAV builder ────────────────────────────────────────────────────────────

  static Uint8List _buildWav(Uint8List pcmBytes) {
    final dataLen = pcmBytes.length;
    final header = ByteData(44);

    _setFourCC(header, 0, 0x52494646); // 'RIFF'
    header.setUint32(4, 36 + dataLen, Endian.little);
    _setFourCC(header, 8, 0x57415645); // 'WAVE'

    _setFourCC(header, 12, 0x666d7420); // 'fmt '
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, 1, Endian.little); // mono
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(28, _sampleRate * 2, Endian.little); // byte rate
    header.setUint16(32, 2, Endian.little); // block align
    header.setUint16(34, 16, Endian.little); // bits per sample

    _setFourCC(header, 36, 0x64617461); // 'data'
    header.setUint32(40, dataLen, Endian.little);

    final result = Uint8List(44 + dataLen);
    result.setAll(0, header.buffer.asUint8List());
    result.setAll(44, pcmBytes);
    return result;
  }

  static void _setFourCC(ByteData data, int offset, int value) {
    data.setUint8(offset, (value >> 24) & 0xFF);
    data.setUint8(offset + 1, (value >> 16) & 0xFF);
    data.setUint8(offset + 2, (value >> 8) & 0xFF);
    data.setUint8(offset + 3, value & 0xFF);
  }
}
