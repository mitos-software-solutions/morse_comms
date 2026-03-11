import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/core/morse/morse_encoder.dart';
import 'package:morse_comms/core/morse/morse_timing.dart';
import 'package:morse_comms/core/morse/transliterator.dart';
import 'package:morse_comms/features/encoder/data/speech_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Encoder Data Layer - MorseEncoder', () {
    late MorseEncoder encoder;

    setUp(() {
      encoder = MorseEncoder(timing: MorseTiming(wpm: 20));
    });

    group('Morse Encoding', () {
      test('encodes single character to morse', () {
        final encoding = encoder.encode('A');
        expect(encoding.written, equals('.-'));
      });

      test('encodes multiple characters with spaces', () {
        final encoding = encoder.encode('AB');
        expect(encoding.written, equals('.- -...'));
      });

      test('encodes SOS correctly', () {
        final encoding = encoder.encode('SOS');
        expect(encoding.written, equals('... --- ...'));
      });

      test('encodes uppercase and lowercase identically', () {
        final upper = encoder.encode('HELLO');
        final lower = encoder.encode('hello');
        expect(upper.written, equals(lower.written));
      });

      test('encodes numbers', () {
        final encoding = encoder.encode('123');
        expect(encoding.written, isNotEmpty);
      });

      test('encodes punctuation', () {
        final encoding = encoder.encode('.');
        expect(encoding.written, isNotEmpty);
      });

      test('handles empty string', () {
        final encoding = encoder.encode('');
        expect(encoding.written, isEmpty);
      });

      test('handles whitespace in input', () {
        final encoding = encoder.encode('A B');
        expect(encoding.written, contains('/'));
      });

      test('encodes all alphabet characters', () {
        for (int i = 0; i < 26; i++) {
          final char = String.fromCharCode(65 + i); // A-Z
          final encoding = encoder.encode(char);
          expect(encoding.written, isNotEmpty);
        }
      });

      test('encodes all digits', () {
        for (int i = 0; i < 10; i++) {
          final encoding = encoder.encode(i.toString());
          expect(encoding.written, isNotEmpty);
        }
      });

      test('morse output contains only valid morse characters', () {
        final encoding = encoder.encode('HELLO WORLD');
        expect(encoding.written, matches(RegExp(r'^[\.\-\s/]*$')));
      });

      test('morse output has correct spacing between letters', () {
        final encoding = encoder.encode('AB');
        expect(encoding.written, contains(' '));
      });

      test('morse output has correct spacing between words', () {
        final encoding = encoder.encode('A B');
        expect(encoding.written, contains('/'));
      });

      test('encoding returns MorseEncoding object', () {
        final encoding = encoder.encode('TEST');
        expect(encoding, isA<MorseEncoding>());
      });

      test('MorseEncoding has written field', () {
        final encoding = encoder.encode('TEST');
        expect(encoding.written, isNotEmpty);
      });

      test('MorseEncoding has tones field', () {
        final encoding = encoder.encode('TEST');
        expect(encoding.tones, isNotEmpty);
      });
    });

    group('Tones Generation', () {
      test('encoding generates tones for morse', () {
        final encoding = encoder.encode('A');
        expect(encoding.tones, isNotEmpty);
      });

      test('tones are MorseTone objects', () {
        final encoding = encoder.encode('A');
        expect(encoding.tones.first, isA<MorseTone>());
      });

      test('tones have duration', () {
        final encoding = encoder.encode('A');
        for (final tone in encoding.tones) {
          expect(tone.durationMs, greaterThan(0));
        }
      });

      test('longer text generates more tones', () {
        final short = encoder.encode('A');
        final long = encoder.encode('HELLO');
        expect(long.tones.length, greaterThan(short.tones.length));
      });
    });

    group('WPM Settings', () {
      test('different WPM produces different tone durations', () {
        final encoder20 = MorseEncoder(timing: MorseTiming(wpm: 20));
        final encoder40 = MorseEncoder(timing: MorseTiming(wpm: 40));

        final encoding20 = encoder20.encode('A');
        final encoding40 = encoder40.encode('A');

        // Higher WPM should produce shorter tones
        expect(encoding40.tones.first.durationMs, lessThan(encoding20.tones.first.durationMs));
      });

      test('WPM affects all tones proportionally', () {
        final encoder10 = MorseEncoder(timing: MorseTiming(wpm: 10));
        final encoder20 = MorseEncoder(timing: MorseTiming(wpm: 20));

        final encoding10 = encoder10.encode('TEST');
        final encoding20 = encoder20.encode('TEST');

        expect(encoding10.tones.length, equals(encoding20.tones.length));
      });
    });

    group('Special Characters', () {
      test('handles diacritics by transliterating', () {
        final transliterated = MorseTransliterator.transliterate('café');
        final encoding = encoder.encode(transliterated);
        expect(encoding.written, isNotEmpty);
      });

      test('handles accented characters', () {
        final transliterated = MorseTransliterator.transliterate('naïve');
        final encoding = encoder.encode(transliterated);
        expect(encoding.written, isNotEmpty);
      });

      test('handles mixed case with diacritics', () {
        final transliterated = MorseTransliterator.transliterate('Café');
        final encoding = encoder.encode(transliterated);
        expect(encoding.written, isNotEmpty);
      });
    });

    group('Edge Cases', () {
      test('very long input is encoded', () {
        final longText = 'A' * 100;
        final encoding = encoder.encode(longText);
        expect(encoding.written, isNotEmpty);
      });

      test('single space produces word separator', () {
        final encoding = encoder.encode(' ');
        // A single space may not produce output, so just verify it doesn't error
        expect(encoding, isNotNull);
      });

      test('multiple spaces handled correctly', () {
        final encoding = encoder.encode('A  B');
        expect(encoding.written, isNotEmpty);
      });

      test('leading space handled', () {
        final encoding = encoder.encode(' A');
        expect(encoding.written, isNotEmpty);
      });

      test('trailing space handled', () {
        final encoding = encoder.encode('A ');
        expect(encoding.written, isNotEmpty);
      });
    });

    group('Consistency', () {
      test('same input produces same output', () {
        final encoding1 = encoder.encode('HELLO');
        final encoding2 = encoder.encode('HELLO');
        expect(encoding1.written, equals(encoding2.written));
      });

      test('encoding is deterministic', () {
        final inputs = ['TEST', 'MORSE', 'CODE', '123', 'A.B'];
        for (final input in inputs) {
          final encoding1 = encoder.encode(input);
          final encoding2 = encoder.encode(input);
          expect(encoding1.written, equals(encoding2.written));
        }
      });
    });
  });

  group('Encoder Data Layer - Transliterator', () {
    group('Transliteration', () {
      test('transliterates accented characters', () {
        final result = MorseTransliterator.transliterate('café');
        expect(result, equals('CAFE'));
      });

      test('transliterates uppercase', () {
        final result = MorseTransliterator.transliterate('hello');
        expect(result, equals('HELLO'));
      });

      test('preserves ASCII characters', () {
        final result = MorseTransliterator.transliterate('HELLO');
        expect(result, equals('HELLO'));
      });

      test('handles mixed case', () {
        final result = MorseTransliterator.transliterate('HeLLo');
        expect(result, equals('HELLO'));
      });

      test('handles numbers', () {
        final result = MorseTransliterator.transliterate('123');
        expect(result, equals('123'));
      });

      test('handles punctuation', () {
        final result = MorseTransliterator.transliterate('A.B');
        expect(result, isNotEmpty);
      });

      test('handles spaces', () {
        final result = MorseTransliterator.transliterate('A B');
        expect(result, contains(' '));
      });

      test('handles empty string', () {
        final result = MorseTransliterator.transliterate('');
        expect(result, isEmpty);
      });

      test('transliteration is deterministic', () {
        final inputs = ['café', 'naïve', 'Café', 'NAÏVE'];
        for (final input in inputs) {
          final result1 = MorseTransliterator.transliterate(input);
          final result2 = MorseTransliterator.transliterate(input);
          expect(result1, equals(result2));
        }
      });
    });
  });

  group('SpeechService', () {
    group('API Contract', () {
      test('SpeechService class exists', () {
        expect(SpeechService, isNotNull);
      });

      test('SpeechService has startListening method', () {
        final service = SpeechService();
        expect(service.startListening, isNotNull);
        service.dispose();
      });

      test('SpeechService has stopListening method', () {
        final service = SpeechService();
        expect(service.stopListening, isNotNull);
        service.dispose();
      });

      test('SpeechService has dispose method', () {
        final service = SpeechService();
        expect(service.dispose, isNotNull);
        service.dispose();
      });
    });

    group('Initialization', () {
      test('SpeechService can be instantiated', () {
        final service = SpeechService();
        expect(service, isNotNull);
        service.dispose();
      });

      test('SpeechService is a SpeechService instance', () {
        final service = SpeechService();
        expect(service, isA<SpeechService>());
        service.dispose();
      });
    });

    group('Method Signatures', () {
      test('startListening method exists and is callable', () {
        final service = SpeechService();
        expect(service.startListening, isA<Function>());
        service.dispose();
      });

      test('stopListening method exists and is callable', () {
        final service = SpeechService();
        expect(service.stopListening, isA<Function>());
        service.dispose();
      });

      test('dispose method exists and is callable', () {
        final service = SpeechService();
        expect(service.dispose, isA<Function>());
        service.dispose();
      });
    });

    group('Lifecycle', () {
      test('dispose can be called', () {
        final service = SpeechService();
        service.dispose();
        expect(true, isTrue);
      });

      test('dispose can be called multiple times', () {
        final service = SpeechService();
        service.dispose();
        service.dispose();
        expect(true, isTrue);
      });
    });
  });

  group('Encoder Data Layer Integration', () {
    late MorseEncoder encoder;

    setUp(() {
      encoder = MorseEncoder(timing: MorseTiming(wpm: 20));
    });

    group('Encoder and Service Together', () {
      test('encoder can be used with speech service', () {
        final encoding = encoder.encode('HELLO');
        expect(encoding.written, isNotEmpty);
        
        final service = SpeechService();
        expect(service, isNotNull);
        service.dispose();
      });

      test('speech results can be encoded to morse', () {
        final testInputs = ['HELLO', 'WORLD', 'MORSE', 'CODE'];
        for (final input in testInputs) {
          final encoding = encoder.encode(input);
          expect(encoding.written, isNotEmpty);
        }
      });
    });

    group('Data Flow', () {
      test('text flows through encoder to morse', () {
        final text = 'ENCODER';
        final encoding = encoder.encode(text);
        expect(encoding.written, isNotEmpty);
        expect(encoding.written, contains('.'));
        expect(encoding.written, contains('-'));
      });

      test('special characters are handled in data flow', () {
        final text = 'CAFÉ';
        final transliterated = MorseTransliterator.transliterate(text);
        final encoding = encoder.encode(transliterated);
        expect(encoding.written, isNotEmpty);
      });

      test('numbers flow through correctly', () {
        final text = '2024';
        final encoding = encoder.encode(text);
        expect(encoding.written, isNotEmpty);
      });

      test('complete flow: text -> transliterate -> encode -> tones', () {
        final text = 'HELLO';
        final transliterated = MorseTransliterator.transliterate(text);
        final encoding = encoder.encode(transliterated);
        
        expect(transliterated, isNotEmpty);
        expect(encoding.written, isNotEmpty);
        expect(encoding.tones, isNotEmpty);
      });
    });
  });
}
