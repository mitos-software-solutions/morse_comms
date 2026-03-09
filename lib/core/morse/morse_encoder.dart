import 'morse_table.dart';
import 'morse_timing.dart';

/// A single on/off interval in a Morse audio sequence.
class MorseTone {
  /// true = beep (tone on), false = silence (tone off).
  final bool on;
  final int durationMs;

  const MorseTone({required this.on, required this.durationMs});

  @override
  String toString() => '${on ? "ON" : "OFF"}(${durationMs}ms)';
}

/// Result of encoding a text string into Morse.
class MorseEncoding {
  /// Human-readable Morse string, e.g. "... --- ..."
  /// Letters separated by spaces, words separated by " / ".
  final String written;

  /// Flat sequence of on/off intervals for audio playback.
  final List<MorseTone> tones;

  const MorseEncoding({required this.written, required this.tones});
}

/// Encodes plain text into Morse code (written form + audio sequence).
class MorseEncoder {
  final MorseTiming timing;

  const MorseEncoder({required this.timing});

  /// Encodes [text] into a [MorseEncoding].
  ///
  /// - Unknown characters are silently skipped.
  /// - Case-insensitive.
  /// - Multiple consecutive spaces are treated as a single word gap.
  MorseEncoding encode(String text) {
    final words = text.trim().toUpperCase().split(RegExp(r'\s+'));
    final writtenWords = <String>[];
    final tones = <MorseTone>[];

    for (int wi = 0; wi < words.length; wi++) {
      final word = words[wi];
      final encodedChars = <String>[];

      for (int ci = 0; ci < word.length; ci++) {
        final pattern = kMorseTable[word[ci]];
        if (pattern == null) continue; // skip unknown characters

        encodedChars.add(pattern);

        // Build tones for this character's dot/dash pattern.
        for (int si = 0; si < pattern.length; si++) {
          final isDash = pattern[si] == '-';
          tones.add(MorseTone(
            on: true,
            durationMs: isDash ? timing.dashMs : timing.dotMs,
          ));
          // Inter-symbol gap after each symbol except the last in the char.
          if (si < pattern.length - 1) {
            tones.add(MorseTone(on: false, durationMs: timing.symbolGapMs));
          }
        }

        // Inter-letter gap after each character except the last in the word.
        final isLastCharInWord = (ci == word.length - 1) ||
            _remainingCharsAllUnknown(word, ci + 1);
        if (!isLastCharInWord) {
          tones.add(MorseTone(on: false, durationMs: timing.letterGapMs));
        }
      }

      if (encodedChars.isNotEmpty) {
        writtenWords.add(encodedChars.join(' '));
        // Word gap after each word except the last.
        if (wi < words.length - 1) {
          tones.add(MorseTone(on: false, durationMs: timing.wordGapMs));
        }
      }
    }

    return MorseEncoding(
      written: writtenWords.join(' / '),
      tones: tones,
    );
  }

  bool _remainingCharsAllUnknown(String word, int fromIndex) {
    for (int i = fromIndex; i < word.length; i++) {
      if (kMorseTable.containsKey(word[i])) return false;
    }
    return true;
  }

  /// Converts a dot/dash pattern string to its written Morse representation.
  /// Returns null if the pattern is not in the table.
  static String? decode(String pattern) => kMorseTableReverse[pattern];
}
