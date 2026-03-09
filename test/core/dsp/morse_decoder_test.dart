import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/core/dsp/morse_decoder.dart';
import 'package:morse_comms/core/morse/morse_timing.dart';

/// Feed a dot/dash pattern string (e.g. '.-') into [decoder] using exact
/// [timing] durations, with symbol gaps between symbols and [trailingGap]
/// after the last symbol.
void _feedPattern(
  MorseDecoder decoder,
  String pattern,
  MorseTiming timing, {
  int trailingGapMs = 0,
}) {
  for (int i = 0; i < pattern.length; i++) {
    final isDash = pattern[i] == '-';
    decoder.processEvent(
      on: true,
      durationMs: isDash ? timing.dashMs : timing.dotMs,
    );
    if (i < pattern.length - 1) {
      decoder.processEvent(on: false, durationMs: timing.symbolGapMs);
    }
  }
  if (trailingGapMs > 0) {
    decoder.processEvent(on: false, durationMs: trailingGapMs);
  }
}

/// Encode a full word into the decoder using standard timing.
void _feedWord(MorseDecoder decoder, String text, MorseTiming timing) {
  final upper = text.toUpperCase();
  for (int ci = 0; ci < upper.length; ci++) {
    final char = upper[ci];
    final pattern = {
      'A': '.-', 'B': '-...', 'C': '-.-.', 'D': '-..', 'E': '.',
      'F': '..-.', 'G': '--.', 'H': '....', 'I': '..', 'J': '.---',
      'K': '-.-', 'L': '.-..', 'M': '--', 'N': '-.', 'O': '---',
      'P': '.--.', 'Q': '--.-', 'R': '.-.', 'S': '...', 'T': '-',
      'U': '..-', 'V': '...-', 'W': '.--', 'X': '-..-', 'Y': '-.--',
      'Z': '--..',
    }[char];
    if (pattern == null) continue;

    final isLastChar = (ci == upper.length - 1);
    _feedPattern(
      decoder,
      pattern,
      timing,
      trailingGapMs: isLastChar ? 0 : timing.letterGapMs,
    );
  }
}

