import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
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

  /// Decode the recorded magnitudes offline on a background isolate.
  ///
  /// Call after [stopListening]. Returns the decoded Morse text.
  Future<String> analyzeRecording() {
    final mags = List<double>.from(_magnitudes);
    final dur = _detector.frameDurationMs;
    return compute(runOfflineAnalysisIsolate, (mags, dur));
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
  /// Parses the WAV header, extracts PCM samples, runs Goertzel on each frame,
  /// then runs the offline analyzer on a background isolate.
  /// Returns the decoded text, or an empty string on failure.
  Future<String> analyzeWavFile(Uint8List wavBytes) async {
    final parsed = _parseWavPcm(wavBytes);
    if (parsed == null) return '';
    final (pcm, sampleRate) = parsed;

    // Use a detector tuned to the file's sample rate (handles recordings from
    // other apps / sample rates other than the default 44100 Hz).
    final detector = sampleRate == _sampleRate
        ? _detector
        : GoertzelDetector(
            sampleRate: sampleRate,
            targetFrequency: MorseTiming.defaultFrequencyHz.toDouble(),
            frameSize: _frameSize,
          );

    final frames = GoertzelDetector.framesFromPcm16(pcm, _frameSize);
    final magnitudes = frames.map((f) => detector.computePower(f)).toList();
    return compute(
        runOfflineAnalysisIsolate, (magnitudes, detector.frameDurationMs));
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

  /// Parses a WAV file and returns `(pcmSamples, sampleRate)`, or null if the
  /// file is not a valid 16-bit mono PCM WAV.
  static (Int16List pcm, int sampleRate)? _parseWavPcm(Uint8List bytes) {
    if (bytes.length < 44) return null;
    // RIFF header
    if (bytes[0] != 0x52 || bytes[1] != 0x49 ||
        bytes[2] != 0x46 || bytes[3] != 0x46) {
      return null;
    }
    // WAVE marker
    if (bytes[8] != 0x57 || bytes[9] != 0x41 ||
        bytes[10] != 0x56 || bytes[11] != 0x45) {
      return null;
    }

    final bd = ByteData.view(bytes.buffer);
    final sampleRate = bd.getUint32(24, Endian.little);

    // Walk chunks after the RIFF/WAVE header to find the 'data' chunk.
    int offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = bd.getUint32(offset + 4, Endian.little);
      if (id == 'data') {
        final end = (offset + 8 + chunkSize).clamp(0, bytes.length);
        final pcmBytes = bytes.sublist(offset + 8, end);
        return (pcmBytes.buffer.asInt16List(), sampleRate);
      }
      offset += 8 + chunkSize;
      if (chunkSize.isOdd) offset++; // RIFF pads odd-sized chunks
    }
    return null;
  }

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
