import 'dart:math';
import 'dart:typed_data';

import 'package:morse_comms/core/morse/morse_table.dart';

/// Generates synthetic PCM-16 audio for a Morse code message.
///
/// Produces a pure sine wave at [frequencyHz] shaped by ITU Morse timing,
/// with optional white Gaussian noise at [snrDb]. The output includes:
///   - A calibration lead-in (110 frames of silence / noise)
///   - The message
///   - A short trailing silence to flush the final debounce
class SineMorseGenerator {
  static const int sampleRate = 44100;
  static const int frameSize = 512;
  static const double _amplitude = 16000.0; // ~49 % full-scale — leaves headroom for noise

  final int wpm;
  final double frequencyHz;
  final double? snrDb; // null → no noise
  final int seed;

  const SineMorseGenerator({
    required this.wpm,
    this.frequencyHz = 700.0,
    this.snrDb,
    this.seed = 42,
  });

  int get dotSamples => (sampleRate * 1200 / (wpm * 1000)).round();

  /// Builds an event list: (bool on, int samples) for every segment.
  List<(bool, int)> buildEvents(String message) {
    final events = <(bool, int)>[];

    // ── Lead-in silence: enough for 100-frame calibration + 10 guard frames ──
    events.add((false, 110 * frameSize));

    // ── Encode message ──────────────────────────────────────────────────────
    final words = message.toUpperCase().trim().split(RegExp(r'\s+'));

    for (int wi = 0; wi < words.length; wi++) {
      final word = words[wi];
      for (int ci = 0; ci < word.length; ci++) {
        final pattern = kMorseTable[word[ci]];
        if (pattern == null) continue; // skip unknowns

        for (int si = 0; si < pattern.length; si++) {
          final isDash = pattern[si] == '-';
          events.add((true, isDash ? dotSamples * 3 : dotSamples));
          if (si < pattern.length - 1) {
            events.add((false, dotSamples)); // inter-symbol gap
          }
        }

        if (ci < word.length - 1) {
          events.add((false, dotSamples * 3)); // inter-letter gap
        }
      }

      if (wi < words.length - 1) {
        events.add((false, dotSamples * 7)); // inter-word gap
      }
    }

    // ── Trailing silence: 20 frames — triggers final debounce + leaves buffer ──
    events.add((false, 20 * frameSize));

    return events;
  }

  /// Renders the event list to a PCM-16 Int16List.
  Int16List renderPcm(List<(bool, int)> events) {
    final totalSamples = events.fold(0, (s, e) => s + e.$2);
    final pcm = Int16List(totalSamples);
    final rng = Random(seed);

    // Noise sigma: sigma = A / sqrt(2 × 10^(SNR/10))
    final noiseSigma = snrDb != null
        ? _amplitude / sqrt(2.0 * pow(10.0, snrDb! / 10.0))
        : 0.0;

    int offset = 0;
    for (final (on, samples) in events) {
      for (int i = 0; i < samples; i++) {
        double s = on
            ? _amplitude * sin(2 * pi * frequencyHz * (offset + i) / sampleRate)
            : 0.0;

        if (noiseSigma > 0) {
          // Box-Muller transform → Gaussian noise
          final u1 = max(rng.nextDouble(), 1e-10);
          final u2 = rng.nextDouble();
          s += noiseSigma * sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
        }

        pcm[offset + i] = s.round().clamp(-32768, 32767);
      }
      offset += samples;
    }

    return pcm;
  }

  /// Convenience: generate PCM for [message] in one call.
  Int16List generate(String message) => renderPcm(buildEvents(message));
}
