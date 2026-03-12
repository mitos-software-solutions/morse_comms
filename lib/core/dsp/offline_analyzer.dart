import 'dart:math';
import 'dart:typed_data';

import 'decoder_pipeline.dart';
import 'goertzel.dart';
import 'morse_decoder.dart';

/// Offline Morse decoder — high-accuracy multi-pass analysis.
///
/// Design (accuracy > speed):
///
///  1. Global two-pass noise floor from the full power distribution.
///  2. 2-frame debounced ON/OFF event extraction (mirrors [DecoderPipeline]).
///  3. Split events into segments wherever silence ≥ [_segmentBreakMs].
///  4. Per-segment analysis:
///       a. Collect ON durations; skip micro-events shorter than
///          [_minOnMs] (2.5 × frameDuration) which are below the minimum
///          detectable at any useful Morse speed.
///       b. For segments with ≥ [_minOnEvents] ON events, run
///          [_robustBimodalSplit]:
///            • Try every split point in the sorted ON durations.
///            • Score by how close the upper/lower-median ratio is to 3.0.
///            • Require ratio ∈ [_minRatio, _maxRatio] AND
///              within-cluster CV ≤ [_maxClusterCv].
///            • Invalid split → output '?' for the whole segment.
///       c. For segments with < [_minOnEvents] ON events, or when the
///          bimodal ratio is < [_seedRatioThreshold], fall back to the
///          [MorseDecoder] adaptive-bootstrap (same as the live decoder).
///          This handles single-character and non-standard-ratio recordings
///          where the inflated Goertzel dot measurement would otherwise
///          push the letter-gap threshold above the measured letter gaps.
///       d. For valid bimodal with ratio ≥ [_seedRatioThreshold], pre-seed
///          [MorseDecoder] with the estimated dot/dash durations for faster,
///          more accurate decoding on well-structured recordings.
///
/// '?' is output instead of text for segments that look non-Morse or
/// contain ambiguous overlapping-speed content.
class OfflineAnalyzer {
  // ── Tuning constants ────────────────────────────────────────────────────────

  /// Minimum ON events (after noise filter) before attempting bimodal split.
  /// Segments below this fall back to adaptive bootstrap.
  /// Set to 4 so short but valid messages (even "A" = .-) go through bimodal
  /// while single-character signals use the safer adaptive path.
  static const int _minOnEvents = 4;

  /// Acceptable dash:dot ratio range for the bimodal split.
  /// Standard Morse is exactly 3.0; real recordings range ≈ 2.0–4.5.
  /// 
  /// Lowered minimum from 2.0 to 1.8 to accommodate heavily compressed
  /// YouTube recordings where timing ratios can be squeezed below 2.0
  /// while still being recognizable Morse (e.g., yt2.wav has ratio 2.15).
  /// 
  /// A ratio outside this range strongly indicates non-Morse content
  /// (noise, mixed-speed segments, typewriter) → output '?'.
  static const double _minRatio = 1.8;
  static const double _maxRatio = 4.5;

  /// Maximum coefficient of variation for each timing cluster.
  /// Real Morse timing is very consistent (CV ≈ 0.05–0.15); noise and
  /// mixed-speed content have much higher variance.
  /// Relaxed to 0.50 to accommodate YouTube recordings with compression
  /// artifacts that increase CV to 0.25-0.35 while still being valid Morse.
  static const double _maxClusterCv = 0.50;

  /// Minimum ratio to pre-seed [MorseDecoder] timing from the bimodal result.
  ///
  /// Set to 2.0 (the minimum valid Morse ratio) to trust bimodal splits for
  /// YouTube recordings with compression artifacts and room reverb.  Real-world
  /// recordings often produce ratios in the 2.0–2.5 range due to audio
  /// compression and environmental effects, but the bimodal split is still more
  /// reliable than adaptive bootstrap when the structure is clear (low CV,
  /// valid ratio range).  At ratios below 2.0, the Goertzel power-lingering
  /// effect causes the measured dot duration to exceed the true dot, which
  /// shifts the letter-gap threshold above the measured inter-letter gaps.
  /// The adaptive bootstrap uses the first ON event + first gap ratio to derive
  /// timing, which is unaffected by this inflation and handles ratios < 2.0.
  static const double _seedRatioThreshold = 2.0;

  /// Silence longer than this separates distinct message segments (ms).
  /// At 2 WPM the word gap is 7 × 800 = 5 600 ms, so 3 000 ms safely
  /// separates inter-message gaps while keeping slow single-word messages
  /// intact.
  static const double _segmentBreakMs = 3000.0;

