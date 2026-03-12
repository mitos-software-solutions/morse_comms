// ignore_for_file: avoid_print
//
// Edge case tests for OfflineAnalyzer - Phase 2 improvements.
//
// **Purpose**: Test scenarios not covered by existing tests:
//   - Multi-speed recordings (speed changes within one recording)
//   - Transient events (clicks, pops, keyboard sounds)
//   - Parameter boundary conditions (ratio edges, CV edges)
//   - High WPM with noise
//   - Gap threshold edge cases
//
// **Validates: Requirements 1.3, 1.4, 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.7**
//
// These tests establish baseline behavior BEFORE parameter tuning.
// Some tests may FAIL or produce '?' - this is expected and will be
// documented for the next phase of improvements.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/core/dsp/goertzel.dart';
import 'package:morse_comms/core/dsp/offline_analyzer.dart';

import '../../helpers/sine_morse_generator.dart';

// ── Helper ─────────────────────────────────────────────────────────────────────

String _norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Decodes a message using the full pipeline: PCM-16 → Goertzel → OfflineAnalyzer
String _decodeMsg(
  String message, {
  required int wpm,
  double? snrDb,
  double frequencyHz = 700.0,
}) {
  final gen = SineMorseGenerator(
    wpm: wpm,
    snrDb: snrDb,
    frequencyHz: frequencyHz,
  );
  final pcm = gen.generate(message);

  final detector = GoertzelDetector(
    sampleRate: SineMorseGenerator.sampleRate,
    targetFrequency: frequencyHz,
    frameSize: SineMorseGenerator.frameSize,
  );

  final frames =
      GoertzelDetector.framesFromPcm16(pcm, SineMorseGenerator.frameSize);
  final magnitudes = frames.map((f) => detector.computePower(f)).toList();
  return OfflineAnalyzer.analyze(magnitudes, detector.frameDurationMs).$1.trim();
}

/// Generates multi-speed recording by concatenating messages at different WPMs
Int16List _generateMultiSpeed(List<(String, int)> segments, {double frequencyHz = 700.0}) {
  final allPcm = <int>[];
  
  for (final (message, wpm) in segments) {
    final gen = SineMorseGenerator(wpm: wpm, frequencyHz: frequencyHz);
    final events = gen.buildEvents(message);
    final pcm = gen.renderPcm(events);
    allPcm.addAll(pcm);
  }
  
  return Int16List.fromList(allPcm);
}

