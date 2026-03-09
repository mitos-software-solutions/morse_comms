import 'dart:math';
import 'dart:typed_data';

/// Goertzel algorithm — efficient single-bin DFT for tone detection.
///
/// Detects the presence of [targetFrequency] in a fixed-size audio frame.
/// Far cheaper than FFT when only one frequency matters.
///
/// Typical setup for Morse decoding:
///   - sampleRate: 44100 or 16000 Hz
///   - targetFrequency: 700 Hz (standard Morse tone)
///   - frameSize: 1024 samples @ 44100 Hz ≈ 23 ms per frame
///               (≥ 2 frames per dot at 25 WPM)
class GoertzelDetector {
  final int sampleRate;
  final double targetFrequency;
  final int frameSize;

  late final double _coeff;

  GoertzelDetector({
    required this.sampleRate,
    required this.targetFrequency,
    required this.frameSize,
  }) {
    final k = (frameSize * targetFrequency / sampleRate).round();
    final omega = 2.0 * pi * k / frameSize;
    _coeff = 2.0 * cos(omega);
  }

  /// Duration of one audio frame in milliseconds.
  double get frameDurationMs => frameSize / sampleRate * 1000.0;

  /// Compute the Goertzel power for [samples] at [targetFrequency].
  ///
  /// [samples] must have exactly [frameSize] elements, normalized to [-1.0, 1.0].
  /// Returns a non-negative power value; compare against a calibrated threshold
  /// to decide whether the tone is present.
  double computePower(Float64List samples) {
    assert(samples.length == frameSize,
        'Expected $frameSize samples, got ${samples.length}');

    double s1 = 0.0;
    double s2 = 0.0;

    for (int i = 0; i < samples.length; i++) {
      final s0 = samples[i] + _coeff * s1 - s2;
      s2 = s1;
      s1 = s0;
    }

    return s1 * s1 + s2 * s2 - _coeff * s1 * s2;
  }

  /// Normalize a PCM-16 buffer (raw Android AudioRecord output) to [-1.0, 1.0].
  ///
  /// Splits the flat [bytes] into [frameSize]-length Float64 frames ready for
  /// [computePower]. Extra samples that don't fill a full frame are discarded.
  static List<Float64List> framesFromPcm16(
    Int16List pcm,
    int frameSize,
  ) {
    final frameCount = pcm.length ~/ frameSize;
    return List.generate(frameCount, (fi) {
      final start = fi * frameSize;
      final frame = Float64List(frameSize);
      for (int i = 0; i < frameSize; i++) {
        frame[i] = pcm[start + i] / 32768.0;
      }
      return frame;
    });
  }
}
