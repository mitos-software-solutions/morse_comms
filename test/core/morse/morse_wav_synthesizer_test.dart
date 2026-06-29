import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/core/dsp/goertzel.dart';
import 'package:morse_comms/core/dsp/offline_analyzer.dart';
import 'package:morse_comms/core/morse/morse_encoder.dart';
import 'package:morse_comms/core/morse/morse_timing.dart';
import 'package:morse_comms/core/morse/morse_wav_synthesizer.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Reads a little-endian uint32 from raw WAV bytes at [offset].
int _u32(Uint8List b, int offset) =>
    ByteData.view(b.buffer).getUint32(offset, Endian.little);

/// Reads a little-endian uint16 from raw WAV bytes at [offset].
int _u16(Uint8List b, int offset) =>
    ByteData.view(b.buffer).getUint16(offset, Endian.little);

/// Extracts the PCM Int16 samples from a synthesized WAV (strips 44-byte header).
Int16List _extractPcm(Uint8List wav) {
  final pcmBytes = wav.sublist(44);
  final bd = ByteData.view(pcmBytes.buffer);
  return Int16List.fromList(
    List.generate(pcmBytes.length ~/ 2, (i) => bd.getInt16(i * 2, Endian.little)),
  );
}

/// Expected sample count for a given duration.
int _samples(int ms) =>
    (ms * MorseWavSynthesizer.sampleRate / 1000).round();

/// Encodes [text] at [wpm] WPM and returns the tone list.
List<MorseTone> _tones(String text, {int wpm = 20}) =>
    MorseEncoder(timing: MorseTiming(wpm: wpm)).encode(text).tones;