void main() {
  const timing = MorseTiming(wpm: 20);

  MorseDecoder makeDecoder() => MorseDecoder();

  group('AdaptiveTiming', () {
    test('classifies dot correctly after two observations', () {
      final t = AdaptiveTiming();
      t.observeOn(60);  // dot
      t.observeOn(180); // dash → now both estimates exist
      expect(t.isDot(60), isTrue);
      expect(t.isDot(180), isFalse);
    });

    test('symbol gap < 2 units → GapType.symbol', () {
      final t = AdaptiveTiming()..observeOn(60);
      expect(t.classifyGap(60), GapType.symbol);
      expect(t.classifyGap(110), GapType.symbol); // < 120
    });

    test('letter gap 3 units → GapType.letter', () {
      final t = AdaptiveTiming()..observeOn(60);
      expect(t.classifyGap(180), GapType.letter);
    });

    test('word gap 7 units → GapType.word', () {
      final t = AdaptiveTiming()..observeOn(60);
      expect(t.classifyGap(420), GapType.word);
    });

    test('reset clears learned state', () {
      final t = AdaptiveTiming()
        ..observeOn(60)
        ..observeOn(180);
      t.reset();
      // estimatedUnitMs falls back to default 60ms
      expect(t.estimatedUnitMs, 60.0);
    });
  });

  group('MorseDecoder — single characters', () {
    test('decodes E (single dot)', () {
      final d = makeDecoder();
      d.processEvent(on: true, durationMs: timing.dotMs);
      d.flush();
      expect(d.decodedText, 'E');
    });

    test('decodes T (single dash)', () {
      final d = makeDecoder();
      d.processEvent(on: true, durationMs: timing.dotMs); // bootstrap dot
      d.processEvent(on: false, durationMs: timing.letterGapMs);
      d.processEvent(on: true, durationMs: timing.dashMs);
      d.flush();
      expect(d.decodedText, 'ET');
    });

    test('decodes A (.-)', () {
      final d = makeDecoder();
      _feedPattern(d, '.-', timing, trailingGapMs: timing.letterGapMs);
      d.flush();
      expect(d.decodedText, 'A');
    });

    test('decodes S (...)', () {
      final d = makeDecoder();
      _feedPattern(d, '...', timing, trailingGapMs: timing.letterGapMs);
      d.flush();
      expect(d.decodedText, 'S');
    });

    test('decodes O (---)', () {
      final d = makeDecoder();
      // bootstrap with a dot first so timing knows dot vs dash
      d.processEvent(on: true, durationMs: timing.dotMs);
      d.processEvent(on: false, durationMs: timing.letterGapMs);
      _feedPattern(d, '---', timing, trailingGapMs: timing.letterGapMs);
      d.flush();
      expect(d.decodedText, 'EO');
    });
  });

  group('MorseDecoder — words', () {
    test('decodes SOS', () {
      final d = makeDecoder();
      _feedPattern(d, '...', timing, trailingGapMs: timing.letterGapMs);
      _feedPattern(d, '---', timing, trailingGapMs: timing.letterGapMs);
      _feedPattern(d, '...', timing);
      d.flush();
      expect(d.decodedText, 'SOS');
    });

    test('word gap inserts a space', () {
      final d = makeDecoder();
      _feedWord(d, 'HI', timing);
      d.processEvent(on: false, durationMs: timing.wordGapMs);
      _feedWord(d, 'MOM', timing);
      d.flush();
      expect(d.decodedText, 'HI MOM');
    });
  });

  group('AdaptiveTiming — isCalibrated', () {
    test('false before any ON event', () {
      final t = AdaptiveTiming();
      expect(t.isCalibrated, isFalse);
    });

    test('false while first ON is still pending', () {
      final t = AdaptiveTiming();
      t.observeOn(60); // deferred — waiting for gap
      expect(t.isCalibrated, isFalse);
    });

    test('true after gap-based bootstrap completes', () {
      final t = AdaptiveTiming();
      t.observeOn(60);
      t.bootstrapFromGap(60); // resolves pending first
      expect(t.isCalibrated, isTrue);
    });

    test('true after two-ON bootstrap', () {
      final t = AdaptiveTiming();
      t.observeOn(60);
      t.observeOn(180); // two-ON bootstrap
      expect(t.isCalibrated, isTrue);
    });
  });

  group('MorseDecoder — edge cases', () {
    test('unknown pattern is skipped silently', () {
      final d = makeDecoder();
      // 6 dots = "......" which is not in the table
      for (int i = 0; i < 6; i++) {
        d.processEvent(on: true, durationMs: timing.dotMs);
        if (i < 5) d.processEvent(on: false, durationMs: timing.symbolGapMs);
      }
      d.flush();
      expect(d.decodedText, '');
    });

    test('leading silence before any tone does not produce spurious spaces', () {
      // Regression: before the isCalibrated guard, a long leading gap at slow
      // WPM would be misclassified as a word gap (using 60 ms fallback) and
      // write a spurious space even though no character had started.
      final d = makeDecoder();
      // Simulate 500 ms of silence before the first tone (e.g. mic opens early)
      d.processEvent(on: false, durationMs: 500);
      d.processEvent(on: false, durationMs: 300);
      // Now send 'E'
      d.processEvent(on: true, durationMs: timing.dotMs);
      d.flush();
      expect(d.decodedText, 'E'); // no leading space
    });

    test('flush on empty buffer is a no-op', () {
      final d = makeDecoder();
      d.flush();
      expect(d.decodedText, '');
    });

    test('reset clears output and timing', () {
      final d = makeDecoder();
      _feedPattern(d, '...', timing, trailingGapMs: timing.letterGapMs);
      d.flush();
      expect(d.decodedText, 'S');
      d.reset();
      expect(d.decodedText, '');
    });

    test('multiple word gaps do not add multiple spaces', () {
      // Only one word gap between ET and the next char
      final d = makeDecoder();
      d.processEvent(on: true, durationMs: timing.dotMs);   // E
      d.processEvent(on: false, durationMs: timing.wordGapMs);
      d.processEvent(on: true, durationMs: timing.dotMs);   // E
      d.flush();
      expect(d.decodedText, 'E E');
    });
  });
}
