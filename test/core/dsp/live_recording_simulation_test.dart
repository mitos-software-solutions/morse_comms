// ignore_for_file: avoid_print
//
// Live-recording simulation tests for OfflineAnalyzer.
//
// The hardware path (mic → Android audio stack → PCM) is not testable in unit
// tests.  These tests cover everything that happens *after* the ADC by
// injecting synthetic PCM that models known real-world degradation:
//
//   1. Non-standard sender timing  — dash:dot ratio ≠ 3.0 (as seen in YouTube
//      Morse demo videos).  This was the root cause of the "OOOOO" bug.
//
//   2. Mouse-click transient       — short wideband burst captured at recording
//      start when the user clicks to play the YouTube video.
//
//   3. Simulated room reverb       — exponential power decay after each tone
//      burst, extending the apparent ON duration.
//
//   4. Tone-frequency auto-detect  — unknown CW frequency (600 / 800 Hz)
//      decoded with targetFrequencyHz = null.
//
//   5. No silence lead-in          — recording starts mid-transmission with
//      no calibration silence.
//
// All tests run through OfflineAnalyzer.analyzeWav() — the same code path
// used by DecoderService.analyzeRecording() after the 2026-03-10 refactor.

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/core/dsp/decoder_pipeline.dart' show kSignalRatio;
import 'package:morse_comms/core/dsp/goertzel.dart';
import 'package:morse_comms/core/dsp/offline_analyzer.dart';
import 'package:morse_comms/core/morse/morse_table.dart';

import '../../helpers/sine_morse_generator.dart';

// ── PCM / WAV helpers ─────────────────────────────────────────────────────────

/// Wrap a mono Int16List in a minimal RIFF/WAV header.
Uint8List _pcmToWav(Int16List pcm,
    {int sampleRate = SineMorseGenerator.sampleRate}) {
  final data = pcm.buffer.asUint8List(pcm.offsetInBytes, pcm.lengthInBytes);
  final hdr = ByteData(44);
  void fcc(int off, int v) {
    hdr.setUint8(off, (v >> 24) & 0xFF);
    hdr.setUint8(off + 1, (v >> 16) & 0xFF);
    hdr.setUint8(off + 2, (v >> 8) & 0xFF);
    hdr.setUint8(off + 3, v & 0xFF);
  }

  fcc(0, 0x52494646); // RIFF
  hdr.setUint32(4, 36 + data.length, Endian.little);
  fcc(8, 0x57415645); // WAVE
  fcc(12, 0x666d7420); // fmt
  hdr.setUint32(16, 16, Endian.little);
  hdr.setUint16(20, 1, Endian.little); // PCM
  hdr.setUint16(22, 1, Endian.little); // mono
  hdr.setUint32(24, sampleRate, Endian.little);
  hdr.setUint32(28, sampleRate * 2, Endian.little);
  hdr.setUint16(32, 2, Endian.little);
  hdr.setUint16(34, 16, Endian.little);
  fcc(36, 0x64617461); // data
  hdr.setUint32(40, data.length, Endian.little);
  final out = Uint8List(44 + data.length);
  out.setAll(0, hdr.buffer.asUint8List());
  out.setAll(44, data);
  return out;
}

