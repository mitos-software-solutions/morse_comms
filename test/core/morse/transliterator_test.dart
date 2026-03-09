import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/core/morse/transliterator.dart';

void main() {
  group('MorseTransliterator.transliterate', () {
    // ── No-op cases ─────────────────────────────────────────────────────────

    test('empty string returns empty string', () {
      expect(MorseTransliterator.transliterate(''), '');
    });

    test('plain ASCII letters are uppercased and unchanged', () {
      expect(MorseTransliterator.transliterate('hello'), 'HELLO');
      expect(MorseTransliterator.transliterate('SOS'), 'SOS');
      expect(MorseTransliterator.transliterate('Paris'), 'PARIS');
    });

    test('digits and spaces pass through unchanged', () {
      expect(MorseTransliterator.transliterate('CQ 73'), 'CQ 73');
    });

    // ── Latin diacritics ────────────────────────────────────────────────────

    test('acute accent stripped: é→E, á→A, ó→O, ú→U, í→I', () {
      expect(MorseTransliterator.transliterate('é'), 'E');
      expect(MorseTransliterator.transliterate('á'), 'A');
      expect(MorseTransliterator.transliterate('ó'), 'O');
      expect(MorseTransliterator.transliterate('ú'), 'U');
      expect(MorseTransliterator.transliterate('í'), 'I');
    });

    test('grave and circumflex accent stripped: è→E, â→A, ô→O', () {
      expect(MorseTransliterator.transliterate('è'), 'E');
      expect(MorseTransliterator.transliterate('â'), 'A');
      expect(MorseTransliterator.transliterate('ô'), 'O');
    });

    test('umlaut stripped: ü→U, ö→O, ä→A', () {
      expect(MorseTransliterator.transliterate('ü'), 'U');
      expect(MorseTransliterator.transliterate('ö'), 'O');
      expect(MorseTransliterator.transliterate('ä'), 'A');
    });

    test('special ligatures expanded: ß→SS, Æ→AE, æ→AE, Œ→OE', () {
      expect(MorseTransliterator.transliterate('ß'), 'SS');
      expect(MorseTransliterator.transliterate('Æ'), 'AE');
      expect(MorseTransliterator.transliterate('æ'), 'AE');
      expect(MorseTransliterator.transliterate('Œ'), 'OE');
    });

    test('ñ→N, ç→C, ø→O', () {
      expect(MorseTransliterator.transliterate('ñ'), 'N');
      expect(MorseTransliterator.transliterate('ç'), 'C');
      expect(MorseTransliterator.transliterate('ø'), 'O');
    });

    test('mixed Spanish sentence transliterated correctly', () {
      // "Está bien" → ESTA BIEN
      expect(MorseTransliterator.transliterate('Está'), 'ESTA');
    });

    test('German umlauts in a word: Über→UBER', () {
      expect(MorseTransliterator.transliterate('Über'), 'UBER');
    });

    // ── Cyrillic ────────────────────────────────────────────────────────────

    test('Cyrillic SOS (СОС) → SOS', () {
      expect(MorseTransliterator.transliterate('СОС'), 'SOS');
    });

    test('Russian word ПРИВЕТ → PRIVET', () {
      expect(MorseTransliterator.transliterate('ПРИВЕТ'), 'PRIVET');
      expect(MorseTransliterator.transliterate('привет'), 'PRIVET');
    });

    test('Cyrillic multi-symbol sequences: ЖЩЮ → ZHSHCHYU', () {
      expect(MorseTransliterator.transliterate('Ж'), 'ZH');
      expect(MorseTransliterator.transliterate('Щ'), 'SHCH');
      expect(MorseTransliterator.transliterate('Ю'), 'YU');
      expect(MorseTransliterator.transliterate('Я'), 'YA');
    });

    test('Cyrillic soft sign and hard sign are silently dropped', () {
      // Soft sign Ь and hard sign Ъ map to empty string
      expect(MorseTransliterator.transliterate('ЬЪ'), '');
    });

    test('Ukrainian extras: Ї→YI, Є→YE', () {
      expect(MorseTransliterator.transliterate('Ї'), 'YI');
      expect(MorseTransliterator.transliterate('Є'), 'YE');
    });

    // ── Greek ───────────────────────────────────────────────────────────────

    test('Greek letters: Α→A, Β→V, Γ→G, Δ→D', () {
      expect(MorseTransliterator.transliterate('Α'), 'A');
      expect(MorseTransliterator.transliterate('Β'), 'V');
      expect(MorseTransliterator.transliterate('Γ'), 'G');
      expect(MorseTransliterator.transliterate('Δ'), 'D');
    });

    test('Greek multi-char sequences: Θ→TH, Χ→CH, Ψ→PS', () {
      expect(MorseTransliterator.transliterate('Θ'), 'TH');
      expect(MorseTransliterator.transliterate('Χ'), 'CH');
      expect(MorseTransliterator.transliterate('Ψ'), 'PS');
    });

    test('Greek word ΣΟΣ → SOS', () {
      expect(MorseTransliterator.transliterate('ΣΟΣ'), 'SOS');
    });

    test('Greek with tonos (accent marks) stripped: ά→A, έ→E', () {
      expect(MorseTransliterator.transliterate('ά'), 'A');
      expect(MorseTransliterator.transliterate('έ'), 'E');
    });

    // ── Unknown characters ──────────────────────────────────────────────────

    test('characters with no mapping are passed through as-is (encoder drops them)', () {
      // Chinese characters have no mapping — passed through for encoder to skip
      final result = MorseTransliterator.transliterate('A中B');
      expect(result, contains('A'));
      expect(result, contains('B'));
      // The unknown char is present but the encoder will ignore it
    });

    // ── Mixed scripts ───────────────────────────────────────────────────────

    test('mixed ASCII + Cyrillic + diacritics transliterates each correctly', () {
      // "SOS Привет" → "SOS PRIVET"
      expect(MorseTransliterator.transliterate('SOS Привет'), 'SOS PRIVET');
    });

    test('mixed Latin diacritics in a full word', () {
      // "héllo wörld" → "HELLO WORLD"
      expect(MorseTransliterator.transliterate('héllo wörld'), 'HELLO WORLD');
    });
  });

  group('MorseTransliterator.needsTransliteration', () {
    test('returns false for plain ASCII', () {
      expect(MorseTransliterator.needsTransliteration('SOS'), isFalse);
      expect(MorseTransliterator.needsTransliteration('hello world'), isFalse);
      expect(MorseTransliterator.needsTransliteration('CQ 73'), isFalse);
      expect(MorseTransliterator.needsTransliteration(''), isFalse);
    });

    test('returns true for Latin diacritics', () {
      expect(MorseTransliterator.needsTransliteration('héllo'), isTrue);
      expect(MorseTransliterator.needsTransliteration('naïve'), isTrue);
      expect(MorseTransliterator.needsTransliteration('ñoño'), isTrue);
    });

    test('returns true for Cyrillic', () {
      expect(MorseTransliterator.needsTransliteration('Привет'), isTrue);
      expect(MorseTransliterator.needsTransliteration('СОС'), isTrue);
    });

    test('returns true for Greek', () {
      expect(MorseTransliterator.needsTransliteration('ΣΟΣ'), isTrue);
    });

    test('returns true for mixed ASCII + non-ASCII', () {
      expect(MorseTransliterator.needsTransliteration('SOS Привет'), isTrue);
    });
  });
}
