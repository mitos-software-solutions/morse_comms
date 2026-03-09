/// Morse timing constants and WPM math.
///
/// Based on the PARIS standard: one "word" = 50 dot units.
/// At [wpm] words per minute: unit duration = 1200 / wpm milliseconds.
///
/// Standard ratios (ITU-R M.1677):
///   Dot       = 1 unit
///   Dash      = 3 units
///   Symbol gap (within a character) = 1 unit
///   Letter gap (between characters) = 3 units
///   Word gap   (between words)       = 7 units
class MorseTiming {
  final int wpm;

  const MorseTiming({required this.wpm})
      : assert(wpm >= 5 && wpm <= 40, 'WPM must be between 5 and 40');

  /// Duration of one unit in milliseconds.
  int get unitMs => 1200 ~/ wpm;

  int get dotMs => unitMs;
  int get dashMs => unitMs * 3;
  int get symbolGapMs => unitMs;
  int get letterGapMs => unitMs * 3;
  int get wordGapMs => unitMs * 7;

  static const int defaultWpm = 20;
  static const int defaultFrequencyHz = 700;
  static const int minWpm = 5;
  static const int maxWpm = 40;
}