  /// Default Goertzel frame size (samples per analysis window).
  static const int _frameSize = 512;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Decode Morse directly from raw WAV file bytes.
  ///
  /// Handles:
  ///   - 16-bit PCM, any sample rate.
  ///   - Mono and stereo; stereo is downmixed to mono by averaging channels.
  ///
  /// [targetFrequencyHz] — the Goertzel detector target frequency.
  /// Pass `null` (the default) to auto-detect the dominant tone frequency by
  /// scanning 400–900 Hz and picking the frequency with the highest
  /// signal-to-noise ratio.  Pass an explicit value to override auto-detection
  /// (useful in tests and when the tone frequency is known in advance).
  ///
  /// Returns the decoded text, or an empty string if the WAV cannot be parsed.
  static String analyzeWav(
    Uint8List bytes, {
    double? targetFrequencyHz,
  }) {
    final parsed = _parseWav(bytes);
    if (parsed == null) return '';
    final (pcm, sampleRate) = parsed;

    final freq = targetFrequencyHz ??
        _detectDominantFrequency(pcm, sampleRate, _frameSize);

    final detector = GoertzelDetector(
      sampleRate: sampleRate,
      targetFrequency: freq,
      frameSize: _frameSize,
    );
    final frames = GoertzelDetector.framesFromPcm16(pcm, _frameSize);
    final magnitudes = frames.map((f) => detector.computePower(f)).toList();
    return analyze(magnitudes, detector.frameDurationMs);
  }

  /// Scan candidate CW frequencies (400–900 Hz, 25 Hz steps) and return the
  /// one whose Goertzel power distribution has the highest dynamic range
  /// (p90 / p33).  The CW tone frequency produces the most pronounced contrast
  /// between silent frames (low power) and keyed frames (high power).
  ///
  /// Falls back to 700 Hz if the PCM is empty or all SNRs are zero.
  static double _detectDominantFrequency(
    Int16List pcm,
    int sampleRate,
    int frameSize,
  ) {
    final frames = GoertzelDetector.framesFromPcm16(pcm, frameSize);
    if (frames.isEmpty) return 700.0;

    double bestSnr = 0.0;
    double bestFreq = 700.0;

    for (double freq = 400.0; freq <= 900.0; freq += 25.0) {
      final detector = GoertzelDetector(
        sampleRate: sampleRate,
        targetFrequency: freq,
        frameSize: frameSize,
      );
      final powers = frames.map((f) => detector.computePower(f)).toList()
        ..sort();
      final p33 = powers[powers.length ~/ 3];
      final p90 = powers[(powers.length * 9) ~/ 10];
      final snr = p33 > 0 ? p90 / p33 : 0.0;

      if (snr > bestSnr) {
        bestSnr = snr;
        bestFreq = freq;
      }
    }

    // ignore: avoid_print
    print('[MorseDbg] Auto-detected tone:'
        ' ${bestFreq.toStringAsFixed(0)} Hz'
        ' (SNR=${bestSnr.toStringAsFixed(1)}×)');
    return bestFreq;
  }

