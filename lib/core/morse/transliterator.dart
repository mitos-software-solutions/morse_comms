/// Converts arbitrary Unicode text to Morse-safe ASCII.
///
/// Handles:
///   - Latin diacritics (é→E, ü→U, ñ→N, ç→C, ß→SS …)
///   - Cyrillic (Russian, Ukrainian, Bulgarian, Serbian)
///   - Greek
///
/// Characters with no mapping are passed through unchanged; the Morse encoder
/// will silently skip anything it cannot encode.
class MorseTransliterator {
  const MorseTransliterator._();

  /// Transliterates [text] to uppercase ASCII ready for Morse encoding.
  ///
  /// Returns the transliterated string (always uppercase). If no mapping
  /// exists for a character it is left as-is — the encoder drops unknowns.
  static String transliterate(String text) {
    if (text.isEmpty) return text;
    final buf = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      buf.write(_map[ch] ?? ch.toUpperCase());
    }
    return buf.toString();
  }

  /// True when [text] contains characters that will be transliterated,
  /// i.e. the result differs from simply uppercasing [text].
  static bool needsTransliteration(String text) =>
      text.runes.any((r) => r > 127);

  // ---------------------------------------------------------------------------
  // Transliteration table
  // All mapped values are already UPPERCASE.
  // ---------------------------------------------------------------------------
  static const Map<String, String> _map = {
    // -------------------------------------------------------------------------
    // Latin diacritics — covers ES, FR, DE, PT, IT, NL, PL, CS, SK, RO …
    // -------------------------------------------------------------------------
    'À': 'A',  'Á': 'A',  'Â': 'A',  'Ã': 'A',  'Ä': 'A',  'Å': 'A',
    'à': 'A',  'á': 'A',  'â': 'A',  'ã': 'A',  'ä': 'A',  'å': 'A',
    'Æ': 'AE', 'æ': 'AE',
    'Ç': 'C',  'ç': 'C',
    'Č': 'C',  'č': 'C',  'Ć': 'C',  'ć': 'C',
    'Ð': 'D',  'ð': 'D',  'Đ': 'D',  'đ': 'D',
    'È': 'E',  'É': 'E',  'Ê': 'E',  'Ë': 'E',
    'è': 'E',  'é': 'E',  'ê': 'E',  'ë': 'E',
    'Ě': 'E',  'ě': 'E',
    'Ì': 'I',  'Í': 'I',  'Î': 'I',  'Ï': 'I',
    'ì': 'I',  'í': 'I',  'î': 'I',  'ï': 'I',
    'Ł': 'L',  'ł': 'L',
    'Ñ': 'N',  'ñ': 'N',  'Ń': 'N',  'ń': 'N',
    'Ò': 'O',  'Ó': 'O',  'Ô': 'O',  'Õ': 'O',  'Ö': 'O',  'Ø': 'O',
    'ò': 'O',  'ó': 'O',  'ô': 'O',  'õ': 'O',  'ö': 'O',  'ø': 'O',
    'Œ': 'OE', 'œ': 'OE',
    'Ř': 'R',  'ř': 'R',
    'Š': 'S',  'š': 'S',  'Ś': 'S',  'ś': 'S',  'ß': 'SS',
    'Þ': 'TH', 'þ': 'TH',
    'Ù': 'U',  'Ú': 'U',  'Û': 'U',  'Ü': 'U',
    'ù': 'U',  'ú': 'U',  'û': 'U',  'ü': 'U',
    'Ý': 'Y',  'ý': 'Y',  'ÿ': 'Y',
    'Ž': 'Z',  'ž': 'Z',  'Ź': 'Z',  'ź': 'Z',  'Ż': 'Z',  'ż': 'Z',

    // -------------------------------------------------------------------------
    // Cyrillic — Russian, Ukrainian, Bulgarian, Serbian (GOST 7.79-2000 / BGN)
    // -------------------------------------------------------------------------
    'А': 'A',  'а': 'A',
    'Б': 'B',  'б': 'B',
    'В': 'V',  'в': 'V',
    'Г': 'G',  'г': 'G',
    'Д': 'D',  'д': 'D',
    'Е': 'E',  'е': 'E',
    'Ё': 'YO', 'ё': 'YO',
    'Ж': 'ZH', 'ж': 'ZH',
    'З': 'Z',  'з': 'Z',
    'И': 'I',  'и': 'I',
    'Й': 'Y',  'й': 'Y',
    'К': 'K',  'к': 'K',
    'Л': 'L',  'л': 'L',
    'М': 'M',  'м': 'M',
    'Н': 'N',  'н': 'N',
    'О': 'O',  'о': 'O',
    'П': 'P',  'п': 'P',
    'Р': 'R',  'р': 'R',
    'С': 'S',  'с': 'S',
    'Т': 'T',  'т': 'T',
    'У': 'U',  'у': 'U',
    'Ф': 'F',  'ф': 'F',
    'Х': 'KH', 'х': 'KH',
    'Ц': 'TS', 'ц': 'TS',
    'Ч': 'CH', 'ч': 'CH',
    'Ш': 'SH', 'ш': 'SH',
    'Щ': 'SHCH','щ': 'SHCH',
    'Ъ': '',   'ъ': '',   // hard sign — silent
    'Ы': 'Y',  'ы': 'Y',
    'Ь': '',   'ь': '',   // soft sign — silent
    'Э': 'E',  'э': 'E',
    'Ю': 'YU', 'ю': 'YU',
    'Я': 'YA', 'я': 'YA',
    // Ukrainian extras
    'І': 'I',  'і': 'I',
    'Ї': 'YI', 'ї': 'YI',
    'Є': 'YE', 'є': 'YE',
    'Ґ': 'G',  'ґ': 'G',
    // Serbian extras
    'Ђ': 'DJ', 'ђ': 'DJ',
    'Ј': 'J',  'ј': 'J',
    'Љ': 'LJ', 'љ': 'LJ',
    'Њ': 'NJ', 'њ': 'NJ',
    'Ћ': 'C',  'ћ': 'C',
    'Џ': 'DZ', 'џ': 'DZ',

    // -------------------------------------------------------------------------
    // Greek (modern monotonic, ISO 843)
    // -------------------------------------------------------------------------
    'Α': 'A',  'α': 'A',
    'Β': 'V',  'β': 'V',
    'Γ': 'G',  'γ': 'G',
    'Δ': 'D',  'δ': 'D',
    'Ε': 'E',  'ε': 'E',
    'Ζ': 'Z',  'ζ': 'Z',
    'Η': 'I',  'η': 'I',
    'Θ': 'TH', 'θ': 'TH',
    'Ι': 'I',  'ι': 'I',
    'Κ': 'K',  'κ': 'K',
    'Λ': 'L',  'λ': 'L',
    'Μ': 'M',  'μ': 'M',
    'Ν': 'N',  'ν': 'N',
    'Ξ': 'X',  'ξ': 'X',
    'Ο': 'O',  'ο': 'O',
    'Π': 'P',  'π': 'P',
    'Ρ': 'R',  'ρ': 'R',
    'Σ': 'S',  'σ': 'S',  'ς': 'S',
    'Τ': 'T',  'τ': 'T',
    'Υ': 'Y',  'υ': 'Y',
    'Φ': 'F',  'φ': 'F',
    'Χ': 'CH', 'χ': 'CH',
    'Ψ': 'PS', 'ψ': 'PS',
    'Ω': 'O',  'ω': 'O',
    // Greek with tonos
    'Ά': 'A',  'ά': 'A',
    'Έ': 'E',  'έ': 'E',
    'Ή': 'I',  'ή': 'I',
    'Ί': 'I',  'ί': 'I',
    'Ό': 'O',  'ό': 'O',
    'Ύ': 'Y',  'ύ': 'Y',
    'Ώ': 'O',  'ώ': 'O',
  };
}
