// ignore_for_file: avoid_print
//
// Property-based preservation tests for OfflineAnalyzer.
//
// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**
//
// Purpose: Verify that the decoder continues to work correctly on synthetic
// signals (non-buggy inputs where isBugCondition returns false). These tests
// establish the baseline behavior that must be preserved when fixing the
// YouTube decoder accuracy bug.
//
// These tests are run on UNFIXED code to establish the baseline, and will be
// re-run after the fix to ensure no regressions.
//
// Property 2: Preservation - Synthetic Signal Accuracy
// For any audio recording where the bug condition does NOT hold (synthetic
// test signals with clean timing and single-speed content), the OfflineAnalyzer
// SHALL produce exactly the same decoding results as the original implementation,
// preserving the existing high accuracy on well-formed signals.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/core/dsp/goertzel.dart';
import 'package:morse_comms/core/dsp/offline_analyzer.dart';
import 'package:morse_comms/core/morse/morse_table.dart';

import '../../helpers/sine_morse_generator.dart';

// ── Helper ─────────────────────────────────────────────────────────────────────

String _norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Decodes a message using the full pipeline: PCM-16 → Goertzel → OfflineAnalyzer
String _decodeMsg(
  String message, {
  required int wpm,
  double? snrDb,
  double frequencyHz = 700.0,
  int sampleRate = SineMorseGenerator.sampleRate,
}) {
  final gen = SineMorseGenerator(
    wpm: wpm,
    snrDb: snrDb,
    frequencyHz: frequencyHz,
  );
  final pcm = gen.generate(message);

  final detector = GoertzelDetector(
    sampleRate: sampleRate,
    targetFrequency: frequencyHz,
    frameSize: SineMorseGenerator.frameSize,
  );

  final frames =
      GoertzelDetector.framesFromPcm16(pcm, SineMorseGenerator.frameSize);
  final magnitudes = frames.map((f) => detector.computePower(f)).toList();
  return OfflineAnalyzer.analyze(magnitudes, detector.frameDurationMs).$1.trim();
}