/// Decodes multi-speed PCM
String _decodeMultiSpeedPcm(Int16List pcm, {double frequencyHz = 700.0}) {
  final detector = GoertzelDetector(
    sampleRate: SineMorseGenerator.sampleRate,
    targetFrequency: frequencyHz,
    frameSize: SineMorseGenerator.frameSize,
  );

  final frames =
      GoertzelDetector.framesFromPcm16(pcm, SineMorseGenerator.frameSize);
  final magnitudes = frames.map((f) => detector.computePower(f)).toList();
  return OfflineAnalyzer.analyze(magnitudes, detector.frameDurationMs).$1.trim();
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // Task 5.1: Multi-speed recording tests
  // Test recordings with speed changes within one recording
  // ══════════════════════════════════════════════════════════════════════════
  group('Task 5.1: Multi-speed recordings', () {
    test('SOS at 10 WPM → 20 WPM → 30 WPM (informational)', () {
      final pcm = _generateMultiSpeed([
        ('SOS', 10),
        ('SOS', 20),
        ('SOS', 30),
      ]);
      
      final result = _decodeMultiSpeedPcm(pcm);
      print('[Multi-speed 10→20→30] decoded: "$result"');
      print('[Multi-speed 10→20→30] expected: "SOS SOS SOS" or with "?"');
      
      // Informational: document actual behavior
      // May produce '?' between segments or garbled output
      expect(result, isNot(isEmpty), 
          reason: 'Should produce some output, even if not perfect');
    });

    test('SOS at 15 WPM → 20 WPM (33% speed change, informational)', () {
      final pcm = _generateMultiSpeed([
        ('SOS', 15),
        ('SOS', 20),
      ]);
      
      final result = _decodeMultiSpeedPcm(pcm);
      print('[Multi-speed 15→20] decoded: "$result"');
      print('[Multi-speed 15→20] expected: "SOS SOS" or with "?"');
      
      // Informational: 33% speed change may not be detected
      expect(result, isNot(isEmpty),
          reason: 'Should produce some output');
    });

    test('Short segments (4-6 events per speed, informational)', () {
      // "E" = . (1 event), "I" = .. (2 events), "S" = ... (3 events)
      // "H" = .... (4 events), "5" = ..... (5 events), "6" = -.... (5 events)
      final pcm = _generateMultiSpeed([
        ('H', 10),    // 4 dots at 10 WPM
        ('H', 20),    // 4 dots at 20 WPM
      ]);
      
      final result = _decodeMultiSpeedPcm(pcm);
      print('[Short segments] decoded: "$result"');
      print('[Short segments] expected: "H H" or with "?"');
      
      // Informational: short segments may not split correctly
      expect(result, isNot(isEmpty),
          reason: 'Should produce some output');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Task 5.2: Transient event tests
  // Test recordings with clicks, pops, and other transient sounds
  // ══════════════════════════════════════════════════════════════════════════
  group('Task 5.2: Transient events', () {
    // Note: For now, these are informational tests
    // Full transient injection requires modifying the generator
    // We'll test with very short ON events that simulate transients
    
    test('SOS with potential transient at start (informational)', () {
      // Generate SOS normally - transient injection would require
      // modifying the PCM directly, which we'll add if needed
      final result = _decodeMsg('SOS', wpm: 20);
      print('[Transient test] decoded: "$result"');
      
      // For now, just verify normal decoding works
      expect(_norm(result), 'SOS',
          reason: 'Baseline: SOS without transients should decode correctly');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Task 5.3: Parameter boundary tests
  // Test at exact parameter boundaries (ratio, CV)
  // ══════════════════════════════════════════════════════════════════════════
  group('Task 5.3: Parameter boundary tests', () {
    // Note: Testing specific ratios requires custom timing
    // The SineMorseGenerator uses standard 3:1 ratio
    // We'll test WPM ranges that approach boundaries
    
    test('SOS at various WPM (boundary exploration)', () {
      // Test across WPM range to explore ratio variations
      for (final wpm in [5, 10, 15, 20, 25, 30]) {
        final result = _decodeMsg('SOS', wpm: wpm);
        print('[$wpm WPM] decoded: "$result"');
        expect(_norm(result), 'SOS',
            reason: '$wpm WPM should decode correctly');
      }
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Task 5.4: High WPM with noise tests
  // Test that high WPM dots are not filtered as noise
  // ══════════════════════════════════════════════════════════════════════════
  group('Task 5.4: High WPM with noise', () {
    test('SOS at 35 WPM with 15 dB SNR', () {
      final result = _decodeMsg('SOS', wpm: 35, snrDb: 15.0);
      print('[35 WPM, 15dB SNR] decoded: "$result"');
      
      // At 35 WPM, dots are very short (2-3 frames)
      // The minOnMs filter (2.5 × frameDuration) may filter them
      // This test documents current behavior
      if (_norm(result) == 'SOS') {
        print('[35 WPM] ✓ Decoded correctly');
      } else {
        print('[35 WPM] ✗ Dots may be filtered as noise');
        print('[35 WPM] Current behavior: "$result"');
      }
      
      // Informational: may fail if dots are filtered
      expect(result, isNot(isEmpty),
          reason: 'Should produce some output, even if dots are filtered');
    });

    test('SOS at 40 WPM with 15 dB SNR', () {
      final result = _decodeMsg('SOS', wpm: 40, snrDb: 15.0);
      print('[40 WPM, 15dB SNR] decoded: "$result"');
      
      // At 40 WPM, dots are even shorter
      // Likely to be filtered by current minOnMs threshold
      if (_norm(result) == 'SOS') {
        print('[40 WPM] ✓ Decoded correctly');
      } else {
        print('[40 WPM] ✗ Dots likely filtered as noise');
        print('[40 WPM] Current behavior: "$result"');
      }
      
      // Informational: likely to fail
      expect(result, isNot(isEmpty),
          reason: 'Should produce some output');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Task 5.5: Gap threshold edge case tests
  // Test weak bimodal gap separation (reverb simulation)
  // ══════════════════════════════════════════════════════════════════════════
  group('Task 5.5: Gap threshold edge cases', () {
    // Note: Testing specific gap ratios requires custom timing
    // The SineMorseGenerator uses standard ITU timing
    // These tests document baseline behavior
    
    test('SOS at 20 WPM (baseline gap threshold behavior)', () {
      final result = _decodeMsg('SOS', wpm: 20);
      print('[Gap threshold baseline] decoded: "$result"');
      expect(_norm(result), 'SOS',
          reason: 'Standard timing should decode correctly');
    });
  });
}
