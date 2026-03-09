import '../morse/morse_table.dart';

/// Classifies an inter-symbol silence into one of three gap types.
enum GapType {
  /// Gap between dots/dashes within one character (≈ 1 unit).
  symbol,

  /// Gap between characters within one word (≈ 3 units).
  letter,

  /// Gap between words (≈ 7 units).
  word,
}

/// Adaptive timing estimator.
///
/// Learns dot and dash durations from observed ON events using an exponential
/// moving average.
///
/// Bootstrap strategy — deferred first-symbol:
///   The very first ON event is held as [_pendingFirstMs] without being
///   classified. When the next gap (OFF event) arrives, the ON/gap ratio
///   tells us whether the first event was a dot or dash:
///     • ratio ≈ 1  → first was a dot, gap was a symbol gap
///     • ratio ≈ 3  → first was a dash, gap was a symbol gap
///     • ratio ≈ 1/3 → first was a dot, gap was a letter gap
///   This is WPM-agnostic: works correctly whether the first symbol is a
///   dot or a dash, at any speed from 5–25 WPM.
///   If two ON events arrive before any gap, the ratio of the two events
///   is used instead.
class AdaptiveTiming {
  double? _dotMs;
  double? _dashMs;
  double? _pendingFirstMs; // holds first ON until gap-based bootstrap

  // EMA weight for updating existing estimates (0.85 = slow, stable tracking).
  static const double _alpha = 0.85;

  /// True while the first ON event is still pending gap-based bootstrap.
  bool get hasPendingBootstrap => _pendingFirstMs != null;

  /// Observe an ON event duration.
  ///
  /// Returns the retroactively-determined symbol (`'.'` or `'-'`) for the
  /// *pending* first event when a two-ON-without-gap bootstrap completes,
  /// or null in all other cases.
  String? observeOn(double durationMs) {
    if (_dotMs == null) {
      if (_pendingFirstMs == null) {
        // First ever ON: defer until we see a gap.
        _pendingFirstMs = durationMs;
        return null;
      }
      // Second ON before any gap: bootstrap from the two-event ratio.
      return _twoEventBootstrap(_pendingFirstMs!, durationMs);
    }

    if (_dashMs == null) {
      if (durationMs > _dotMs! * 2.0) {
        _dashMs = durationMs;
      } else {
        _dotMs = _dotMs! * _alpha + durationMs * (1 - _alpha);
      }
      return null;
    }

    final mid = (_dotMs! + _dashMs!) / 2.0;
    if (durationMs <= mid) {
      _dotMs = _dotMs! * _alpha + durationMs * (1 - _alpha);
    } else {
      _dashMs = _dashMs! * _alpha + durationMs * (1 - _alpha);
    }
    return null;
  }

  /// Bootstrap from a gap that follows the pending first ON event.
  ///
  /// Returns the symbol (`'.'` or `'-'`) for the deferred first ON event,
  /// or null if there was no pending event.
  String? bootstrapFromGap(double gapMs) {
    if (_pendingFirstMs == null) return null;
    final first = _pendingFirstMs!;
    _pendingFirstMs = null;
    final ratio = first / gapMs;
    if (ratio > 2.0) {
      // first ≈ 3× gap → first was a dash, gap was a symbol gap
      _dotMs = gapMs;
      _dashMs = first;
      return '-';
    } else {
      // ratio ≈ 1 or < 0.5 → first was a dot (gap is symbol or letter gap)
      _dotMs = first;
      return '.';
    }
  }

  /// Classify an ON duration as dot (true) or dash (false).
  bool isDot(double durationMs) {
    if (_dotMs == null) return true; // shouldn't occur post-bootstrap
    if (_dashMs == null) return durationMs <= _dotMs! * 2.0;
    return durationMs <= (_dotMs! + _dashMs!) / 2.0;
  }

  /// Classify an OFF duration as a symbol, letter, or word gap.
  GapType classifyGap(double durationMs) {
    final unit = _dotMs ?? 60.0; // fall back to 20 WPM if uncalibrated
    if (durationMs < unit * 2.0) return GapType.symbol;
    if (durationMs < unit * 5.0) return GapType.letter;
    return GapType.word;
  }

  /// True once at least one ON event has been fully classified (timing known).
  /// Gap events received before this point cannot be reliably classified and
  /// should be ignored to avoid spurious spaces in the output.
  bool get isCalibrated => _dotMs != null;

  /// Best current estimate of one unit (dot) duration in ms.
  double get estimatedUnitMs => _dotMs ?? 60.0;