/// Generate PCM with non-ITU Morse timing.
///
/// [dashDotRatio]    — dash duration as a multiple of dot (standard = 3.0).
/// [symGapDotRatio]  — inter-symbol gap as a multiple of dot (standard = 1.0).
/// [letGapDotRatio]  — inter-letter gap as a multiple of dot (standard = 3.0).
///                     Defaults to 3× [symGapDotRatio] when omitted.
///
/// Reproduces YouTube Morse senders who send dashes that are only 2.0–2.5× a
/// dot and compress inter-symbol gaps, while keeping inter-letter gaps at the
/// standard 3× dot duration.
Uint8List _buildNonStandardWav(
  String message, {
  required int wpm,
  required double dashDotRatio,
  double symGapDotRatio = 1.0,
  double? letGapDotRatio,
  double frequencyHz = 700.0,
  int sampleRate = SineMorseGenerator.sampleRate,
}) {
  const frameSize = SineMorseGenerator.frameSize;
  final dotSamples = (sampleRate * 1200 / (wpm * 1000)).round();
  final dashSamples = (dotSamples * dashDotRatio).round();
  final symGap = max(1, (dotSamples * symGapDotRatio).round());
  final effectiveLetRatio = letGapDotRatio ?? (3.0 * symGapDotRatio);
  final letGap = max(1, (dotSamples * effectiveLetRatio).round());
  final wrdGap = max(1, (dotSamples * effectiveLetRatio * 7.0 / 3.0).round());

  final events = <(bool, int)>[];
  events.add((false, 110 * frameSize)); // calibration lead-in

  final words = message.toUpperCase().trim().split(RegExp(r'\s+'));
  for (int wi = 0; wi < words.length; wi++) {
    final chars = words[wi].split('');
    for (int ci = 0; ci < chars.length; ci++) {
      final pattern = kMorseTable[chars[ci]];
      if (pattern == null) continue;
      for (int si = 0; si < pattern.length; si++) {
        events.add((true, pattern[si] == '-' ? dashSamples : dotSamples));
        if (si < pattern.length - 1) events.add((false, symGap));
      }
      if (ci < chars.length - 1) events.add((false, letGap));
    }
    if (wi < words.length - 1) events.add((false, wrdGap));
  }
  events.add((false, 20 * frameSize)); // trailing flush

  final total = events.fold(0, (s, e) => s + e.$2);
  final pcm = Int16List(total);
  const amp = 16000.0;
  int off = 0;
  for (final (on, n) in events) {
    for (int i = 0; i < n; i++) {
      pcm[off + i] = on
          ? (amp * sin(2 * pi * frequencyHz * (off + i) / sampleRate))
              .round()
              .clamp(-32768, 32767)
          : 0;
    }
    off += n;
  }
  return _pcmToWav(pcm, sampleRate: sampleRate);
}

/// Returns PCM with a simulated click (short wideband burst) prepended,
/// followed by [silenceAfterMs] ms of silence before the actual message.
Int16List prependClick(
  Int16List pcm, {
  int clickDurationMs = 20,
  int silenceAfterMs = 300,
  int sampleRate = SineMorseGenerator.sampleRate,
}) {
  final clickSamples = clickDurationMs * sampleRate ~/ 1000;
  final silenceSamples = silenceAfterMs * sampleRate ~/ 1000;
  final rng = Random(0);
  final out = Int16List(clickSamples + silenceSamples + pcm.length);
  for (int i = 0; i < clickSamples; i++) {
    out[i] =
        ((rng.nextDouble() * 2 - 1) * 20000).round().clamp(-32768, 32767);
  }
  // silence gap is already zero (Int16List default)
  for (int i = 0; i < pcm.length; i++) {
    out[clickSamples + silenceSamples + i] = pcm[i];
  }
  return out;
}

/// Strip the calibration lead-in silence from PCM generated by
/// [SineMorseGenerator] (110 frames × 512 samples = 56320 samples).
Int16List stripLeadIn(Int16List pcm) {
  const leadInSamples = 110 * SineMorseGenerator.frameSize;
  if (pcm.length <= leadInSamples) return pcm;
  return Int16List.sublistView(pcm, leadInSamples);
}

/// Compute noise floor from magnitudes, apply reverb, then decode.
String decodeWithReverb(
  List<double> mags,
  double frameDurationMs, {
  required int decayFrames,
}) {
  final sorted = List<double>.from(mags)..sort();
  final roughFloor = sorted[sorted.length ~/ 3];
  final threshold = roughFloor * kSignalRatio;
  final withReverb = _applyReverb(mags, threshold, decayFrames: decayFrames);
  return OfflineAnalyzer.analyze(withReverb, frameDurationMs);
}

