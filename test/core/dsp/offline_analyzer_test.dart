// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/core/dsp/goertzel.dart';
import 'package:morse_comms/core/dsp/offline_analyzer.dart';

import '../../helpers/sine_morse_generator.dart';

// ── Helper ─────────────────────────────────────────────────────────────────────

String _norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Runs the exact pipeline the app uses after recording/loading a WAV:
///   PCM-16 → Goertzel frames → magnitudes → OfflineAnalyzer → text.
String _decodeMsg(String message, {required int wpm, double? snrDb,
    double frequencyHz = 700.0}) {
  final gen =
      SineMorseGenerator(wpm: wpm, snrDb: snrDb, frequencyHz: frequencyHz);
  final pcm = gen.generate(message);

  final detector = GoertzelDetector(
    sampleRate: SineMorseGenerator.sampleRate,
    targetFrequency: frequencyHz,
    frameSize: SineMorseGenerator.frameSize,
  );

  final frames =
      GoertzelDetector.framesFromPcm16(pcm, SineMorseGenerator.frameSize);
  final magnitudes = frames.map((f) => detector.computePower(f)).toList();
  return OfflineAnalyzer.analyze(magnitudes, detector.frameDurationMs).trim();
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Core messages at 20 WPM — this is the app's primary use case ──────────
  group('OfflineAnalyzer — core messages (20 WPM, no noise)', () {
    const cases = {
      'SOS': 'SOS',
      'HELLO': 'HELLO',
      'PARIS': 'PARIS',
      'CQ CQ': 'CQ CQ',
      'DE W1AW': 'DE W1AW',
    };

    for (final entry in cases.entries) {
      test('"${entry.key}"', () {
        final result = _decodeMsg(entry.key, wpm: 20);
        print('  "${entry.key}" → "$result"');
        expect(_norm(result), entry.value);
      });
    }
  });

  // ── 2. WPM range ──────────────────────────────────────────────────────────────
  group('OfflineAnalyzer — WPM range (no noise)', () {
    for (final wpm in [5, 8, 10, 13, 15, 20, 25]) {
      test('SOS @ $wpm WPM', () {
        final result = _decodeMsg('SOS', wpm: wpm);
        print('  $wpm WPM → "$result"');
        expect(_norm(result), 'SOS');
      });
    }
  });

  // ── 3. Noise tolerance at 20 WPM ─────────────────────────────────────────────
  group('OfflineAnalyzer — noise tolerance (20 WPM)', () {
    for (final snr in [40.0, 30.0, 20.0, 10.0]) {
      test('SOS @ ${snr.toInt()} dB SNR', () {
        final result = _decodeMsg('SOS', wpm: 20, snrDb: snr);
        print('  ${snr.toInt()} dB SNR → "$result"');
        if (snr >= 20.0) {
          expect(_norm(result), 'SOS');
        } else {
          // At very low SNR we just expect non-garbage (non-empty is reasonable)
          expect(result.isNotEmpty, isTrue,
              reason: 'Expected non-empty output at ${snr.toInt()} dB');
        }
      });
    }
  });

  // ── 4. Frequency tolerance ────────────────────────────────────────────────────
  group('OfflineAnalyzer — frequency tolerance (20 WPM, no noise)', () {
    for (final hz in [680.0, 700.0, 720.0, 750.0]) {
      test('SOS @ ${hz.toInt()} Hz', () {
        final result = _decodeMsg('SOS', wpm: 20, frequencyHz: hz);
        print('  ${hz.toInt()} Hz → "$result"');
        expect(_norm(result), 'SOS');
      });
    }
  });

  // ── 5. Magnitudes too short — should return empty gracefully ──────────────────
  test('OfflineAnalyzer — empty/short magnitudes return empty string', () {
    expect(OfflineAnalyzer.analyze([], 11.6), '');
    expect(OfflineAnalyzer.analyze(List.filled(9, 0.0), 11.6), '');
  });

  // ── 6. Pure silence — should return empty gracefully ─────────────────────────
  test('OfflineAnalyzer — pure silence returns empty string', () {
    final silence = List<double>.filled(500, 0.0);
    final result = OfflineAnalyzer.analyze(silence, 11.6);
    expect(result, '');
  });

  // ── 7. Stress matrix (informational — no hard fail) ───────────────────────────
  group('OfflineAnalyzer — stress matrix (informational)', () {
    const wpms = [5, 10, 20, 25];
    const snrs = [20.0, 10.0, 5.0];

    for (final wpm in wpms) {
      for (final snr in snrs) {
        test('SOS @ $wpm WPM, ${snr.toInt()} dB SNR', () {
          final result = _decodeMsg('SOS', wpm: wpm, snrDb: snr);
          final pass = _norm(result) == 'SOS';
          print(
              '  $wpm WPM / ${snr.toInt()} dB → "$result" ${pass ? "✓" : "✗"}');
          // Informational: no hard assertion, just logs for tracking regression
        });
      }
    }
  });
}
