import 'dart:math';
import 'dart:typed_data';

import 'morse_encoder.dart';

/// Synthesizes a list of [MorseTone] events into a 16-bit mono 44 100 Hz WAV.
///
/// The output is compatible with both [PlayerService.playWav] (audio playback)
/// and [OfflineAnalyzer.analyzeWav] (offline Morse decoding).
///
/// Three signal-quality mitigations are built in to ensure reliable decoding:
///
/// 1. **Leading silence** ([leadingMs] = 100 ms): ensures the global two-pass
///    noise-floor p33 percentile is computed from silence frames, not tone frames.
///
/// 2. **Trailing silence** ([trailingMs] = 250 ms): flushes the last symbol
///    through the 2-frame debounce inside [OfflineAnalyzer] so the final
///    character is never silently dropped.
///
/// 3. **Tiny noise floor in silence sections** (±[noiseAmplitude] = 15 LSB):
///    prevents `threshold = 6 × noise_floor` from collapsing to zero.  A zero
///    threshold would treat every Goertzel ringing artefact as a tone.  The
///    noise is seeded (deterministic), so test output is reproducible.
///
/// A 5 ms linear fade-in/fade-out ([fadeSamples] = 220 samples) is applied to
/// every tone onset and offset to eliminate audible clicks during playback.
class MorseWavSynthesizer {
  // ── Public constants (used by tests) ───────────────────────────────────────
  static const int sampleRate = 44100;
  static const double amplitude = 16000.0; // ~49 % full-scale — matches SineMorseGenerator
  static const int noiseAmplitude = 15;    // ~0.05 % — prevents threshold collapse
  static const int leadingMs = 100;        // calibration lead-in
  static const int trailingMs = 250;       // final debounce flush
  static const int fadeSamples = 220;      // ~5 ms at 44 100 Hz

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Synthesizes [tones] at [frequencyHz] into a WAV byte buffer.
  static Uint8List synthesize(List<MorseTone> tones, int frequencyHz) {
    final rng = Random(42); // seeded for reproducible tests
    final sections = <Int16List>[];

    sections.add(_silence(_msToSamples(leadingMs), rng));

    for (final tone in tones) {
      final n = _msToSamples(tone.durationMs);
      sections.add(
        tone.on ? _sineWithFade(n, frequencyHz, rng) : _silence(n, rng),
      );
    }

    sections.add(_silence(_msToSamples(trailingMs), rng));

    // Flatten sections into a single PCM buffer.
    final totalSamples = sections.fold(0, (s, l) => s + l.length);
    final pcm = Int16List(totalSamples);
    var offset = 0;
    for (final s in sections) {
      pcm.setRange(offset, offset + s.length, s);
      offset += s.length;
    }

    final pcmBytes = pcm.buffer.asUint8List();
    final header = _buildWavHeader(pcmBytes.length);
    final result = Uint8List(header.length + pcmBytes.length);
    result.setRange(0, header.length, header);
    result.setRange(header.length, result.length, pcmBytes);
    return result;
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  static int _msToSamples(int ms) => (ms * sampleRate / 1000).round();

  /// Silence with a tiny ±[noiseAmplitude] dither so p33 > 0 in Goertzel analysis.
  static Int16List _silence(int samples, Random rng) {
    final buf = Int16List(samples);
    for (int i = 0; i < samples; i++) {
      buf[i] = rng.nextInt(noiseAmplitude * 2 + 1) - noiseAmplitude;
    }
    return buf;
  }

  /// Sine wave at [frequencyHz] with linear fade-in and fade-out to prevent clicks.
  static Int16List _sineWithFade(int samples, int frequencyHz, Random rng) {
    final buf = Int16List(samples);
    // Compress the fade window if the tone is shorter than two full fades.
    final fade = samples < fadeSamples * 2 ? samples ~/ 2 : fadeSamples;
    for (int i = 0; i < samples; i++) {
      double env = 1.0;
      if (i < fade) {
        env = i / fade;
      } else if (i >= samples - fade) {
        env = (samples - 1 - i) / fade;
      }
      final sine = amplitude * sin(2 * pi * frequencyHz * i / sampleRate);
      final noise = rng.nextInt(noiseAmplitude * 2 + 1) - noiseAmplitude;
      buf[i] = (sine * env + noise).round().clamp(-32768, 32767);
    }
    return buf;
  }

  /// Standard 44-byte RIFF/WAVE/fmt /data header for 16-bit mono PCM.
  static Uint8List _buildWavHeader(int numPcmBytes) {
    final bd = ByteData(44);
    // 'RIFF'
    bd.setUint8(0, 0x52); bd.setUint8(1, 0x49); bd.setUint8(2, 0x46); bd.setUint8(3, 0x46);
    bd.setUint32(4, numPcmBytes + 36, Endian.little); // file size − 8
    // 'WAVE'
    bd.setUint8(8, 0x57); bd.setUint8(9, 0x41); bd.setUint8(10, 0x56); bd.setUint8(11, 0x45);
    // 'fmt '
    bd.setUint8(12, 0x66); bd.setUint8(13, 0x6D); bd.setUint8(14, 0x74); bd.setUint8(15, 0x20);
    bd.setUint32(16, 16, Endian.little);               // PCM subchunk size
    bd.setUint16(20, 1, Endian.little);                // AudioFormat = PCM
    bd.setUint16(22, 1, Endian.little);                // NumChannels = mono
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, sampleRate * 2, Endian.little);   // ByteRate
    bd.setUint16(32, 2, Endian.little);                // BlockAlign
    bd.setUint16(34, 16, Endian.little);               // BitsPerSample
    // 'data'
    bd.setUint8(36, 0x64); bd.setUint8(37, 0x61); bd.setUint8(38, 0x74); bd.setUint8(39, 0x61);
    bd.setUint32(40, numPcmBytes, Endian.little);
    return bd.buffer.asUint8List();
  }
}
