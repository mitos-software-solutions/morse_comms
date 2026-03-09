import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/core/morse/morse_encoder.dart';
import 'package:morse_comms/core/morse/morse_table.dart';
import 'package:morse_comms/core/morse/morse_timing.dart';

void main() {
  const timing20 = MorseTiming(wpm: 20);
  const encoder = MorseEncoder(timing: timing20);

  group('MorseTiming', () {
    test('unit duration at 20 WPM is 60ms', () {
      expect(timing20.unitMs, 60);
    });

    test('dot = 1 unit, dash = 3 units', () {
      expect(timing20.dotMs, 60);
      expect(timing20.dashMs, 180);
    });

    test('gaps are correct multiples', () {
      expect(timing20.symbolGapMs, 60);
      expect(timing20.letterGapMs, 180);
      expect(timing20.wordGapMs, 420);
    });

    test('unit duration scales with WPM', () {
      const t5 = MorseTiming(wpm: 5);
      const t10 = MorseTiming(wpm: 10);
      expect(t5.unitMs, 240);
      expect(t10.unitMs, 120);
    });
  });

  group('kMorseTable', () {
    test('contains all 26 letters', () {
      for (final c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
        expect(kMorseTable.containsKey(c), isTrue, reason: 'Missing: $c');
      }
    });

    test('contains all 10 digits', () {
      for (final c in '0123456789'.split('')) {
        expect(kMorseTable.containsKey(c), isTrue, reason: 'Missing: $c');
      }
    });

    test('spot-check known patterns', () {
      expect(kMorseTable['A'], '.-');
      expect(kMorseTable['S'], '...');
      expect(kMorseTable['O'], '---');
      expect(kMorseTable['0'], '-----');
      expect(kMorseTable['5'], '.....');
    });

    test('reverse table is consistent', () {
      expect(kMorseTableReverse['.-'], 'A');
      expect(kMorseTableReverse['...'], 'S');
      expect(kMorseTableReverse['---'], 'O');
    });
  });

  group('MorseEncoder.encode — written output', () {
    test('single letter', () {
      expect(encoder.encode('A').written, '.-');
      expect(encoder.encode('E').written, '.');
      expect(encoder.encode('T').written, '-');
    });

    test('SOS pattern', () {
      expect(encoder.encode('SOS').written, '... --- ...');
    });

    test('two words separated by /', () {
      final result = encoder.encode('HI MOM');
      expect(result.written, '.... .. / -- --- --');
    });

    test('case-insensitive', () {
      expect(encoder.encode('sos').written, encoder.encode('SOS').written);
    });

    test('unknown characters are skipped', () {
      // '~' is not in the table; 'A' and 'B' should still encode.
      expect(encoder.encode('A~B').written, '.- -...');
    });

    test('extra whitespace collapsed to one word gap', () {
      expect(encoder.encode('A  B').written, encoder.encode('A B').written);
    });
  });

  group('MorseEncoder.encode — tone sequence', () {
    test('single dot (E) produces one ON tone', () {
      final tones = encoder.encode('E').tones;
      expect(tones.length, 1);
      expect(tones[0].on, isTrue);
      expect(tones[0].durationMs, timing20.dotMs);
    });

    test('single dash (T) produces one ON tone', () {
      final tones = encoder.encode('T').tones;
      expect(tones.length, 1);
      expect(tones[0].on, isTrue);
      expect(tones[0].durationMs, timing20.dashMs);
    });

    test('A (.-) produces ON dot, OFF symbol-gap, ON dash', () {
      final tones = encoder.encode('A').tones;
      expect(tones.length, 3);
      expect(tones[0], _tone(on: true, ms: timing20.dotMs));
      expect(tones[1], _tone(on: false, ms: timing20.symbolGapMs));
      expect(tones[2], _tone(on: true, ms: timing20.dashMs));
    });

    test('two letters include letter gap between them', () {
      // ET = (.) letter-gap (-)
      final tones = encoder.encode('ET').tones;
      expect(tones.length, 3);
      expect(tones[0], _tone(on: true, ms: timing20.dotMs));   // E dot
      expect(tones[1], _tone(on: false, ms: timing20.letterGapMs));
      expect(tones[2], _tone(on: true, ms: timing20.dashMs));  // T dash
    });

    test('two words include word gap between them', () {
      // E T (two single-symbol words)
      final tones = encoder.encode('E T').tones;
      expect(tones.length, 3);
      expect(tones[1], _tone(on: false, ms: timing20.wordGapMs));
    });

    test('no trailing silence at end of sequence', () {
      final tones = encoder.encode('SOS').tones;
      expect(tones.last.on, isTrue);
    });
  });

  group('MorseEncoder.decode', () {
    test('decodes known patterns', () {
      expect(MorseEncoder.decode('.-'), 'A');
      expect(MorseEncoder.decode('...'), 'S');
      expect(MorseEncoder.decode('---'), 'O');
    });

    test('returns null for unknown pattern', () {
      expect(MorseEncoder.decode('......'), isNull);
    });
  });
}

/// Helper matcher for [MorseTone].
_ToneMatcher _tone({required bool on, required int ms}) =>
    _ToneMatcher(on: on, ms: ms);

class _ToneMatcher extends Matcher {
  final bool on;
  final int ms;
  const _ToneMatcher({required this.on, required this.ms});

  @override
  bool matches(dynamic item, Map matchState) =>
      item is MorseTone && item.on == on && item.durationMs == ms;

  @override
  Description describe(Description description) =>
      description.add('MorseTone(on: $on, durationMs: $ms)');
}
