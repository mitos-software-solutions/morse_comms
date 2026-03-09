/// ITU Morse code lookup table.
/// Keys are uppercase characters. Values are dot/dash pattern strings.
const Map<String, String> kMorseTable = {
  // Letters
  'A': '.-',
  'B': '-...',
  'C': '-.-.',
  'D': '-..',
  'E': '.',
  'F': '..-.',
  'G': '--.',
  'H': '....',
  'I': '..',
  'J': '.---',
  'K': '-.-',
  'L': '.-..',
  'M': '--',
  'N': '-.',
  'O': '---',
  'P': '.--.',
  'Q': '--.-',
  'R': '.-.',
  'S': '...',
  'T': '-',
  'U': '..-',
  'V': '...-',
  'W': '.--',
  'X': '-..-',
  'Y': '-.--',
  'Z': '--..',

  // Digits
  '0': '-----',
  '1': '.----',
  '2': '..---',
  '3': '...--',
  '4': '....-',
  '5': '.....',
  '6': '-....',
  '7': '--...',
  '8': '---..',
  '9': '----.',

  // Punctuation
  '.': '.-.-.-',
  ',': '--..--',
  '?': '..--..',
  "'": '.----.',
  '!': '-.-.--',
  '/': '-..-.',
  '(': '-.--.',
  ')': '-.--.-',
  '&': '.-...',
  ':': '---...',
  ';': '-.-.-.',
  '=': '-...-',
  '+': '.-.-.',
  '-': '-....-',
  '"': '.-..-.',
  '@': '.--.-.',

  // Extended Latin — European characters
  // Where two variants share a pattern both keys are included.
  'À': '.--.-',   // A-grave  (French); same pattern as Å
  'Å': '.--.-',   // A-ring   (Scandinavian)
  'Ä': '.-.-',    // A-umlaut (German/Swedish); same pattern as Æ
  'Æ': '.-.-',    // AE       (Danish/Norwegian)
  'É': '..-..', // E-acute  (French)
  'È': '.-..-', // E-grave  (French)
  'Ñ': '--.-.', // N-tilde  (Spanish)
  'Ö': '---.',  // O-umlaut (German/Swedish); same pattern as Ø
  'Ø': '---.',  // O-slash  (Danish/Norwegian)
  'Ü': '..--.', // U-umlaut (German)

  // Esperanto extensions
  'Ĥ': '----',   // H-circumflex
  'Ĵ': '.---.', // J-circumflex
  'Ŝ': '...-.',  // S-circumflex
  'Ŭ': '..--',  // U-breve
};

/// Reverse lookup: dot/dash pattern → character.
/// Note: where multiple chars share a pattern (e.g. À/Å, Ä/Æ) only one
/// is stored here (last write wins in the map literal).
final Map<String, String> kMorseTableReverse = {
  for (final entry in kMorseTable.entries) entry.value: entry.key,
};

// ---------------------------------------------------------------------------
// Prosigns
// ---------------------------------------------------------------------------

/// A Morse procedural sign (prosign).
///
/// Prosigns are sent as a single continuous unit — no inter-character gaps
/// between the component letters. They share some patterns with punctuation
/// marks (e.g. AR = +, BT = =, AS = &) but carry a distinct operational
/// meaning.
class MorseProsign {
  final String code;        // e.g. 'AR'
  final String pattern;     // e.g. '.-.-.'
  final String description; // e.g. 'End of message'
  final String? note;       // optional equivalence note

  const MorseProsign({
    required this.code,
    required this.pattern,
    required this.description,
    this.note,
  });
}

const List<MorseProsign> kProsigns = [
  MorseProsign(
    code: 'CT',
    pattern: '-.-.-',
    description: 'Start of transmission (Commence)',
    note: 'Also written KA',
  ),
  MorseProsign(
    code: 'AR',
    pattern: '.-.-.',
    description: 'End of message',
    note: 'Same pattern as +',
  ),
  MorseProsign(
    code: 'AS',
    pattern: '.-...',
    description: 'Wait / Stand by',
    note: 'Same pattern as &',
  ),
  MorseProsign(
    code: 'BT',
    pattern: '-...-',
    description: 'Break / New paragraph',
    note: 'Same pattern as =',
  ),
  MorseProsign(
    code: 'KN',
    pattern: '-.--.',
    description: 'Go ahead — invited station only',
    note: 'Same pattern as (',
  ),
  MorseProsign(
    code: 'SK',
    pattern: '...-.-',
    description: 'End of contact / Sign off',
  ),
  MorseProsign(
    code: 'SOS',
    pattern: '...---...',
    description: 'International distress signal',
    note: 'Sent as one unbroken sequence — no letter gaps',
  ),
  MorseProsign(
    code: 'HH',
    pattern: '........',
    description: 'Error — correction follows',
  ),
];