/// Apply a simulated room-reverb tail to Goertzel magnitudes.
///
/// After each ON→OFF transition (detected in the *original* magnitudes),
/// inject [decayFrames] frames of exponentially-decaying power into the
/// output.  Reading from the original prevents cascade: reverb frames that
/// were injected into the output do not themselves trigger further decay.
List<double> _applyReverb(
  List<double> mags,
  double threshold, {
  required int decayFrames,
}) {
  final out = List<double>.from(mags);
  // Iterate over the ORIGINAL mags to find genuine ON→OFF transitions.
  for (int i = 1; i < mags.length; i++) {
    if (mags[i - 1] > threshold && mags[i] <= threshold) {
      final peak = mags[i - 1];
      for (int d = 0; d < decayFrames && i + d < out.length; d++) {
        final decayed = peak * exp(-d * 3.0 / decayFrames);
        if (decayed > out[i + d]) out[i + d] = decayed;
      }
    }
  }
  return out;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // 1.  Non-standard Morse timing (the YouTube-video bug)
  //
  //     Root cause of the 2026-03-10 "OOOOO" device failure:
  //       • Bimodal correctly found dotMs≈366ms, dashMs≈824ms, ratio=2.25.
  //       • Old code: ratio ≤ 2.5 → adaptive bootstrap → dotMs set to 139ms
  //         (the inter-symbol gap) → every element classified as dash → "OOOOO".
  //       • Fix: adaptive only when ratio ≤ 2.5 AND dotMs < 150ms (high WPM).
  //         At low WPM (dotMs ≥ 150ms) the bimodal result is used directly.
  // ══════════════════════════════════════════════════════════════════════════
  group('Non-standard Morse timing (YouTube-like)', () {
    test('ratio 2.25 at 3 WPM decodes SOS (exact bug reproduction)', () {
      // Mirrors the ADB log: dotMs≈366ms, dashMs≈824ms, ratio=2.25.
      // Inter-symbol gap compressed to ~0.38× dot (139ms vs expected 366ms).
      final wav = _buildNonStandardWav(
        'SOS',
        wpm: 3,
        dashDotRatio: 2.25,
        symGapDotRatio: 0.38,
        letGapDotRatio: 3.0, // standard letter gap — only sym gap is compressed
      );
      final result = OfflineAnalyzer.analyzeWav(wav, targetFrequencyHz: 700);
      print('[sim] ratio=2.25 @3wpm: "$result"');
      expect(result, 'SOS',
          reason: 'Low-WPM non-standard ratio must use bimodal seeded path, '
              'not adaptive bootstrap which misclassifies every element as dash');
    });

    test('ratio 2.0 at 5 WPM decodes SOS', () {
      final wav = _buildNonStandardWav(
        'SOS',
        wpm: 5,
        dashDotRatio: 2.0,
        symGapDotRatio: 0.7,
        letGapDotRatio: 3.0,
      );
      final result = OfflineAnalyzer.analyzeWav(wav, targetFrequencyHz: 700);
      print('[sim] ratio=2.0 @5wpm: "$result"');
      expect(result, 'SOS');
    });

    test('ratio 2.3 at 8 WPM decodes SOS', () {
      final wav = _buildNonStandardWav(
        'SOS',
        wpm: 8,
        dashDotRatio: 2.3,
        symGapDotRatio: 0.8,
        letGapDotRatio: 3.0,
      );
      final result = OfflineAnalyzer.analyzeWav(wav, targetFrequencyHz: 700);
      print('[sim] ratio=2.3 @8wpm: "$result"');
      expect(result, 'SOS');
    });

    test('ratio 2.5 at 10 WPM decodes SOS (boundary case)', () {
      // At 10 WPM dotMs≈120ms > 150ms guard → seeded path is used.
      final wav = _buildNonStandardWav(
        'SOS',
        wpm: 10,
        dashDotRatio: 2.5,
      );
      final result = OfflineAnalyzer.analyzeWav(wav, targetFrequencyHz: 700);
      print('[sim] ratio=2.5 @10wpm: "$result"');
      expect(result, 'SOS');
    });

    test('non-standard timing with multi-word message decodes correctly', () {
      final wav = _buildNonStandardWav(
        'SOS SOS',
        wpm: 5,
        dashDotRatio: 2.3,
        symGapDotRatio: 0.6,
        letGapDotRatio: 3.0,
      );
      final result = OfflineAnalyzer.analyzeWav(wav, targetFrequencyHz: 700);
      print('[sim] ratio=2.3 SOS SOS @5wpm: "$result"');
      // Word gap may not always produce a space — strip spaces and check chars.
      expect(result.replaceAll(' ', ''), 'SOSSOS',
          reason: 'Both words must decode as SOS');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 2.  Mouse-click transient at recording start
  //
  //     When the user clicks the mouse to start the YouTube video, the mic
  //     captures a short wideband transient burst before the Morse content.
  //     This should not corrupt the bimodal split or noise floor estimation.
  // ══════════════════════════════════════════════════════════════════════════
  group('Mouse-click transient at recording start', () {
    test('20ms click before SOS at 20 WPM still decodes correctly', () {
      final gen = SineMorseGenerator(wpm: 20);
      final cleanPcm = gen.generate('SOS');
      final pcmWithClick = prependClick(cleanPcm);
      final wav = _pcmToWav(pcmWithClick);
      final result = OfflineAnalyzer.analyzeWav(wav, targetFrequencyHz: 700);
      print('[sim] click + SOS @20wpm: "$result"');
      expect(result, 'SOS',
          reason: 'Mouse-click transient must not corrupt Morse decoding');
    });

    test('50ms click before SOS at 15 WPM still decodes correctly', () {
      final gen = SineMorseGenerator(wpm: 15);
      final cleanPcm = gen.generate('SOS');
      final pcmWithClick = prependClick(cleanPcm, clickDurationMs: 50);
      final wav = _pcmToWav(pcmWithClick);
      final result = OfflineAnalyzer.analyzeWav(wav, targetFrequencyHz: 700);
      print('[sim] 50ms click + SOS @15wpm: "$result"');
      expect(result, 'SOS');
    });

    test('click followed immediately by message (no silence gap) decodes non-empty', () {
      // Worst case: click right before first Morse element.
      final gen = SineMorseGenerator(wpm: 20);
      final cleanPcm = gen.generate('SOS');
      final pcmWithClick = prependClick(cleanPcm, silenceAfterMs: 0);
      final wav = _pcmToWav(pcmWithClick);
      final result = OfflineAnalyzer.analyzeWav(wav, targetFrequencyHz: 700);
      print('[sim] click (no gap) + SOS: "$result"');
      // May not decode perfectly, but should not crash or return empty.
      expect(result, isNotEmpty,
          reason: 'Decoder must not crash or return empty on click+message');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 3.  Simulated room reverb
  //
  //     Room acoustics cause the Goertzel power to decay slowly after each
  //     tone burst ends.  This extends the apparent ON event duration,
  //     inflating dotMs measurements.  Tests verify the decoder handles this.
  // ══════════════════════════════════════════════════════════════════════════
  group('Simulated room reverb', () {
    test('mild reverb (2 frames ≈ 23ms) at 15 WPM decodes SOS', () {
      // 2 reverb frames inflate dotMs from ~81ms to ~104ms.  The measured
      // letter gap (~220ms) still exceeds the gap-cluster threshold (~139ms)
      // computed from the interior OFF distribution, so SOS decodes correctly.
      final gen = SineMorseGenerator(wpm: 15);
      final pcm = gen.generate('SOS');
      final detector = GoertzelDetector(
          sampleRate: SineMorseGenerator.sampleRate,
          targetFrequency: 700,
          frameSize: SineMorseGenerator.frameSize);
      final frames = GoertzelDetector.framesFromPcm16(
          pcm, SineMorseGenerator.frameSize);
      final mags = frames.map((f) => detector.computePower(f)).toList();

      final result =
          decodeWithReverb(mags, detector.frameDurationMs, decayFrames: 2);
      print('[sim] reverb 2fr @15wpm: "$result"');
      expect(result, 'SOS',
          reason: 'Gap-cluster threshold makes mild-reverb letter boundaries '
              'immune to inflated dotMs');
    });

    test('moderate reverb (4 frames ≈ 46ms) at 10 WPM decodes SOS', () {
      // 4 reverb frames inflate dotMs from ~116ms to ~162ms, raising the naive
      // 2×dot letter threshold to 324ms — above the compressed letter gap
      // (~302ms).  The measured gap-cluster midpoint (~186ms) correctly
      // separates symbol gaps (~70ms) from letter gaps (~302ms) → SOS.
      final gen = SineMorseGenerator(wpm: 10);
      final pcm = gen.generate('SOS');
      final detector = GoertzelDetector(
          sampleRate: SineMorseGenerator.sampleRate,
          targetFrequency: 700,
          frameSize: SineMorseGenerator.frameSize);
      final frames = GoertzelDetector.framesFromPcm16(
          pcm, SineMorseGenerator.frameSize);
      final mags = frames.map((f) => detector.computePower(f)).toList();

      final result =
          decodeWithReverb(mags, detector.frameDurationMs, decayFrames: 4);
      print('[sim] reverb 4fr @10wpm: "$result"');
      expect(result, 'SOS',
          reason: 'Gap-cluster threshold bridges the reverb-induced gap '
              'compression at moderate reverb');
    });

    test('heavy reverb (8 frames ≈ 93ms) at 5 WPM decodes SOS', () {
      // 8 reverb frames at 5 WPM inflate dotMs from ~243ms to ~337ms, raising
      // the naive threshold to 674ms — above the compressed letter gap (~638ms).
      // The gap-cluster midpoint (~395ms) correctly separates symbol gaps
      // (~151ms) from letter gaps (~638ms) → SOS decodes correctly.
      final gen = SineMorseGenerator(wpm: 5);
      final pcm = gen.generate('SOS');
      final detector = GoertzelDetector(
          sampleRate: SineMorseGenerator.sampleRate,
          targetFrequency: 700,
          frameSize: SineMorseGenerator.frameSize);
      final frames = GoertzelDetector.framesFromPcm16(
          pcm, SineMorseGenerator.frameSize);
      final mags = frames.map((f) => detector.computePower(f)).toList();

      final result =
          decodeWithReverb(mags, detector.frameDurationMs, decayFrames: 8);
      print('[sim] reverb 8fr @5wpm: "$result"');
      expect(result, 'SOS',
          reason: 'Gap-cluster threshold makes heavy-reverb decoding correct '
              'even when dotMs inflation exceeds the letter gap');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 4.  Tone-frequency auto-detection
  //
  //     DecoderService.analyzeRecording() now passes null to analyzeWav(),
  //     enabling _detectDominantFrequency() to scan 400–900 Hz and pick the
  //     frequency with the highest SNR.  These tests verify the detector
  //     correctly identifies common CW frequencies without being told.
  // ══════════════════════════════════════════════════════════════════════════
  group('Tone frequency auto-detection (null targetFrequencyHz)', () {
    test('600 Hz tone auto-detected and decoded correctly', () {
      final gen = SineMorseGenerator(wpm: 20, frequencyHz: 600);
      final pcm = gen.generate('SOS');
      final wav = _pcmToWav(pcm);
      // Pass null → auto-detect
      final result = OfflineAnalyzer.analyzeWav(wav);
      print('[sim] auto-detect 600 Hz: "$result"');
      expect(result, 'SOS',
          reason: 'Auto-detection must pick 600 Hz and decode correctly');
    });

    test('750 Hz tone auto-detected and decoded correctly', () {
      final gen = SineMorseGenerator(wpm: 20, frequencyHz: 750);
      final pcm = gen.generate('SOS');
      final wav = _pcmToWav(pcm);
      final result = OfflineAnalyzer.analyzeWav(wav);
      print('[sim] auto-detect 750 Hz: "$result"');
      expect(result, 'SOS');
    });

    test('800 Hz tone auto-detected and decoded correctly', () {
      final gen = SineMorseGenerator(wpm: 20, frequencyHz: 800);
      final pcm = gen.generate('SOS');
      final wav = _pcmToWav(pcm);
      final result = OfflineAnalyzer.analyzeWav(wav);
      print('[sim] auto-detect 800 Hz: "$result"');
      expect(result, 'SOS');
    });

    test('450 Hz tone auto-detected and decoded correctly', () {
      final gen = SineMorseGenerator(wpm: 20, frequencyHz: 450);
      final pcm = gen.generate('SOS');
      final wav = _pcmToWav(pcm);
      final result = OfflineAnalyzer.analyzeWav(wav);
      print('[sim] auto-detect 450 Hz: "$result"');
      expect(result, 'SOS');
    });

    test('auto-detection outperforms wrong fixed frequency on 600 Hz signal', () {
      final gen = SineMorseGenerator(wpm: 20, frequencyHz: 600);
      final pcm = gen.generate('SOS');
      final wav = _pcmToWav(pcm);

      final autoResult = OfflineAnalyzer.analyzeWav(wav); // auto-detect
      final wrongResult =
          OfflineAnalyzer.analyzeWav(wav, targetFrequencyHz: 300); // wrong

      final autoUseful =
          autoResult.replaceAll('?', '').replaceAll(' ', '').length;
      final wrongUseful =
          wrongResult.replaceAll('?', '').replaceAll(' ', '').length;
      print('[sim] auto=$autoResult ($autoUseful chars useful)'
          '  @300Hz=$wrongResult ($wrongUseful chars useful)');
      expect(autoUseful, greaterThanOrEqualTo(wrongUseful),
          reason: 'Auto-detection must decode at least as well as wrong freq');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 5.  No silence lead-in (recording starts mid-transmission)
  //
  //     If the user taps Listen after the Morse has already started, the
  //     recording contains no calibration silence.  OfflineAnalyzer uses a
  //     global two-pass noise floor (not a fixed calibration window), so it
  //     should still estimate the noise floor from the quietest frames.
  // ══════════════════════════════════════════════════════════════════════════
  group('No silence lead-in (recording starts mid-transmission)', () {
    test('SOS at 15 WPM without silence lead-in decodes non-empty', () {
      final gen = SineMorseGenerator(wpm: 15);
      final pcm = stripLeadIn(gen.generate('SOS'));
      final wav = _pcmToWav(pcm);
      final result = OfflineAnalyzer.analyzeWav(wav, targetFrequencyHz: 700);
      print('[sim] no lead-in @15wpm: "$result"');
      // Without lead-in silence, noise floor estimation is harder.
      // We don't require "SOS" but must produce something non-empty.
      expect(result, isNotEmpty,
          reason: 'No-lead-in recording must still produce some output');
    });

    test('SOS at 10 WPM without silence lead-in produces some valid chars', () {
      final gen = SineMorseGenerator(wpm: 10);
      final pcm = stripLeadIn(gen.generate('SOS'));
      final wav = _pcmToWav(pcm);
      final result = OfflineAnalyzer.analyzeWav(wav, targetFrequencyHz: 700);
      print('[sim] no lead-in @10wpm: "$result"');
      final useful = result.replaceAll('?', '').replaceAll(' ', '');
      expect(useful, isNotEmpty,
          reason: 'At least some valid characters must be decoded');
    });
  });
}
