/// Farnsworth method level definition.
///
/// Characters are sent at [charWpm] so they sound correct at target speed,
/// but inter-character / inter-word gaps are stretched to reach [effectiveWpm].
/// As the student advances, the gaps tighten until they match character speed,
/// then both speeds climb together toward expert rates.
class FarnsworthLevel {
  final int charWpm;
  final int effectiveWpm;
  final String label;
  final String description;

  const FarnsworthLevel({
    required this.charWpm,
    required this.effectiveWpm,
    required this.label,
    required this.description,
  });
}

/// Ten Farnsworth levels, all free, using the full 36-character set.
///
/// Levels 1–6: character speed locked at 15 WPM, effective copy speed rises
///   from 5 WPM (maximum spacing) to 15 WPM (full speed, no stretch).
/// Levels 7–10: character and effective speed climb together (20 / 25 / 30 WPM),
///   building toward expert copy rates.
const List<FarnsworthLevel> kFarnsworthLevels = [
  FarnsworthLevel(
    charWpm: 15,
    effectiveWpm: 5,
    label: 'F-1 — 5 WPM copy',
    description: 'Maximum spacing. Characters at 15 WPM, wide gaps.',
  ),
  FarnsworthLevel(
    charWpm: 15,
    effectiveWpm: 7,
    label: 'F-2 — 7 WPM copy',
    description: 'Characters at 15 WPM, gaps narrowing.',
  ),
  FarnsworthLevel(
    charWpm: 15,
    effectiveWpm: 9,
    label: 'F-3 — 9 WPM copy',
    description: 'Characters at 15 WPM, medium spacing.',
  ),
  FarnsworthLevel(
    charWpm: 15,
    effectiveWpm: 11,
    label: 'F-4 — 11 WPM copy',
    description: 'Characters at 15 WPM, spacing tightening.',
  ),
  FarnsworthLevel(
    charWpm: 15,
    effectiveWpm: 13,
    label: 'F-5 — 13 WPM copy',
    description: 'Characters at 15 WPM, nearly standard spacing.',
  ),
  FarnsworthLevel(
    charWpm: 15,
    effectiveWpm: 15,
    label: 'F-6 — 15 WPM full',
    description: 'Standard ITU timing at 15 WPM. No Farnsworth stretch.',
  ),
  FarnsworthLevel(
    charWpm: 18,
    effectiveWpm: 18,
    label: 'F-7 — 18 WPM',
    description: 'Standard timing at 18 WPM.',
  ),
  FarnsworthLevel(
    charWpm: 20,
    effectiveWpm: 20,
    label: 'F-8 — 20 WPM',
    description: 'Standard timing at 20 WPM. General Class copy speed.',
  ),
  FarnsworthLevel(
    charWpm: 25,
    effectiveWpm: 25,
    label: 'F-9 — 25 WPM',
    description: 'Standard timing at 25 WPM. Extra Class territory.',
  ),
  FarnsworthLevel(
    charWpm: 30,
    effectiveWpm: 30,
    label: 'F-10 — 30 WPM',
    description: 'Standard timing at 30 WPM. Contest / QRQ operator.',
  ),
];

/// Full 36-character set used in every Farnsworth level.
const List<String> kFarnsworthChars = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
];
