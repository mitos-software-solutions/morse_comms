import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/core/dsp/goertzel.dart';

/// Generate a pure sine wave at [freq] Hz.
Float64List _sine(double freq, int sampleRate, int samples, {double amplitude = 1.0}) {
  final out = Float64List(samples);
  for (int i = 0; i < samples; i++) {
    out[i] = amplitude * sin(2 * pi * freq * i / sampleRate);
  }
  return out;
}

/// Generate white noise in [-amplitude, amplitude].
Float64List _noise(int samples, {double amplitude = 0.05, int seed = 42}) {
  final rng = Random(seed);
  final out = Float64List(samples);
  for (int i = 0; i < samples; i++) {
    out[i] = (rng.nextDouble() * 2 - 1) * amplitude;
  }
  return out;
}

void main() {
  const sampleRate = 44100;
  const frameSize = 1024;
  const targetHz = 700.0;

  final detector = GoertzelDetector(
    sampleRate: sampleRate,
    targetFrequency: targetHz,
    frameSize: frameSize,
  );

  group('GoertzelDetector — frequency detection', () {
    test('high power for exact target frequency', () {
      final frame = _sine(targetHz, sampleRate, frameSize);
      final power = detector.computePower(frame);
      expect(power, greaterThan(100.0));
    });

    test('low power for silence (all zeros)', () {
      final frame = Float64List(frameSize); // all zeros
      final power = detector.computePower(frame);
      expect(power, lessThan(1e-6));
    });

    test('low power for unrelated frequency (440 Hz)', () {
      final frame = _sine(440.0, sampleRate, frameSize);
      final power440 = detector.computePower(frame);
      final powerTarget = detector.computePower(_sine(targetHz, sampleRate, frameSize));
      // Target should be at least 100x stronger than an unrelated tone.
      expect(powerTarget, greaterThan(power440 * 100));
    });

    test('low power for noise well below signal', () {
      final signal = _sine(targetHz, sampleRate, frameSize);
      final noiseOnly = _noise(frameSize, amplitude: 0.02);
      final powerSignal = detector.computePower(signal);
      final powerNoise = detector.computePower(noiseOnly);
      expect(powerSignal, greaterThan(powerNoise * 50));
    });

    test('power scales with amplitude squared', () {
      final strong = _sine(targetHz, sampleRate, frameSize, amplitude: 1.0);
      final weak   = _sine(targetHz, sampleRate, frameSize, amplitude: 0.5);
      final ratio  = detector.computePower(strong) / detector.computePower(weak);
      // Goertzel power is quadratic in amplitude: expect ratio ≈ 4.
      expect(ratio, closeTo(4.0, 0.5));
    });
  });

  group('GoertzelDetector — frame duration', () {
    test('frameDurationMs is correct for 44100 / 1024', () {
      expect(detector.frameDurationMs, closeTo(23.22, 0.01));
    });

    test('at 16000 Hz / 512 samples = 32 ms per frame', () {
      final d = GoertzelDetector(
        sampleRate: 16000,
        targetFrequency: 700.0,
        frameSize: 512,
      );
      expect(d.frameDurationMs, closeTo(32.0, 0.1));
    });
  });

  group('GoertzelDetector.framesFromPcm16', () {
    test('splits flat PCM16 into correct number of frames', () {
      // 3 frames of 1024 samples = 3072 samples
      final pcm = Int16List(3072);
      final frames = GoertzelDetector.framesFromPcm16(pcm, 1024);
      expect(frames.length, 3);
      expect(frames[0].length, 1024);
    });

    test('partial final frame is discarded', () {
      final pcm = Int16List(2500); // 2 full frames + 452 leftover
      final frames = GoertzelDetector.framesFromPcm16(pcm, 1024);
      expect(frames.length, 2);
    });

    test('normalises PCM16 max value to ~1.0', () {
      final pcm = Int16List(1024);
      pcm[0] = 32767; // max positive int16
      final frames = GoertzelDetector.framesFromPcm16(pcm, 1024);
      expect(frames[0][0], closeTo(1.0, 0.0001));
    });

    test('normalises PCM16 min value to ~-1.0', () {
      final pcm = Int16List(1024);
      pcm[0] = -32768; // min int16
      final frames = GoertzelDetector.framesFromPcm16(pcm, 1024);
      expect(frames[0][0], closeTo(-1.0, 0.0001));
    });
  });
}
