import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/core/morse/farnsworth_timing.dart';
import 'package:morse_comms/core/morse/morse_timing.dart';

void main() {
  // Helper: standard MorseTiming for the same charWpm.
  MorseTiming standard(int wpm) => MorseTiming(wpm: wpm);

  group('FarnsworthTiming — constructor', () {
    test('constructs without error when effectiveWpm == charWpm', () {
      expect(() => FarnsworthTiming(charWpm: 15, effectiveWpm: 15), returnsNormally);
    });

    test('constructs without error when effectiveWpm < charWpm', () {
      expect(() => FarnsworthTiming(charWpm: 15, effectiveWpm: 5), returnsNormally);
    });

    test('asserts when effectiveWpm > charWpm', () {
      expect(
        () => FarnsworthTiming(charWpm: 15, effectiveWpm: 20),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts when effectiveWpm is 0', () {
      expect(
        () => FarnsworthTiming(charWpm: 15, effectiveWpm: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('FarnsworthTiming — standard timing identity', () {
    // When effectiveWpm == charWpm, Farnsworth gaps must equal standard ITU gaps.
    for (final wpm in [5, 10, 15, 20, 25, 30]) {
      test('letterGapMs == standard at $wpm WPM (effectiveWpm == charWpm)', () {
        final f = FarnsworthTiming(charWpm: wpm, effectiveWpm: wpm);
        final s = standard(wpm);
        expect(f.letterGapMs, s.letterGapMs);
      });

      test('wordGapMs == standard at $wpm WPM (effectiveWpm == charWpm)', () {
        final f = FarnsworthTiming(charWpm: wpm, effectiveWpm: wpm);
        final s = standard(wpm);
        expect(f.wordGapMs, s.wordGapMs);
      });
    }
  });

  group('FarnsworthTiming — character-level timing unchanged', () {
    test('unitMs equals standard unitMs at same charWpm', () {
      final f = FarnsworthTiming(charWpm: 15, effectiveWpm: 5);
      final s = standard(15);
      expect(f.unitMs, s.unitMs);
    });

    test('dotMs equals standard dotMs at same charWpm', () {
      final f = FarnsworthTiming(charWpm: 15, effectiveWpm: 5);
      expect(f.dotMs, standard(15).dotMs);
    });

    test('dashMs equals standard dashMs at same charWpm', () {
      final f = FarnsworthTiming(charWpm: 15, effectiveWpm: 5);
      expect(f.dashMs, standard(15).dashMs);
    });

    test('symbolGapMs equals standard symbolGapMs at same charWpm', () {
      final f = FarnsworthTiming(charWpm: 15, effectiveWpm: 5);
      expect(f.symbolGapMs, standard(15).symbolGapMs);
    });
  });

  group('FarnsworthTiming — stretched gaps', () {
    test('letterGapMs is larger than standard when effectiveWpm < charWpm', () {
      final f = FarnsworthTiming(charWpm: 15, effectiveWpm: 5);
      expect(f.letterGapMs, greaterThan(standard(15).letterGapMs));
    });

    test('wordGapMs is larger than standard when effectiveWpm < charWpm', () {
      final f = FarnsworthTiming(charWpm: 15, effectiveWpm: 5);
      expect(f.wordGapMs, greaterThan(standard(15).wordGapMs));
    });

    test('gaps decrease as effectiveWpm increases toward charWpm', () {
      final f5  = FarnsworthTiming(charWpm: 15, effectiveWpm: 5);
      final f9  = FarnsworthTiming(charWpm: 15, effectiveWpm: 9);
      final f13 = FarnsworthTiming(charWpm: 15, effectiveWpm: 13);
      final f15 = FarnsworthTiming(charWpm: 15, effectiveWpm: 15);

      // Letter gaps should strictly decrease as effectiveWpm rises.
      expect(f5.letterGapMs,  greaterThan(f9.letterGapMs));
      expect(f9.letterGapMs,  greaterThan(f13.letterGapMs));
      expect(f13.letterGapMs, greaterThan(f15.letterGapMs));

      // Word gaps the same.
      expect(f5.wordGapMs,  greaterThan(f9.wordGapMs));
      expect(f9.wordGapMs,  greaterThan(f13.wordGapMs));
      expect(f13.wordGapMs, greaterThan(f15.wordGapMs));
    });
  });

  group('FarnsworthTiming — F-1 concrete values (charWpm=15, effectiveWpm=5)', () {
    // spacingUnit = (60000/5 − 31×(1200.0/15)) / 19 = (12000 − 2480) / 19 = 501.053 ms
    // letterGapMs = round(501.053 × 3) = round(1503.158) = 1503 ms
    // wordGapMs   = round(501.053 × 7) = round(3507.368) = 3507 ms
    late FarnsworthTiming f;
    setUp(() => f = FarnsworthTiming(charWpm: 15, effectiveWpm: 5));

    test('letterGapMs is 1503 ms', () => expect(f.letterGapMs, 1503));
    test('wordGapMs is 3507 ms',   () => expect(f.wordGapMs,   3507));
  });

  group('FarnsworthTiming — clamping', () {
    test('letterGapMs is never below standard unitMs × 3', () {
      // Even at effectiveWpm == charWpm (no stretch), clamp should hold.
      for (final wpm in [5, 15, 20, 30]) {
        final f = FarnsworthTiming(charWpm: wpm, effectiveWpm: wpm);
        expect(f.letterGapMs, greaterThanOrEqualTo(f.unitMs * 3));
      }
    });

    test('wordGapMs is never below standard unitMs × 7', () {
      for (final wpm in [5, 15, 20, 30]) {
        final f = FarnsworthTiming(charWpm: wpm, effectiveWpm: wpm);
        expect(f.wordGapMs, greaterThanOrEqualTo(f.unitMs * 7));
      }
    });
  });
}
