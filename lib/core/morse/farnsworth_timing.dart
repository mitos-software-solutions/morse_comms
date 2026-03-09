import 'morse_timing.dart';

/// Farnsworth timing: characters are sent at [charWpm] speed, but
/// inter-character and inter-word gaps are stretched so the overall
/// effective copy rate is [effectiveWpm] (must be ≤ [charWpm]).
///
/// Formula (PARIS standard):
///   PARIS characters occupy 31 units at charWpm.
///   PARIS full word takes 60 000 / effectiveWpm ms total.
///   There are 19 spacing units in PARIS (4 letter-gaps × 3 + 1 word-gap × 7).
///   spacingUnit = (60 000 / effectiveWpm − 31 × charUnitMs) / 19
///
/// When effectiveWpm == charWpm the result equals standard ITU timing.
class FarnsworthTiming extends MorseTiming {
  final int effectiveWpm;

  FarnsworthTiming({required int charWpm, required this.effectiveWpm})
      : assert(effectiveWpm >= 1 && effectiveWpm <= charWpm,
            'effectiveWpm must be between 1 and charWpm'),
        super(wpm: charWpm);

  double get _spacingUnitMs =>
      (60000.0 / effectiveWpm - 31.0 * (1200.0 / wpm)) / 19.0;

  @override
  int get letterGapMs => (_spacingUnitMs * 3).round().clamp(unitMs * 3, 99999);

  @override
  int get wordGapMs => (_spacingUnitMs * 7).round().clamp(unitMs * 7, 99999);
}