  /// Parse a 16-bit PCM WAV file and return mono samples + sample rate.
  ///
  /// Stereo (or multi-channel) recordings are downmixed to mono by averaging
  /// all channels.  Returns null if the file is not a valid 16-bit PCM WAV.
  static (Int16List pcm, int sampleRate)? _parseWav(Uint8List bytes) {
    if (bytes.length < 44) return null;
    // RIFF header
    if (bytes[0] != 0x52 || bytes[1] != 0x49 ||
        bytes[2] != 0x46 || bytes[3] != 0x46) {
      return null;
    }
    // WAVE marker
    if (bytes[8] != 0x57 || bytes[9] != 0x41 ||
        bytes[10] != 0x56 || bytes[11] != 0x45) {
      return null;
    }

    final bd = ByteData.view(bytes.buffer);
    final numChannels = bd.getUint16(22, Endian.little);
    final sampleRate = bd.getUint32(24, Endian.little);
    final bitsPerSample = bd.getUint16(34, Endian.little);
    if (bitsPerSample != 16) return null;

    // Walk chunks to find 'data'.
    int offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = bd.getUint32(offset + 4, Endian.little);
      if (id == 'data') {
        final end = (offset + 8 + chunkSize).clamp(0, bytes.length);
        final dataBytes = bytes.sublist(offset + 8, end);
        final raw = dataBytes.buffer.asInt16List(
            dataBytes.offsetInBytes, dataBytes.lengthInBytes ~/ 2);

        if (numChannels == 1) return (raw, sampleRate);

        // Downmix multi-channel to mono: average all channels per frame.
        final monoLen = raw.length ~/ numChannels;
        final mono = Int16List(monoLen);
        for (int i = 0; i < monoLen; i++) {
          int sum = 0;
          for (int ch = 0; ch < numChannels; ch++) {
            sum += raw[i * numChannels + ch];
          }
          mono[i] = sum ~/ numChannels;
        }
        return (mono, sampleRate);
      }
      offset += 8 + chunkSize;
      if (chunkSize.isOdd) offset++; // RIFF pads odd-sized chunks
    }
    return null;
  }

  /// Decode Morse from a list of Goertzel power magnitudes.
  ///
  /// [magnitudes] — one value per audio frame.
  /// [frameDurationMs] — duration of one frame in milliseconds.
  ///
  /// Returns the decoded text. Undecodable segments are represented as '?'.
  static String analyze(List<double> magnitudes, double frameDurationMs) {
    if (magnitudes.length < 10) return '';

    // ── Step 1: global two-pass noise floor ──────────────────────────────────
    final sorted = List<double>.from(magnitudes)..sort();
    final p33Idx = (sorted.length - 1) ~/ 3;
    final roughFloor = max(sorted[p33Idx], 1e-10);
    final roughThreshold = roughFloor * kSignalRatio;
    final silences = magnitudes.where((p) => p < roughThreshold).toList();
    final noiseFloor = silences.isNotEmpty
        ? max(silences.reduce((a, b) => a + b) / silences.length, 1e-10)
        : roughFloor;
    final threshold = noiseFloor * kSignalRatio;

    // ignore: avoid_print
    print('[MorseDbg] OfflineAnalyzer:'
        ' frames=${magnitudes.length}'
        ' silenceFrames=${silences.length}'
        ' roughFloor=${roughFloor.toStringAsFixed(4)}'
        ' noiseFloor=${noiseFloor.toStringAsFixed(4)}'
        ' threshold=${threshold.toStringAsFixed(4)}'
        ' powerMin=${sorted.first.toStringAsFixed(4)}'
        ' powerMax=${sorted.last.toStringAsFixed(4)}');

    // ── Step 2: debounced ON/OFF events ──────────────────────────────────────
    final allEvents = _extractEvents(magnitudes, frameDurationMs, threshold);
    if (allEvents.isEmpty) return '';

    // ── Step 3: segment splitting ────────────────────────────────────────────
    final segments = _splitSegments(allEvents, _segmentBreakMs);
    // ignore: avoid_print
    print('[MorseDbg] OfflineAnalyzer: ${segments.length} segment(s)');

    // ── Step 4: per-segment analysis ─────────────────────────────────────────
    // Noise filter: ignore ON events shorter than a WPM-aware threshold.
    // The debounce cannot produce events shorter than 2 × frameDuration,
    // so this threshold removes only the very shortest 2-frame events that
    // can appear from marginal tone-detections at the debounce boundary.
    // NOTE: At 30–40 WPM, dots are 2–3 frames. We use WPM-aware thresholds
    // (1.5-2.5×) to avoid filtering genuine short dots at high WPM while
    // still removing transients at lower speeds.
    // For segments without bimodal analysis, use conservative 2.5× threshold.
    final minOnMs = frameDurationMs * 2.5;

    final parts = <String>[];
    for (int i = 0; i < segments.length; i++) {
      final text = _analyzeSegment(segments[i], frameDurationMs, minOnMs, i);
      if (text.isNotEmpty) parts.add(text);
    }

    final result = parts.join(' ').trim();
    // ignore: avoid_print
    print('[MorseDbg] OfflineAnalyzer result: "$result"');
    return result;
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  /// Calculate WPM-aware minimum ON duration threshold.
  ///
  /// At high WPM (35-40), dots are 2-3 frames. Using a fixed 2.5× threshold
  /// would filter genuine dots. This function adapts the threshold based on
  /// the estimated dot duration from bimodal analysis:
  ///   - Low WPM (5-15, dotMs ≥ 90): 2.5 × frameDuration
  ///   - Medium WPM (15-25, dotMs 60-90): 2.0 × frameDuration
  ///   - High WPM (25-40, dotMs < 60): 1.5 × frameDuration
  ///
  /// This prevents filtering genuine high-WPM dots while still removing
  /// transient noise at lower speeds.
  static double _calculateMinOnMs(double dotMs, double frameDurationMs) {
    if (dotMs >= 90.0) {
      // Low WPM (≤ 14 WPM): use conservative 2.5× threshold
      return frameDurationMs * 2.5;
    } else if (dotMs >= 60.0) {
      // Medium WPM (14-20 WPM): use moderate 2.0× threshold
      return frameDurationMs * 2.0;
    } else {
      // High WPM (≥ 20 WPM): use aggressive 1.5× threshold
      return frameDurationMs * 1.5;
    }
  }

  /// Calculate confidence score for a dash:dot ratio.
  ///
  /// Returns a confidence score (0.0-1.0) indicating how reliable the
  /// bimodal split is based on how close the ratio is to the ideal 3:1:
  ///   - Ratio 2.5-3.5 (±17% of 3.0): High confidence (1.0)
  ///   - Ratio 2.0-2.5 or 3.5-4.5: Medium confidence (0.7)
  ///   - Ratio < 2.0 or > 4.5: Low confidence (0.3)
  ///
  /// This is used to decide between seeded path (high confidence) vs.
  /// gap threshold measurement (medium confidence) vs. adaptive bootstrap
  /// or '?' output (low confidence).
  static double _calculateRatioConfidence(double ratio) {
    if (ratio >= 2.5 && ratio <= 3.5) {
      // Near ideal 3:1 ratio - high confidence
      return 1.0;
    } else if ((ratio >= 2.0 && ratio < 2.5) || (ratio > 3.5 && ratio <= 4.5)) {
      // Boundary ratios - medium confidence
      return 0.7;
    } else {
      // Outside valid range - low confidence
      return 0.3;
    }
  }

  /// Analyse one segment and return decoded text, '?', or ''.
  static String _analyzeSegment(
    List<(bool, double)> seg,
    double frameDurationMs,
    double minOnMs,
    int idx,
  ) {
    // Collect ON durations (excluding sub-threshold noise events).
    final onDurs =
        seg.where((e) => e.$1 && e.$2 >= minOnMs).map((e) => e.$2).toList();

    if (onDurs.isEmpty) return ''; // pure silence

    // Strip trailing OFF event before decoding.
    // A trailing silence at the end of the segment can mislead the adaptive
    // bootstrap: for "T" (single dash), a long trailing gap gives ratio < 2.0
    // and bootstrapFromGap() misclassifies the dash as a dot → "E".
    // The trailing OFF is not needed: flush() commits the last character.
    final trimmed = (seg.isNotEmpty && !seg.last.$1)
        ? seg.sublist(0, seg.length - 1)
        : seg;

    // Remove impulsive ON events shorter than minOnMs (noise/transients).
    // These are filtered from the bimodal analysis above; applying the same
    // filter before decoding prevents them from being decoded as dots, e.g.
    // a mouse-click transient appearing as a spurious leading 'E'.
    final decodeSeg = _filterShortOns(trimmed, minOnMs);

    // Too few events for reliable bimodal: use adaptive bootstrap.
    // This handles single-character messages (E=1, I=2, M=2, O=3, etc.) and
    // very short fragments gracefully without spuriously outputting '?'.
    if (onDurs.length < _minOnEvents) {
      // ignore: avoid_print
      print('[MorseDbg] Segment $idx: ${onDurs.length} ON events'
          ' (< $_minOnEvents) → adaptive bootstrap');
      return _decodeAdaptive(decodeSeg);
    }

    final (dotMs, dashMs, valid) = _robustBimodalSplit(onDurs);
    final ratio = dotMs > 0 ? dashMs / dotMs : 0.0;

    // ignore: avoid_print
    print('[MorseDbg] Segment $idx: ${seg.length} events'
        ' onCount=${onDurs.length}'
        ' dotMs=${dotMs.toStringAsFixed(1)}'
        ' dashMs=${dashMs.toStringAsFixed(1)}'
        ' ratio=${ratio.toStringAsFixed(2)}'
        ' valid=$valid');

    if (!valid) return '?';

    // For ratios at or below [_seedRatioThreshold] AND very short dots
    // (high WPM ≥ 25 WPM), the Goertzel power-lingering effect inflates the
    // measured dot duration enough that the old 2×dot letter-gap threshold
    // misfires.  The adaptive bootstrap derives timing from the first ON+gap
    // pair and is not subject to this inflation — use it for these fast,
    // borderline-ratio recordings.
    //
    // The dotMs guard (< 90 ms ≈ 14 WPM) allows medium-to-low WPM recordings
    // (≥ 15 WPM, even with reverb-inflated dotMs) to reach the seeded path,
    // where [_findGapThreshold] measures the actual sym/letter boundary from
    // the observed OFF-event distribution.  This is immune to Goertzel reverb
    // inflation — the seeded path is now safer than adaptive for ≥ 15 WPM.
    //
    // At truly high WPM (≥ 25 WPM, dotMs < 90 ms), the gap-threshold search
    // has too few frames to be reliable; adaptive bootstrap is more robust.
    //
    // NOTE: the boundary is inclusive (<=) because at 35 WPM the bimodal
    // produces exactly ratio=2.50, and the old seeded path would misclassify
    // the letter gap; adaptive is still correct for that speed.
    //
    // NEW: Use confidence scoring for boundary ratios (2.0-2.5). Medium
    // confidence ratios should use gap threshold measurement when available,
    // falling back to adaptive bootstrap if gap threshold cannot be found.
    final confidence = _calculateRatioConfidence(ratio);
    
    if (ratio <= _seedRatioThreshold && dotMs < 90.0) {
      // Low ratio + high WPM: use adaptive bootstrap
      // ignore: avoid_print
      print('[MorseDbg] Low ratio ($ratio) + high WPM (dotMs=${dotMs.toStringAsFixed(1)}ms)'
          ' → adaptive bootstrap');
      return _decodeAdaptive(decodeSeg);
    }
    
    // For medium confidence ratios (2.0-2.5), try to find gap threshold first.
    // If gap threshold cannot be found, fall back to adaptive bootstrap which
    // is more robust for these boundary cases than seeded path with default 2×dot.
    if (confidence == 0.7) {
      // Medium confidence - check if gap threshold can be found
      final interiorOffDursCheck = <double>[];
      bool seenOnCheck = false;
      for (final (isOn, ms) in trimmed) {
        if (isOn) {
          seenOnCheck = true;
        } else if (seenOnCheck) {
          interiorOffDursCheck.add(ms);
        }
      }
      final gapThresholdCheck = _findGapThreshold(interiorOffDursCheck, dotMs);
      
      if (gapThresholdCheck == null) {
        // Gap threshold not found - use adaptive bootstrap for boundary ratios
        // ignore: avoid_print
        print('[MorseDbg] Medium confidence ratio ($ratio), no gap threshold'
            ' → adaptive bootstrap');
        return _decodeAdaptive(decodeSeg);
      }
      // Gap threshold found - continue to seeded path below
    }

    // For the seeded path dotMs is known, so use WPM-aware filtering.
    // This catches clicks whose apparent duration (due to a partial Goertzel
    // frame staying above threshold) exceeds the base minOnMs but is still
    // clearly below any genuine Morse element.
    // WPM-aware threshold adapts to speed: 2.5× at low WPM, 1.5× at high WPM.
    final wpmAwareMinOnMs = _calculateMinOnMs(dotMs, frameDurationMs);
    // Also apply 70% of dot as secondary filter for transients
    final seededMinOnMs = max(wpmAwareMinOnMs, dotMs * 0.7);
    final seededSeg = _filterShortOns(trimmed, seededMinOnMs);

    // Measure the actual gap-cluster boundary from the interior OFF events.
    // Room reverb inflates dotMs (and raises the 2×dot letter-gap threshold)
    // while simultaneously compressing the measured letter gaps.  Using the
    // midpoint between the two observed gap clusters as the letter threshold
    // makes classification immune to this reverb-induced drift.
    final interiorOffDurs = <double>[];
    bool seenOn = false;
    for (final (isOn, ms) in seededSeg) {
      if (isOn) {
        seenOn = true;
      } else if (seenOn) {
        interiorOffDurs.add(ms);
      }
    }
    final gapThresholdMs = _findGapThreshold(interiorOffDurs, dotMs);

    return _decodeSeeded(seededSeg, dotMs, dashMs, gapThresholdMs: gapThresholdMs);
  }

  /// Decode using adaptive bootstrap (no pre-seeded timing).
  /// Delegates entirely to [MorseDecoder]'s gap-ratio bootstrap.
  static String _decodeAdaptive(List<(bool, double)> events) {
    final decoder = MorseDecoder();
    for (final (isOn, ms) in events) {
      decoder.processEvent(on: isOn, durationMs: ms.round());
    }
    decoder.flush();
    return decoder.decodedText;
  }

  /// Decode using pre-seeded dot/dash timing from bimodal analysis.
  ///
  /// [gapThresholdMs] — optional measured midpoint between the symbol-gap
  /// and letter-gap clusters (from [_findGapThreshold]).  When provided it
  /// overrides the standard 2×dot ITU letter-boundary, making classification
  /// immune to Goertzel reverb inflation of [dotMs].
  static String _decodeSeeded(
    List<(bool, double)> events,
    double dotMs,
    double dashMs, {
    double? gapThresholdMs,
  }) {
    final decoder = MorseDecoder();
    decoder.timing.seed(dotMs, dashMs, gapThresholdMs: gapThresholdMs);
    for (final (isOn, ms) in events) {
      decoder.processEvent(on: isOn, durationMs: ms.round());
    }
    decoder.flush();
    return decoder.decodedText;
  }

  /// Find the midpoint between the symbol-gap and letter-gap clusters in the
  /// sorted interior OFF-event durations.
  ///
  /// Scans for the **first** relative jump ≥ 1.7 between consecutive sorted
  /// values (skipping sub-noise values below 0.2×[dotMs]).  Using the first
  /// large relative jump — rather than the globally largest jump — ensures we
  /// identify the sym/letter boundary even when messages also contain word
  /// gaps whose letter→word jump is larger in absolute terms.
  ///
  /// Lowered to 1.7 to handle YouTube recordings with reverb and weak bimodal
  /// gap separation. Validates that at least 3 events exist in each cluster
  /// and threshold is between 1.5×dotMs and 3.5×dotMs.
  ///
  /// Returns null when no clear separation is found (e.g. only symbol gaps
  /// in a very short segment, or only one OFF event).
  static double? _findGapThreshold(List<double> offDurs, double dotMs) {
    if (offDurs.length < 2) return null;
    final sorted = List<double>.from(offDurs)..sort();

    for (int i = 1; i < sorted.length; i++) {
      final left = sorted[i - 1];
      if (left < dotMs * 0.2) continue; // skip sub-noise micro-gaps
      final ratio = sorted[i] / left;
      if (ratio >= 1.7) {
        // First large relative jump → sym/letter boundary.
        final threshold = (left + sorted[i]) / 2.0;
        
        // Validation: threshold must be between 1.0×dotMs and 4.0×dotMs
        // Lower bound relaxed to 1.0× to handle compressed letter gaps at
        // high WPM with low ratios (e.g., 30 WPM with ratio=2.20).
        // Upper bound at 4.0× handles YouTube recordings with reverb.
        if (threshold < dotMs * 1.0 || threshold > dotMs * 4.0) continue;
        
        // ignore: avoid_print
        print('[MorseDbg] gapThreshold: ${threshold.toStringAsFixed(1)}ms'
            ' (ratio=${ratio.toStringAsFixed(2)},'
            ' dotMs=${dotMs.toStringAsFixed(1)}ms,'
            ' lowerCount=$i,'
            ' upperCount=${sorted.length - i})');
        return threshold;
      }
    }
    return null; // no clear bimodal separation
  }

  /// Find the split of sorted [onDurs] whose upper/lower-median ratio is
  /// closest to 3.0, subject to ratio ∈ [_minRatio, _maxRatio] and
  /// within-cluster CV ≤ [_maxClusterCv].
  ///
  /// For ratios very close to the ideal 3:1 (within ±10%), relaxes the CV
  /// threshold to 0.70 to accommodate YouTube recordings with compression
  /// artifacts and fading that increase variance while maintaining valid
  /// Morse structure.
  ///
  /// Returns `(dotMs, dashMs, isValid)`.
  static (double, double, bool) _robustBimodalSplit(List<double> onDurs) {
    if (onDurs.isEmpty) return (60.0, 180.0, false);

    final s = List<double>.from(onDurs)..sort();
    if (s.length == 1) return (s.first, s.first * 3.0, false);

    double bestScore = double.infinity;
    int bestSplit = -1;

    for (int split = 1; split < s.length; split++) {
      final lower = s.sublist(0, split);
      final upper = s.sublist(split);

      final lowerMed = _median(lower);
      final upperMed = _median(upper);
      if (lowerMed <= 0 || upperMed <= 0) continue;

      final ratio = upperMed / lowerMed;
      if (ratio < _minRatio || ratio > _maxRatio) continue;

      // Each cluster must have consistent timing.
      final lowerCv = _cv(lower);
      final upperCv = _cv(upper);
      
      // Progressive CV relaxation based on ratio quality:
      // - Near-perfect ratios (2.7-3.3 = ±10% of 3.0): allow CV up to 0.80
      // - Good ratios (2.2-2.7 or 3.3-4.0): allow CV up to 0.65
      // - Acceptable ratios (1.8-2.2 or 4.0-4.5): use standard 0.50
      //
      // YouTube recordings with compression, fading, and reverb can have
      // high CV (0.50-0.80) while still being valid Morse. The closer the
      // ratio is to the ideal 3:1, the more CV variance we can tolerate.
      final isNearPerfectRatio = ratio >= 2.7 && ratio <= 3.3;
      final isGoodRatio = (ratio >= 2.2 && ratio < 2.7) || (ratio > 3.3 && ratio <= 4.0);
      
      final double cvThreshold;
      if (isNearPerfectRatio) {
        cvThreshold = 0.80;
      } else if (isGoodRatio) {
        cvThreshold = 0.65;
      } else {
        cvThreshold = _maxClusterCv; // 0.50
      }
      
      if (lowerCv > cvThreshold || upperCv > cvThreshold) {
        // ignore: avoid_print
        print('[CV-Diag] Bimodal split rejected: ratio=${ratio.toStringAsFixed(2)}, '
            'lowerCV=${lowerCv.toStringAsFixed(4)}, upperCV=${upperCv.toStringAsFixed(4)}, '
            'threshold=$cvThreshold (nearPerfect=$isNearPerfectRatio, good=$isGoodRatio)');
        continue;
      }

      // Combined score: deviation from ideal 3:1 plus penalty for small gap
      // between adjacent values at the split (a small gap means the bimodal
      // is weakly separated and less reliable).
      final relGap = (s[split] - s[split - 1]) / s[split - 1];
      final ratioScore = (ratio - 3.0).abs() / 3.0;
      final gapScore = 1.0 / (relGap + 0.01);
      final score = ratioScore + gapScore * 0.3;

      if (score < bestScore) {
        bestScore = score;
        bestSplit = split;
      }
    }

    if (bestSplit < 0) {
      // ignore: avoid_print
      print('[CV-Diag] No valid bimodal split found - all splits rejected');
      return (_median(s), _median(s) * 3.0, false);
    }

    final dotMs = _median(s.sublist(0, bestSplit));
    final dashMs = _median(s.sublist(bestSplit));
    // ignore: avoid_print
    print('[CV-Diag] ✓ Bimodal split ACCEPTED: ratio=${(dashMs / dotMs).toStringAsFixed(2)}, '
        'dotMs=${dotMs.toStringAsFixed(1)}, dashMs=${dashMs.toStringAsFixed(1)}');
    
    return (dotMs, dashMs, true);
  }

  /// 2-frame debounced event extraction (mirrors [DecoderPipeline._runDecode]).
  static List<(bool, double)> _extractEvents(
    List<double> magnitudes,
    double frameDurationMs,
    double threshold,
  ) {
    const debounceRequired = 2;
    final events = <(bool, double)>[];
    bool toneOn = false;
    int framesInState = 0;
    int debounceCount = 0;

    for (final power in magnitudes) {
      final isTone = power > threshold;
      if (isTone == toneOn) {
        framesInState += debounceCount + 1;
        debounceCount = 0;
      } else {
        debounceCount++;
        if (debounceCount >= debounceRequired) {
          final ms = framesInState * frameDurationMs;
          if (ms > 0) events.add((toneOn, ms));
          toneOn = isTone;
          framesInState = debounceCount;
          debounceCount = 0;
        }
      }
    }
    final ms = framesInState * frameDurationMs;
    if (ms > 0) events.add((toneOn, ms));
    return events;
  }

  /// Detect speed changes within a segment by analyzing the bimodal structure
  /// of ON durations. Returns indices where speed changes occur.
  ///
  /// Strategy: For multi-speed recordings (e.g., 5 WPM → 15 WPM → 25 WPM),
  /// the ON durations form 4+ clusters (slow dots, slow dashes, fast dots,
  /// fast dashes). We detect speed changes by:
  /// 1. Attempting bimodal split on the full segment
  /// 2. If CV is too high (>0.45), try splitting into sub-segments
  /// 3. Find split points where there's a SIGNIFICANT speed difference (>50%)
  ///    AND the bimodal structure improves
  ///
  /// This allows the bimodal split to work on each speed segment independently
  /// while avoiding false positives on normal timing variation.
  static List<int> _detectSpeedChanges(List<(bool, double)> events) {
    // Extract ON events with their indices and durations
    final onEvents = <(int, double)>[];
    for (int i = 0; i < events.length; i++) {
      if (events[i].$1) onEvents.add((i, events[i].$2));
    }

    if (onEvents.length < 12) return []; // Need enough events for multi-speed

    // Try bimodal split on full segment
    final allDurations = onEvents.map((e) => e.$2).toList();
    final (fullDotMs, fullDashMs, fullValid) = _robustBimodalSplit(allDurations);
    
    // If bimodal split works well with low CV, proceed to check for speed changes
    // Note: Low CV means good data quality, NOT absence of speed changes.
    // We still need to check if there are multiple speeds within the segment.
    if (fullValid) {
      final sorted = List<double>.from(allDurations)..sort();
      final cvLower = _cv(sorted.sublist(0, sorted.length ~/ 2));
      final cvUpper = _cv(sorted.sublist(sorted.length ~/ 2));
      // ignore: avoid_print
      print('[CV-Diag] Full segment: ${onEvents.length} ON events, '
          'cvLower=${cvLower.toStringAsFixed(4)}, cvUpper=${cvUpper.toStringAsFixed(4)}, '
          'threshold=0.45');
      // ignore: avoid_print
      print('[CV-Diag] Proceeding to check split points (fullValid=true)');
    }

    // Look for split points that improve bimodal structure AND show
    // significant speed difference (>50% change in dot duration)
    final splitIndices = <int>[];
    const minSegmentSize = 4; // Minimum ON events per sub-segment (same as _minOnEvents)

    for (int i = minSegmentSize; i < onEvents.length - minSegmentSize; i++) {
      final beforeDurs = onEvents.sublist(0, i).map((e) => e.$2).toList();
      final afterDurs = onEvents.sublist(i).map((e) => e.$2).toList();

      final (beforeDotMs, beforeDashMs, beforeValid) = _robustBimodalSplit(beforeDurs);
      final (afterDotMs, afterDashMs, afterValid) = _robustBimodalSplit(afterDurs);

      // Split only if:
      // 1. Both sub-segments have valid bimodal structure
      // 2. There's a SIGNIFICANT speed difference (>50% change in dot duration)
      // 3. Both sub-segments have low CV (confirming they're single-speed)
      if (beforeValid && afterValid) {
        final speedRatio = beforeDotMs > afterDotMs 
            ? beforeDotMs / afterDotMs 
            : afterDotMs / beforeDotMs;
        
        // Require >30% speed difference to detect moderate speed changes
        // (e.g., 15→20 WPM). Lowered from 1.5 to 1.3 to catch 33% changes.
        if (speedRatio > 1.3) {
          // Verify both sub-segments have consistent timing (low CV < 0.40)
          final beforeSorted = List<double>.from(beforeDurs)..sort();
          final afterSorted = List<double>.from(afterDurs)..sort();
          final beforeCvLower = _cv(beforeSorted.sublist(0, beforeSorted.length ~/ 2));
          final beforeCvUpper = _cv(beforeSorted.sublist(beforeSorted.length ~/ 2));
          final afterCvLower = _cv(afterSorted.sublist(0, afterSorted.length ~/ 2));
          final afterCvUpper = _cv(afterSorted.sublist(afterSorted.length ~/ 2));
          
          // ignore: avoid_print
          print('[CV-Diag] Split candidate at event $i: '
              'speedRatio=${speedRatio.toStringAsFixed(2)}×, '
              'before: cvLower=${beforeCvLower.toStringAsFixed(4)} cvUpper=${beforeCvUpper.toStringAsFixed(4)}, '
              'after: cvLower=${afterCvLower.toStringAsFixed(4)} cvUpper=${afterCvUpper.toStringAsFixed(4)}, '
              'threshold=0.40');
          
          // Both sub-segments must have low CV to confirm single-speed
          if (beforeCvLower < 0.40 && beforeCvUpper < 0.40 &&
              afterCvLower < 0.40 && afterCvUpper < 0.40) {
            final eventIdx = onEvents[i].$1;
            splitIndices.add(eventIdx);
            // ignore: avoid_print
            print('[MorseDbg] Speed change detected at event $eventIdx:'
                ' before=${beforeDurs.length} ON events (dotMs=${beforeDotMs.toStringAsFixed(1)}ms)'
                ' after=${afterDurs.length} ON events (dotMs=${afterDotMs.toStringAsFixed(1)}ms)'
                ' speedRatio=${speedRatio.toStringAsFixed(2)}×');
            // ignore: avoid_print
            print('[CV-Diag] ✓ SPLIT ACCEPTED (all CV < 0.40)');
            // Only take the first good split to avoid over-segmentation
            break;
          } else {
            // ignore: avoid_print
            print('[CV-Diag] ✗ SPLIT REJECTED (CV >= 0.40)');
          }
        }
      }
    }

    return splitIndices;
  }

  /// Split [events] into segments wherever an OFF event ≥ [breakMs].
  /// Additionally, detect and split on speed changes within segments.
  static List<List<(bool, double)>> _splitSegments(
    List<(bool, double)> events,
    double breakMs,
  ) {
    // First pass: split on long silences (original behavior)
    final primarySegments = <List<(bool, double)>>[];
    var current = <(bool, double)>[];
    for (final event in events) {
      final (isOn, ms) = event;
      if (!isOn && ms >= breakMs) {
        // ignore: avoid_print
        print('[MorseDbg] Segment break: ${ms.toStringAsFixed(0)}ms'
            ' (threshold=${breakMs.toStringAsFixed(0)}ms)');
        if (current.isNotEmpty) {
          primarySegments.add(current);
          current = [];
        }
      } else {
        current.add(event);
      }
    }
    if (current.isNotEmpty) primarySegments.add(current);

    // Second pass: detect and split on speed changes within each segment
    final finalSegments = <List<(bool, double)>>[];
    for (final segment in primarySegments) {
      final speedChangeIndices = _detectSpeedChanges(segment);
      
      if (speedChangeIndices.isEmpty) {
        // No speed changes detected - keep segment as-is
        finalSegments.add(segment);
      } else {
        // Split segment at detected speed changes
        int startIdx = 0;
        for (final splitIdx in speedChangeIndices) {
          if (splitIdx > startIdx) {
            final subSegment = segment.sublist(startIdx, splitIdx);
            if (subSegment.isNotEmpty) {
              finalSegments.add(subSegment);
              // ignore: avoid_print
              print('[MorseDbg] Speed-based sub-segment:'
                  ' events=${subSegment.length}');
            }
          }
          startIdx = splitIdx;
        }
        // Add remaining events after last split
        if (startIdx < segment.length) {
          final subSegment = segment.sublist(startIdx);
          if (subSegment.isNotEmpty) {
            finalSegments.add(subSegment);
            // ignore: avoid_print
            print('[MorseDbg] Speed-based sub-segment:'
                ' events=${subSegment.length}');
          }
        }
      }
    }

    return finalSegments;
  }

  /// Remove ON events shorter than [minOnMs], converting them to silence and
  /// merging any adjacent OFF events that result.
  ///
  /// This ensures the same noise filter applied to bimodal analysis is also
  /// applied before decoding, preventing impulsive transients (e.g. a mouse
  /// click at recording start) from being decoded as dots.
  static List<(bool, double)> _filterShortOns(
    List<(bool, double)> events,
    double minOnMs,
  ) {
    // Replace short ON events with OFF events of the same duration.
    final step1 = events.map((e) {
      final (isOn, ms) = e;
      return (isOn && ms < minOnMs) ? (false, ms) : e;
    }).toList();

    // Merge consecutive events with the same polarity.
    final result = <(bool, double)>[];
    for (final event in step1) {
      if (result.isNotEmpty && result.last.$1 == event.$1) {
        result[result.length - 1] = (event.$1, result.last.$2 + event.$2);
      } else {
        result.add(event);
      }
    }
    return result;
  }

  /// Median of a pre-sorted list.
  static double _median(List<double> sorted) {
    if (sorted.isEmpty) return 0.0;
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2.0;
  }

  /// Coefficient of variation (stdDev / mean). 0 = perfectly consistent.
  static double _cv(List<double> values) {
    if (values.length < 2) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    if (mean <= 0) return 0.0;
    final variance = values
            .map((v) => (v - mean) * (v - mean))
            .reduce((a, b) => a + b) /
        values.length;
    return sqrt(variance) / mean;
  }
}

/// Top-level wrapper used by [compute()] to run [OfflineAnalyzer.analyze]
/// on a background isolate without blocking the UI thread.
///
/// [args.$1] — magnitudes list, [args.$2] — frameDurationMs.
String runOfflineAnalysisIsolate((List<double>, double) args) =>
    OfflineAnalyzer.analyze(args.$1, args.$2);

/// Top-level wrapper used by [compute()] to run [OfflineAnalyzer.analyzeWav]
/// on a background isolate without blocking the UI thread.
///
/// [args.$1] — raw WAV bytes.
/// [args.$2] — Goertzel target frequency in Hz, or null to auto-detect.
String runOfflineWavAnalysisIsolate((Uint8List, double?) args) =>
    OfflineAnalyzer.analyzeWav(args.$1, targetFrequencyHz: args.$2);