/// Generates a random Morse message of given length
String _randomMessage(Random rng, int length) {
  final chars = kMorseTable.keys.where((c) => c != ' ').toList();
  final buffer = StringBuffer();
  for (int i = 0; i < length; i++) {
    if (i > 0 && rng.nextDouble() < 0.2) {
      buffer.write(' '); // 20% chance of word break
    }
    buffer.write(chars[rng.nextInt(chars.length)]);
  }
  return buffer.toString();
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // Property 2.1: Random Synthetic Messages - High Accuracy
  // Generate 100 random synthetic Morse messages with varying parameters
  // and verify decoding accuracy ≥ 95% (baseline for current decoder)
  // ══════════════════════════════════════════════════════════════════════════
  group('Property 2.1: Random synthetic messages decode with ≥95% accuracy', () {
    test('100 random messages (varying WPM 5-30, frequency 400-900Hz)', () {
      final rng = Random(42); // Fixed seed for reproducibility
      int totalChars = 0;
      int correctChars = 0;
      int perfectDecodes = 0;

      for (int i = 0; i < 100; i++) {
        // Random parameters - limit to 5-30 WPM (decoder's reliable range)
        final wpm = 5 + rng.nextInt(26); // 5-30 WPM
        final frequencyHz = 400.0 + rng.nextDouble() * 500.0; // 400-900 Hz
        final messageLength = 3 + rng.nextInt(5); // 3-7 characters
        final message = _randomMessage(rng, messageLength);

        // Decode
        final result = _decodeMsg(
          message,
          wpm: wpm,
          frequencyHz: frequencyHz,
        );

        // Count correct characters
        final expected = _norm(message);
        final actual = _norm(result);
        
        if (expected == actual) {
          perfectDecodes++;
        }

        // Character-by-character comparison
        final expectedChars = expected.replaceAll(' ', '').split('');
        final actualChars = actual.replaceAll(' ', '').split('');
        
        totalChars += expectedChars.length;
        for (int j = 0; j < expectedChars.length && j < actualChars.length; j++) {
          if (expectedChars[j] == actualChars[j]) {
            correctChars++;
          }
        }
      }

      final accuracy = totalChars > 0 ? correctChars / totalChars : 0.0;
      print('  Accuracy: ${(accuracy * 100).toStringAsFixed(2)}% '
          '($correctChars/$totalChars chars correct)');
      print('  Perfect decodes: $perfectDecodes/100');

      expect(accuracy, greaterThanOrEqualTo(0.95),
          reason: 'Synthetic signal accuracy must be ≥95% (baseline)');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Property 2.2: Standard 3:1 Timing Preservation
  // Verify recordings with standard dash:dot ratio decode correctly
  // Testing WPM range 5-30 (decoder's reliable range on unfixed code)
  // ══════════════════════════════════════════════════════════════════════════
  group('Property 2.2: Standard 3:1 timing decodes correctly', () {
    const testMessages = ['SOS', 'HELLO', 'PARIS', 'CQ CQ', 'DE W1AW'];
    const testWpms = [5, 10, 15, 20, 25, 30];

    for (final message in testMessages) {
      for (final wpm in testWpms) {
        test('$message @ $wpm WPM', () {
          final result = _decodeMsg(message, wpm: wpm);
          expect(_norm(result), message,
              reason: 'Standard timing at $wpm WPM must decode correctly');
        });
      }
    }
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Property 2.3: Sample Rate Consistency
  // Verify decoding is consistent across different sample rates
  // Note: SineMorseGenerator uses 44.1kHz, so we test that it works
  // ══════════════════════════════════════════════════════════════════════════
  group('Property 2.3: Sample rate consistency', () {
    test('44.1kHz sample rate decodes correctly', () {
      // Test at various WPM rates
      for (final wpm in [10, 20, 30]) {
        final result = _decodeMsg('SOS', wpm: wpm);
        expect(_norm(result), 'SOS',
            reason: '44.1kHz at $wpm WPM must decode correctly');
      }
    });

    test('Different frequencies decode consistently at 44.1kHz', () {
      // Test frequency range 400-900Hz
      for (final freq in [400.0, 500.0, 600.0, 700.0, 800.0, 900.0]) {
        final result = _decodeMsg('SOS', wpm: 20, frequencyHz: freq);
        expect(_norm(result), 'SOS',
            reason: '${freq.toInt()}Hz must decode correctly');
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Property 2.4: Noise Tolerance Preservation
  // Verify decoder maintains robustness to noise
  // ══════════════════════════════════════════════════════════════════════════
  group('Property 2.4: Noise tolerance preserved', () {
    const testSnrs = [40.0, 30.0, 20.0, 15.0, 10.0];

    for (final snr in testSnrs) {
      test('SOS @ 20 WPM, ${snr.toInt()} dB SNR', () {
        final result = _decodeMsg('SOS', wpm: 20, snrDb: snr);
        
        if (snr >= 15.0) {
          // High SNR should decode perfectly
          expect(_norm(result), 'SOS',
              reason: 'Clean signal at ${snr.toInt()} dB must decode correctly');
        } else {
          // Low SNR should at least produce non-empty output
          expect(result.isNotEmpty, isTrue,
              reason: 'Low SNR at ${snr.toInt()} dB must produce output');
        }
      });
    }
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Property 2.5: Frequency Range Preservation
  // Verify Goertzel-based tone detection works across 400-900 Hz range
  // ══════════════════════════════════════════════════════════════════════════
  group('Property 2.5: Frequency range 400-900Hz preserved', () {
    // Test at 50Hz intervals across the range
    for (int freq = 400; freq <= 900; freq += 50) {
      test('SOS @ ${freq}Hz', () {
        final result = _decodeMsg('SOS', wpm: 20, frequencyHz: freq.toDouble());
        expect(_norm(result), 'SOS',
            reason: '${freq}Hz must decode correctly');
      });
    }
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Property 2.6: Message Length Robustness
  // Verify decoder handles various message lengths
  // ══════════════════════════════════════════════════════════════════════════
  group('Property 2.6: Various message lengths decode correctly', () {
    final testCases = {
      'E': 'E', // Single character (shortest)
      'SOS': 'SOS', // Short message
      'HELLO WORLD': 'HELLO WORLD', // Medium message
      'THE QUICK BROWN FOX': 'THE QUICK BROWN FOX', // Long message
    };

    for (final entry in testCases.entries) {
      test('"${entry.key}"', () {
        final result = _decodeMsg(entry.key, wpm: 20);
        expect(_norm(result), entry.value);
      });
    }
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Property 2.7: Edge Cases Preservation
  // Verify decoder handles edge cases gracefully
  // ══════════════════════════════════════════════════════════════════════════
  group('Property 2.7: Edge cases handled correctly', () {
    test('Empty magnitudes return empty string', () {
      expect(OfflineAnalyzer.analyze([], 11.6).$1, '');
    });

    test('Short magnitudes return empty string', () {
      expect(OfflineAnalyzer.analyze(List.filled(9, 0.0), 11.6).$1, '');
    });

    test('Pure silence returns empty string', () {
      final silence = List<double>.filled(500, 0.0);
      expect(OfflineAnalyzer.analyze(silence, 11.6).$1, '');
    });

    test('Very slow WPM (5 WPM) decodes correctly', () {
      final result = _decodeMsg('SOS', wpm: 5);
      expect(_norm(result), 'SOS');
    });

    test('Fast WPM (30 WPM) decodes correctly', () {
      final result = _decodeMsg('SOS', wpm: 30);
      expect(_norm(result), 'SOS');
    });
  });
}