/// Synthesizes [text] and decodes it via [OfflineAnalyzer.analyzeWav].
String _roundTrip(
  String text, {
  int wpm = 20,
  int freqHz = 700,
  bool autoDetect = false,
}) {
  final wav = MorseWavSynthesizer.synthesize(_tones(text, wpm: wpm), freqHz);
  final (decoded, _) = OfflineAnalyzer.analyzeWav(
    wav,
    targetFrequencyHz: autoDetect ? null : freqHz.toDouble(),
  );
  return decoded.trim().replaceAll(RegExp(r'\s+'), ' ');
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ── 1. WAV header validity ──────────────────────────────────────────────────

  group('WAV header — magic bytes and fixed fields', () {
    late Uint8List wav;
    setUpAll(() => wav = MorseWavSynthesizer.synthesize(_tones('SOS'), 700));

    test('starts with RIFF', () {
      expect(wav[0], 0x52);
      expect(wav[1], 0x49);
      expect(wav[2], 0x46);
      expect(wav[3], 0x46);
    });

    test('bytes 8–11 = WAVE', () {
      expect(wav[8], 0x57);
      expect(wav[9], 0x41);
      expect(wav[10], 0x56);
      expect(wav[11], 0x45);
    });

    test('bytes 12–15 = fmt ', () {
      expect(wav[12], 0x66);
      expect(wav[13], 0x6D);
      expect(wav[14], 0x74);
      expect(wav[15], 0x20);
    });

    test('PCM subchunk size = 16', () => expect(_u32(wav, 16), 16));
    test('AudioFormat = 1 (PCM)',   () => expect(_u16(wav, 20), 1));
    test('NumChannels = 1 (mono)',  () => expect(_u16(wav, 22), 1));
    test('SampleRate = 44100',      () => expect(_u32(wav, 24), 44100));
    test('ByteRate = 88200',        () => expect(_u32(wav, 28), 88200));
    test('BlockAlign = 2',          () => expect(_u16(wav, 32), 2));
    test('BitsPerSample = 16',      () => expect(_u16(wav, 34), 16));

    test('bytes 36–39 = data', () {
      expect(wav[36], 0x64);
      expect(wav[37], 0x61);
      expect(wav[38], 0x74);
      expect(wav[39], 0x61);
    });

    test('RIFF chunk size = totalBytes − 8', () {
      expect(_u32(wav, 4), wav.length - 8);
    });

    test('data chunk size = totalBytes − 44', () {
      expect(_u32(wav, 40), wav.length - 44);
    });

    test('total size ≥ 44 bytes', () => expect(wav.length, greaterThanOrEqualTo(44)));
  });

  // ── 2. Leading and trailing silence ────────────────────────────────────────

  group('Leading and trailing silence', () {
    test('first 100 ms of PCM are noise-level only', () {
      final pcm = _extractPcm(MorseWavSynthesizer.synthesize(_tones('SOS'), 700));
      final leadSamples = _samples(MorseWavSynthesizer.leadingMs);
      final maxAbs = pcm.take(leadSamples).map((s) => s.abs()).reduce(max);
      expect(maxAbs, lessThanOrEqualTo(MorseWavSynthesizer.noiseAmplitude * 3));
    });

    test('last 250 ms of PCM are noise-level only', () {
      final pcm = _extractPcm(MorseWavSynthesizer.synthesize(_tones('SOS'), 700));
      final trailSamples = _samples(MorseWavSynthesizer.trailingMs);
      final maxAbs = pcm.skip(pcm.length - trailSamples).map((s) => s.abs()).reduce(max);
      expect(maxAbs, lessThanOrEqualTo(MorseWavSynthesizer.noiseAmplitude * 3));
    });

    test('empty tone list: total PCM duration = leadingMs + trailingMs', () {
      final wav = MorseWavSynthesizer.synthesize([], 700);
      final expectedSamples = _samples(MorseWavSynthesizer.leadingMs) +
          _samples(MorseWavSynthesizer.trailingMs);
      expect(_extractPcm(wav).length, expectedSamples);
    });

    test('leading silence sample count is exact', () {
      final pcm = _extractPcm(MorseWavSynthesizer.synthesize(_tones('E'), 700));
      // The dot starts at _samples(leadingMs); check the boundary.
      final lead = _samples(MorseWavSynthesizer.leadingMs);
      final beforeDot = pcm.take(lead).map((s) => s.abs()).reduce(max);
      expect(beforeDot, lessThanOrEqualTo(MorseWavSynthesizer.noiseAmplitude * 3));
    });

    test('trailing silence sample count is exact', () {
      final wav = MorseWavSynthesizer.synthesize([], 700);
      expect(
        _extractPcm(wav).length,
        _samples(MorseWavSynthesizer.leadingMs) +
            _samples(MorseWavSynthesizer.trailingMs),
      );
    });
  });

  // ── 3. Noise floor in silence ───────────────────────────────────────────────

  group('Noise floor', () {
    test('silence RMS > 0 (noise present, not pure zeros)', () {
      final wav = MorseWavSynthesizer.synthesize([], 700);
      final pcm = _extractPcm(wav);
      final sumSq = pcm.fold<double>(0.0, (acc, s) => acc + s * s);
      final rms = sqrt(sumSq / pcm.length);
      expect(rms, greaterThan(0.0));
    });

    test('silence max absolute sample ≤ noiseAmplitude × 3', () {
      final wav = MorseWavSynthesizer.synthesize([], 700);
      final pcm = _extractPcm(wav);
      final maxAbs = pcm.map((s) => s.abs()).reduce(max);
      expect(maxAbs, lessThanOrEqualTo(MorseWavSynthesizer.noiseAmplitude * 3));
    });

    test('silence RMS is at least 100× smaller than tone RMS', () {
      const durationMs = 500;
      final toneWav = MorseWavSynthesizer.synthesize(
        [MorseTone(on: true, durationMs: durationMs)],
        700,
      );
      final silenceWav = MorseWavSynthesizer.synthesize(
        [MorseTone(on: false, durationMs: durationMs)],
        700,
      );

      double rms(Int16List pcm) {
        final s = _samples(MorseWavSynthesizer.leadingMs);
        final e = s + _samples(durationMs);
        final slice = pcm.sublist(s, e);
        return sqrt(slice.fold<double>(0.0, (a, v) => a + v * v) / slice.length);
      }

      final toneRms = rms(_extractPcm(toneWav));
      final silenceRms = rms(_extractPcm(silenceWav));
      expect(toneRms / silenceRms, greaterThan(100));
    });

    test('p33 of Goertzel powers > 0 (prevents threshold collapse)', () {
      // A WAV with mixed on/off events — p33 should land on a silence frame.
      final wav = MorseWavSynthesizer.synthesize(_tones('SOS'), 700);
      final pcm = _extractPcm(wav);

      const frameSize = 512;
      final detector = GoertzelDetector(
        sampleRate: 44100,
        targetFrequency: 700.0,
        frameSize: frameSize,
      );
      final frames = GoertzelDetector.framesFromPcm16(pcm, frameSize);
      final powers = frames.map((f) => detector.computePower(f)).toList()..sort();
      final p33 = powers[powers.length ~/ 3];

      expect(p33, greaterThan(0.0));
    });
  });

  // ── 4. Tone content ─────────────────────────────────────────────────────────

  group('Tone content', () {
    test('on-tone section has non-zero samples beyond noise level', () {
      const durationMs = 300;
      final wav = MorseWavSynthesizer.synthesize(
        [MorseTone(on: true, durationMs: durationMs)],
        700,
      );
      final pcm = _extractPcm(wav);
      // Sample the middle of the tone (past the fade-in, before fade-out).
      final start = _samples(MorseWavSynthesizer.leadingMs) +
          MorseWavSynthesizer.fadeSamples + 10;
      final end = start + 100;
      final maxAbs = pcm.sublist(start, end).map((s) => s.abs()).reduce(max);
      expect(maxAbs, greaterThan(MorseWavSynthesizer.noiseAmplitude * 10));
    });

    test('off-tone section stays at noise level', () {
      const durationMs = 300;
      final wav = MorseWavSynthesizer.synthesize(
        [MorseTone(on: false, durationMs: durationMs)],
        700,
      );
      final pcm = _extractPcm(wav);
      final start = _samples(MorseWavSynthesizer.leadingMs);
      final end = start + _samples(durationMs);
      final maxAbs = pcm.sublist(start, end).map((s) => s.abs()).reduce(max);
      expect(maxAbs, lessThanOrEqualTo(MorseWavSynthesizer.noiseAmplitude * 3));
    });

    test('on-tone peak amplitude is close to synthesizer amplitude', () {
      const durationMs = 500;
      final wav = MorseWavSynthesizer.synthesize(
        [MorseTone(on: true, durationMs: durationMs)],
        700,
      );
      final pcm = _extractPcm(wav);
      // Middle of the tone (fully faded in).
      final midStart = _samples(MorseWavSynthesizer.leadingMs) + _samples(durationMs) ~/ 2 - 100;
      final peak = pcm.sublist(midStart, midStart + 200).map((s) => s.abs()).reduce(max);
      expect(peak.toDouble(), closeTo(MorseWavSynthesizer.amplitude, 2000));
    });

    test('on-tone sample count matches durationMs', () {
      const durationMs = 180;
      final wav = MorseWavSynthesizer.synthesize(
        [MorseTone(on: true, durationMs: durationMs)],
        700,
      );
      final pcm = _extractPcm(wav);
      final expectedTotal = _samples(MorseWavSynthesizer.leadingMs) +
          _samples(durationMs) +
          _samples(MorseWavSynthesizer.trailingMs);
      expect(pcm.length, expectedTotal);
    });

    test('off-tone sample count matches durationMs', () {
      const durationMs = 120;
      final wav = MorseWavSynthesizer.synthesize(
        [MorseTone(on: false, durationMs: durationMs)],
        700,
      );
      final pcm = _extractPcm(wav);
      final expectedTotal = _samples(MorseWavSynthesizer.leadingMs) +
          _samples(durationMs) +
          _samples(MorseWavSynthesizer.trailingMs);
      expect(pcm.length, expectedTotal);
    });

    test('total PCM length = leading + sum(tones) + trailing', () {
      final toneList = _tones('HELLO', wpm: 20);
      final wav = MorseWavSynthesizer.synthesize(toneList, 700);
      final pcm = _extractPcm(wav);
      final sumTones = toneList.fold(0, (s, t) => s + _samples(t.durationMs));
      expect(
        pcm.length,
        _samples(MorseWavSynthesizer.leadingMs) +
            sumTones +
            _samples(MorseWavSynthesizer.trailingMs),
      );
    });

    test('all-off tones: no sample exceeds noise threshold', () {
      final toneList = List.generate(
        5,
        (_) => const MorseTone(on: false, durationMs: 100),
      );
      final pcm = _extractPcm(MorseWavSynthesizer.synthesize(toneList, 700));
      final maxAbs = pcm.map((s) => s.abs()).reduce(max);
      expect(maxAbs, lessThanOrEqualTo(MorseWavSynthesizer.noiseAmplitude * 3));
    });

    test('multi-tone: on/off sections alternate correctly', () {
      final toneList = [
        const MorseTone(on: false, durationMs: 100),
        const MorseTone(on: true,  durationMs: 150),
        const MorseTone(on: false, durationMs: 100),
        const MorseTone(on: true,  durationMs: 150),
      ];
      final wav = MorseWavSynthesizer.synthesize(toneList, 700);
      final pcm = _extractPcm(wav);

      int pos = _samples(MorseWavSynthesizer.leadingMs);

      for (final t in toneList) {
        final n = _samples(t.durationMs);
        final mid = pos + n ~/ 2;
        final midAbs = pcm[mid].abs();
        if (t.on) {
          expect(midAbs, greaterThan(MorseWavSynthesizer.noiseAmplitude * 10),
              reason: 'on-tone mid-sample should be loud');
        } else {
          expect(midAbs, lessThanOrEqualTo(MorseWavSynthesizer.noiseAmplitude * 3),
              reason: 'off-tone mid-sample should be quiet');
        }
        pos += n;
      }
    });
  });

  // ── 5. Fade envelope ────────────────────────────────────────────────────────

  group('Fade envelope', () {
    late Int16List pcm;
    late int toneStart;
    const durationMs = 500;

    setUpAll(() {
      final wav = MorseWavSynthesizer.synthesize(
        [MorseTone(on: true, durationMs: durationMs)],
        700,
      );
      pcm = _extractPcm(wav);
      toneStart = _samples(MorseWavSynthesizer.leadingMs);
    });

    double rmsOf(Iterable<int> samples) {
      final list = samples.toList();
      return sqrt(list.fold<double>(0, (a, v) => a + v * v) / list.length);
    }

    test('fade-in: RMS of first fadeSamples < RMS of tone middle', () {
      final fadeRms = rmsOf(pcm.sublist(toneStart, toneStart + MorseWavSynthesizer.fadeSamples));
      final midStart = toneStart + _samples(durationMs) ~/ 2 - MorseWavSynthesizer.fadeSamples ~/ 2;
      final midRms = rmsOf(pcm.sublist(midStart, midStart + MorseWavSynthesizer.fadeSamples));
      expect(fadeRms, lessThan(midRms));
    });

    test('fade-out: RMS of last fadeSamples < RMS of tone middle', () {
      final toneEnd = toneStart + _samples(durationMs);
      final fadeRms = rmsOf(pcm.sublist(toneEnd - MorseWavSynthesizer.fadeSamples, toneEnd));
      final midStart = toneStart + _samples(durationMs) ~/ 2 - MorseWavSynthesizer.fadeSamples ~/ 2;
      final midRms = rmsOf(pcm.sublist(midStart, midStart + MorseWavSynthesizer.fadeSamples));
      expect(fadeRms, lessThan(midRms));
    });

    test('first sample of on-tone is near-zero (ramp starts low)', () {
      final firstSample = pcm[toneStart].abs();
      expect(firstSample.toDouble(),
          lessThan(MorseWavSynthesizer.amplitude / 2));
    });

    test('very short on-tone (< 2 × fadeSamples) synthesizes without error', () {
      const shortMs = 5; // only ~220 samples — less than 2 × 220
      expect(
        () => MorseWavSynthesizer.synthesize(
          [MorseTone(on: true, durationMs: shortMs)],
          700,
        ),
        returnsNormally,
      );
    });

    test('fade envelope is monotonically increasing at tone start', () {
      // Compare RMS across three windows: [0, fade/3], [fade/3, 2*fade/3], [2*fade/3, fade].
      final third = MorseWavSynthesizer.fadeSamples ~/ 3;
      final rms0 = rmsOf(pcm.sublist(toneStart, toneStart + third));
      final rms1 = rmsOf(pcm.sublist(toneStart + third, toneStart + 2 * third));
      final rms2 = rmsOf(pcm.sublist(toneStart + 2 * third, toneStart + 3 * third));
      expect(rms0, lessThan(rms1));
      expect(rms1, lessThan(rms2));
    });
  });

  // ── 6. Frequency accuracy ───────────────────────────────────────────────────

  group('Frequency accuracy', () {
    int zeroCrossings(Int16List pcm, int start, int count) {
      int crossings = 0;
      for (int i = start + 1; i < start + count; i++) {
        if ((pcm[i - 1] >= 0) != (pcm[i] >= 0)) crossings++;
      }
      return crossings;
    }

    test('zero-crossing rate at 700 Hz ≈ 1400/s', () {
      const durationMs = 200; // enough cycles for accurate count
      final pcm = _extractPcm(MorseWavSynthesizer.synthesize(
        [MorseTone(on: true, durationMs: durationMs)],
        700,
      ));
      final start = _samples(MorseWavSynthesizer.leadingMs) + MorseWavSynthesizer.fadeSamples;
      final count = _samples(durationMs) - 2 * MorseWavSynthesizer.fadeSamples;
      final zc = zeroCrossings(pcm, start, count);
      final rate = zc / (durationMs / 1000.0 - 2 * MorseWavSynthesizer.fadeSamples / 44100.0);
      expect(rate, closeTo(1400, 100)); // ±100 tolerance
    });

    test('400 Hz has fewer zero crossings than 700 Hz', () {
      const durationMs = 300;
      Int16List pcmFor(int freq) {
        return _extractPcm(MorseWavSynthesizer.synthesize(
          [MorseTone(on: true, durationMs: durationMs)],
          freq,
        ));
      }
      final pcm400 = pcmFor(400);
      final pcm700 = pcmFor(700);
      final start = _samples(MorseWavSynthesizer.leadingMs) + MorseWavSynthesizer.fadeSamples;
      final count = _samples(durationMs) - 2 * MorseWavSynthesizer.fadeSamples;
      expect(
        zeroCrossings(pcm400, start, count),
        lessThan(zeroCrossings(pcm700, start, count)),
      );
    });

    test('900 Hz has more zero crossings than 700 Hz', () {
      const durationMs = 300;
      Int16List pcmFor(int freq) {
        return _extractPcm(MorseWavSynthesizer.synthesize(
          [MorseTone(on: true, durationMs: durationMs)],
          freq,
        ));
      }
      final pcm700 = pcmFor(700);
      final pcm900 = pcmFor(900);
      final start = _samples(MorseWavSynthesizer.leadingMs) + MorseWavSynthesizer.fadeSamples;
      final count = _samples(durationMs) - 2 * MorseWavSynthesizer.fadeSamples;
      expect(
        zeroCrossings(pcm900, start, count),
        greaterThan(zeroCrossings(pcm700, start, count)),
      );
    });

    test('period between peaks matches sampleRate / frequencyHz', () {
      const freqHz = 700;
      const durationMs = 100;
      final pcm = _extractPcm(MorseWavSynthesizer.synthesize(
        [MorseTone(on: true, durationMs: durationMs)],
        freqHz,
      ));
      final expectedPeriod = MorseWavSynthesizer.sampleRate / freqHz; // ~63 samples
      // Find consecutive positive peaks in the middle of the tone.
      final start = _samples(MorseWavSynthesizer.leadingMs) + MorseWavSynthesizer.fadeSamples;
      final peaks = <int>[];
      for (int i = start + 1; i < start + _samples(durationMs) - 1 && peaks.length < 5; i++) {
        if (pcm[i] > pcm[i - 1] && pcm[i] > pcm[i + 1] && pcm[i].abs() > 5000) {
          peaks.add(i);
        }
      }
      expect(peaks.length, greaterThanOrEqualTo(2));
      final measuredPeriod = (peaks.last - peaks.first) / (peaks.length - 1);
      expect(measuredPeriod, closeTo(expectedPeriod, 3.0));
    });
  });

  // ── 7. Timing accuracy ──────────────────────────────────────────────────────

  group('Timing accuracy', () {
    test('dot at 20 WPM has expected sample count (dotMs = 60)', () {
      const wpm = 20;
      final dotMs = MorseTiming(wpm: wpm).dotMs;
      final wav = MorseWavSynthesizer.synthesize(
        [MorseTone(on: true, durationMs: dotMs)],
        700,
      );
      final pcm = _extractPcm(wav);
      expect(
        pcm.length,
        _samples(MorseWavSynthesizer.leadingMs) +
            _samples(dotMs) +
            _samples(MorseWavSynthesizer.trailingMs),
      );
    });

    test('dash at 20 WPM has 3× the dot sample count', () {
      const wpm = 20;
      final timing = MorseTiming(wpm: wpm);
      int toneSamples(int durationMs) {
        final wav = MorseWavSynthesizer.synthesize(
          [MorseTone(on: true, durationMs: durationMs)],
          700,
        );
        return _extractPcm(wav).length -
            _samples(MorseWavSynthesizer.leadingMs) -
            _samples(MorseWavSynthesizer.trailingMs);
      }
      expect(toneSamples(timing.dashMs), 3 * toneSamples(timing.dotMs));
    });

    test('total samples match formula: leading + sum(tones) + trailing', () {
      final toneList = _tones('PARIS', wpm: 15);
      final wav = MorseWavSynthesizer.synthesize(toneList, 700);
      final pcm = _extractPcm(wav);
      final sumTones = toneList.fold(0, (s, t) => s + _samples(t.durationMs));
      expect(
        pcm.length,
        _samples(MorseWavSynthesizer.leadingMs) +
            sumTones +
            _samples(MorseWavSynthesizer.trailingMs),
      );
    });

    test('dot at 5 WPM (dotMs = 240) has correct sample count', () {
      const wpm = 5;
      final dotMs = MorseTiming(wpm: wpm).dotMs;
      final wav = MorseWavSynthesizer.synthesize(
        [MorseTone(on: true, durationMs: dotMs)],
        700,
      );
      final pcm = _extractPcm(wav);
      expect(
        pcm.length,
        _samples(MorseWavSynthesizer.leadingMs) +
            _samples(dotMs) +
            _samples(MorseWavSynthesizer.trailingMs),
      );
    });
  });

  // ── 8. Edge cases ───────────────────────────────────────────────────────────

  group('Edge cases', () {
    test('empty tone list returns a parseable WAV', () {
      final wav = MorseWavSynthesizer.synthesize([], 700);
      expect(wav.length, greaterThanOrEqualTo(44));
      // OfflineAnalyzer should not throw on an empty-content WAV.
      expect(
        () => OfflineAnalyzer.analyzeWav(wav, targetFrequencyHz: 700),
        returnsNormally,
      );
    });

    test('single on-tone WAV is valid (header parseable)', () {
      final wav = MorseWavSynthesizer.synthesize(
        [const MorseTone(on: true, durationMs: 100)],
        700,
      );
      expect(_u16(wav, 20), 1); // PCM format — header is intact
      expect(wav.length, greaterThan(44));
    });

    test('100-character message produces no integer overflow', () {
      final longText = 'PARIS ' * 16; // 96+ chars
      expect(
        () => MorseWavSynthesizer.synthesize(_tones(longText.trim()), 700),
        returnsNormally,
      );
    });

    test('all-off tones produce valid WAV', () {
      final toneList = List.generate(10, (_) => const MorseTone(on: false, durationMs: 50));
      final wav = MorseWavSynthesizer.synthesize(toneList, 700);
      expect(_u32(wav, 4), wav.length - 8); // RIFF size still correct
    });

    test('minimum WPM (5): valid WAV with long tones', () {
      expect(
        () => MorseWavSynthesizer.synthesize(_tones('SOS', wpm: 5), 700),
        returnsNormally,
      );
    });

    test('maximum WPM (40): valid WAV with short tones, no zero-length sections', () {
      final toneList = _tones('SOS', wpm: 40);
      final wav = MorseWavSynthesizer.synthesize(toneList, 700);
      expect(wav.length, greaterThan(44));
      // Every tone at 40 WPM has dotMs = 30ms > 0.
      for (final t in toneList) {
        expect(t.durationMs, greaterThan(0));
      }
    });
  });

  // ── 9. OfflineAnalyzer integration ─────────────────────────────────────────

  group('OfflineAnalyzer integration — synthesize → decode round-trip', () {
    // WPM sweep
    for (final wpm in [5, 10, 15, 20, 25]) {
      test('SOS at $wpm WPM decodes correctly', () {
        expect(_roundTrip('SOS', wpm: wpm), 'SOS');
      });
    }

    // Single characters (adaptive path — < _minOnEvents)
    for (final char in ['E', 'T', 'I', 'A']) {
      test('single char "$char" decodes correctly (adaptive path)', () {
        expect(_roundTrip(char), char);
      });
    }

    // Common words
    test('"HELLO" at 20 WPM decodes correctly', () {
      expect(_roundTrip('HELLO'), 'HELLO');
    });

    test('"PARIS" at 20 WPM decodes correctly (ITU standard word)', () {
      expect(_roundTrip('PARIS'), 'PARIS');
    });

    test('"CQ CQ" at 20 WPM decodes correctly (word gap preserved)', () {
      expect(_roundTrip('CQ CQ'), 'CQ CQ');
    });

    test('"73 DE W1AW" at 20 WPM decodes correctly (numbers + letters)', () {
      expect(_roundTrip('73 DE W1AW'), '73 DE W1AW');
    });

    // Frequency sweep — auto-detect disabled, explicit freq passed
    for (final freq in [400, 600, 700, 800, 900]) {
      test('SOS at 20 WPM, $freq Hz decodes correctly', () {
        expect(_roundTrip('SOS', freqHz: freq), 'SOS');
      });
    }

    // Auto-detect: noise floor must be non-zero for p33 > 0 → SNR valid
    test('auto-frequency detection works at 400 Hz (noise floor prevents threshold collapse)', () {
      expect(_roundTrip('SOS', freqHz: 400, autoDetect: true), 'SOS');
    });

    test('auto-frequency detection works at 700 Hz', () {
      expect(_roundTrip('SOS', freqHz: 700, autoDetect: true), 'SOS');
    });

    // Quality score
    test('quality score > 0 for clean 20 WPM SOS', () {
      final wav = MorseWavSynthesizer.synthesize(_tones('SOS'), 700);
      final (_, quality) = OfflineAnalyzer.analyzeWav(wav, targetFrequencyHz: 700);
      expect(quality, greaterThan(0.0));
    });
  });
}
