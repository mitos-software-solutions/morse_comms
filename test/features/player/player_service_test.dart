import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/core/morse/morse_encoder.dart';
import 'package:morse_comms/core/morse/morse_timing.dart';

/// Unit-testable helpers extracted from PlayerService logic.
///
/// PlayerService itself wraps SoLoud.instance (hardware) and requires a real
/// device/emulator for integration testing. These tests verify the tone
/// sequence produced by MorseEncoder is correct input for the player.
void main() {
  const timing = MorseTiming(wpm: 20);
  const encoder = MorseEncoder(timing: timing);

  group('Tone sequence contract for PlayerService', () {
    test('sequence always starts with an ON tone', () {
      final tones = encoder.encode('SOS').tones;
      expect(tones.first.on, isTrue);
    });

    test('sequence always ends with an ON tone (no trailing silence)', () {
      final tones = encoder.encode('SOS').tones;
      expect(tones.last.on, isTrue);
    });

    test('ON and OFF tones strictly alternate', () {
      final tones = encoder.encode('PARIS').tones;
      for (int i = 1; i < tones.length; i++) {
        expect(
          tones[i].on,
          isNot(tones[i - 1].on),
          reason: 'Consecutive same-polarity tones at index $i',
        );
      }
    });

    test('all durations are positive', () {
      final tones = encoder.encode('HELLO WORLD').tones;
      for (final t in tones) {
        expect(t.durationMs, greaterThan(0));
      }
    });

    test('ON durations are only dot or dash lengths', () {
      final tones = encoder.encode('ABCDE').tones;
      final validDurations = {timing.dotMs, timing.dashMs};
      for (final t in tones.where((t) => t.on)) {
        expect(
          validDurations,
          contains(t.durationMs),
          reason: 'Unexpected ON duration: ${t.durationMs}ms',
        );
      }
    });

    test('OFF durations are only valid gap lengths', () {
      final tones = encoder.encode('AB CD').tones;
      final validDurations = {
        timing.symbolGapMs,
        timing.letterGapMs,
        timing.wordGapMs,
      };
      for (final t in tones.where((t) => !t.on)) {
        expect(
          validDurations,
          contains(t.durationMs),
          reason: 'Unexpected OFF duration: ${t.durationMs}ms',
        );
      }
    });

    test('total duration of SOS is correct', () {
      // S = ... (3 dots, 2 symbol gaps)
      // O = --- (3 dashes, 2 symbol gaps)
      // S = ... (3 dots, 2 symbol gaps)
      // Plus 2 letter gaps between S-O and O-S
      final tones = encoder.encode('SOS').tones;
      final totalMs = tones.fold<int>(0, (sum, t) => sum + t.durationMs);

      // S: 3*dot + 2*symGap = 3*60 + 2*60 = 300
      // O: 3*dash + 2*symGap = 3*180 + 2*60 = 660
      // S: 3*dot + 2*symGap = 300
      // 2 letter gaps: 2*180 = 360
      // Total = 300 + 360 + 660 + 360 + 300 = 1980ms... wait, let me recalc:
      // S(300) + letterGap(180) + O(660) + letterGap(180) + S(300) = 1620
      expect(totalMs, 1620);
    });

    test('empty string produces no tones', () {
      expect(encoder.encode('').tones, isEmpty);
    });

    test('whitespace-only string produces no tones', () {
      expect(encoder.encode('   ').tones, isEmpty);
    });
  });
}