  /// Commit the pending first ON event with a best-effort classification,
  /// using the fallback 60 ms unit when no gap has been seen yet.
  /// Returns the symbol, or null if there was nothing pending.
  String? flushPending() {
    if (_pendingFirstMs == null) return null;
    final ms = _pendingFirstMs!;
    _pendingFirstMs = null;
    _dotMs ??= 60.0; // fallback: assume 20 WPM
    return ms <= _dotMs! * 2.0 ? '.' : '-';
  }

  /// Reset all learned state.
  void reset() {
    _dotMs = null;
    _dashMs = null;
    _pendingFirstMs = null;
  }

  // ── Private ──────────────────────────────────────────────────────────────

  /// Bootstrap using only two consecutive ON events (no gap available).
  /// Returns the retroactive symbol for the first event.
  String _twoEventBootstrap(double first, double second) {
    _pendingFirstMs = null;
    if (second > first * 2.0) {
      // first was a dot, second is a dash
      _dotMs = first;
      _dashMs = second;
      return '.';
    } else if (first > second * 2.0) {
      // first was a dash, second is a dot
      _dotMs = second;
      _dashMs = first;
      return '-';
    } else {
      // Both similar lengths — treat both as dots
      _dotMs = (first + second) / 2.0;
      return '.';
    }
  }
}

/// Decodes a stream of tone ON/OFF events into plain text.
///
/// Feed events via [processEvent]. Call [flush] after the final event to
/// finalise any character still in progress. Read output via [decodedText].
///
/// Example:
/// ```dart
/// final decoder = MorseDecoder();
/// decoder.processEvent(on: true,  durationMs: 60);   // dot
/// decoder.processEvent(on: false, durationMs: 60);   // symbol gap
/// decoder.processEvent(on: true,  durationMs: 180);  // dash
/// decoder.processEvent(on: false, durationMs: 180);  // letter gap
/// decoder.flush();
/// print(decoder.decodedText); // "A"
/// ```
class MorseDecoder {
  final AdaptiveTiming timing;

  MorseDecoder({AdaptiveTiming? timing})
      : timing = timing ?? AdaptiveTiming();

  final StringBuffer _pattern = StringBuffer();
  final StringBuffer _output = StringBuffer();

  /// Accumulated decoded text.
  String get decodedText => _output.toString();

  /// Process one tone ON or OFF event.
  ///
  /// [on]  — true = tone was present, false = silence.
  /// [durationMs] — how long this state lasted.
  void processEvent({required bool on, required int durationMs}) {
    if (on) {
      final retroSymbol = timing.observeOn(durationMs.toDouble());
      if (retroSymbol != null) {
        // Two-ON bootstrap completed: write the retroactively-fixed first symbol.
        _pattern.write(retroSymbol);
      }
      if (timing.hasPendingBootstrap) return; // first event deferred; wait for gap
      final sym = timing.isDot(durationMs.toDouble()) ? '.' : '-';
      _pattern.write(sym);
      // ignore: avoid_print
      print('[MorseDbg] ON  ${durationMs}ms → $sym'
          ' (dot≈${timing.estimatedUnitMs.toStringAsFixed(1)}ms)');
    } else {
      // Try gap-based bootstrap for the deferred first ON event.
      final firstSymbol = timing.bootstrapFromGap(durationMs.toDouble());
      if (firstSymbol != null) _pattern.write(firstSymbol);

      // Skip gap classification until timing is calibrated (i.e. at least one
      // ON event has been observed). A leading silence before any tone has no
      // useful timing reference — classifying it would produce spurious spaces.
      if (!timing.isCalibrated) return;

      final gap = timing.classifyGap(durationMs.toDouble());
      // ignore: avoid_print
      print('[MorseDbg] OFF ${durationMs}ms → $gap'
          ' (unit≈${timing.estimatedUnitMs.toStringAsFixed(1)}ms)');
      switch (gap) {
        case GapType.symbol:
          break;
        case GapType.letter:
          _commitChar();
        case GapType.word:
          _commitChar();
          _output.write(' ');
      }
    }
  }

  /// Finalise the character currently being accumulated (if any).
  ///
  /// Also commits any pending bootstrap symbol that never received a gap.
  void flush() {
    final sym = timing.flushPending();
    if (sym != null) _pattern.write(sym);
    _commitChar();
  }

  /// Reset decoded text and adaptive timing. Call at start of a new session.
  void reset() {
    _pattern.clear();
    _output.clear();
    timing.reset();
  }

  void _commitChar() {
    if (_pattern.isEmpty) return;
    final pattern = _pattern.toString();
    _pattern.clear();
    final char = kMorseTableReverse[pattern];
    // ignore: avoid_print
    print('[MorseDbg] commit: "$pattern" → "${char ?? "?"}"');
    if (char != null) _output.write(char);
  }
}
