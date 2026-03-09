import 'dart:math';

import 'decoder_pipeline.dart';

/// Offline Morse decoder that analyzes a complete recording in one pass.
///
/// Unlike the live [DecoderPipeline], this operates on a pre-recorded list of
/// Goertzel magnitudes, computing an accurate noise floor from the full
/// distribution before decoding. This produces significantly better results
/// because:
///
/// - The noise floor is estimated from actual silent gaps *throughout* the
///   message, not just a fixed pre-signal window.
/// - The adaptive timing (WPM) is estimated from the observed pulse durations.
/// - Multiple passes or threshold sweeps are possible without re-recording.
class OfflineAnalyzer {
  /// Decode Morse from a list of Goertzel power magnitudes.
  ///
  /// [magnitudes] — precomputed Goertzel power values, one per audio frame.
  /// [frameDurationMs] — duration of each frame in milliseconds.
  ///
  /// Returns the decoded text, or an empty string if no Morse was detected.
  static String analyze(List<double> magnitudes, double frameDurationMs) {
    if (magnitudes.length < 10) return '';

    // ── Step 1: rough noise floor from the 33rd percentile ───────────────
    // Silent frames cluster at the low end of the power distribution; tone
    // frames at the high end. We need the rough separator to land inside the
    // silence distribution.
    //
    // Using p33 (instead of p50 / median) makes this robust for content-dense
    // messages where tone can exceed 50 % of total frames:
    //   • "0123456789" has ~48 % silence (52 % tone) → p50 lands in tone → fail.
    //   • Full alphabet has ~49 % silence (51 % tone) → p50 borderline → fails.
    //   • p33 requires only silence > 33 %, which is always satisfied for any
    //     standard Morse recording with the standard 110-frame lead-in:
    //     even "0123456789" (the densest practical message) has ~48 % silence.
    //   • Staying at p33 (not p25) preserves accuracy for normal recordings:
    //     lower percentiles produce a roughFloor further from the true noise
    //     mean, which can cause small accuracy regressions at high WPM / noisy
    //     conditions compared to p50.
    //
    // The second pass (mean of confirmed-silence frames) corrects for any
    // underestimate introduced by the lower percentile.
    final sorted = List<double>.from(magnitudes)..sort();
    final p33Idx = (sorted.length - 1) ~/ 3;
    final roughFloor = max(sorted[p33Idx], 1e-10);

    // ── Step 2: refine by averaging confirmed-silence frames ───────────────
    // Goertzel power follows a chi-squared(2) / exponential distribution for
    // white noise, so low-percentile values (p20, mean-of-bottom-third) can
    // underestimate the true mean by 4–5×, lowering the threshold into the
    // noise and causing false-positive detections.
    //
    // Instead: classify frames below roughFloor × kSignalRatio as silence and
    // compute their mean — this gives a stable estimate of the true noise mean
    // regardless of the noise distribution.
    final roughThreshold = roughFloor * kSignalRatio;
    final silencePowers =
        magnitudes.where((p) => p < roughThreshold).toList();
    final noiseFloor = silencePowers.isNotEmpty
        ? max(silencePowers.reduce((a, b) => a + b) / silencePowers.length,
            1e-10)
        : roughFloor;

    // ignore: avoid_print
    print('[MorseDbg] OfflineAnalyzer:'
        ' frames=${magnitudes.length}'
        ' silenceFrames=${silencePowers.length}'
        ' roughFloor=${roughFloor.toStringAsFixed(4)}'
        ' noiseFloor=${noiseFloor.toStringAsFixed(4)}'
        ' threshold=${(noiseFloor * kSignalRatio).toStringAsFixed(4)}'
        ' powerMin=${sorted.first.toStringAsFixed(4)}'
        ' powerMax=${sorted.last.toStringAsFixed(4)}');

    // ── Step 2: feed all frames through the pipeline synchronously ─────────
    // Create a pipeline seeded with the computed noise floor so we skip the
    // calibration phase and jump straight to decoding.
    final pipeline = DecoderPipeline(calibrationFrames: 0);
    pipeline.resetForDecode(CalibrationResult(
      noiseFloor: noiseFloor,
      cv: 0.0,
      quality: CalibrationQuality.good,
    ));

    for (final power in magnitudes) {
      pipeline.processPower(power);
    }
    pipeline.flush();

    // ignore: avoid_print
    print('[MorseDbg] OfflineAnalyzer result: "${pipeline.decodedText}"');
    return pipeline.decodedText;
  }
}

/// Top-level wrapper used by [compute()] to run [OfflineAnalyzer.analyze]
/// on a background isolate without blocking the UI thread.
///
/// [args.$1] — magnitudes list, [args.$2] — frameDurationMs.
String runOfflineAnalysisIsolate((List<double>, double) args) =>
    OfflineAnalyzer.analyze(args.$1, args.$2);
