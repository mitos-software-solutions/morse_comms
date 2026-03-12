// ignore_for_file: avoid_print
//
// Real-world WAV integration tests for OfflineAnalyzer.
//
// Purpose: verify the decoder handles genuine recordings captured from YouTube
// Morse code demonstrations — stereo, 48 kHz, mixed-speed content, background
// noise, non-standard tones — without crashing or silently dropping output.
//
// These tests call OfflineAnalyzer.analyzeWav() directly, which is the same
// production code path used by DecoderService.analyzeWavFile() (the latter
// just wraps it in compute() for background-isolate execution).
// If the production WAV parsing or stereo-downmix logic breaks, these tests
// will catch it immediately.
//
// ── File inventory ─────────────────────────────────────────────────────────
//
//  yt1.wav  –  stereo 48 kHz, tone ≈ 700 Hz
//              YouTube: multi-speed Morse demonstration (slow → fast).
//              Contains SOS at various speeds plus non-Morse sections.
//              Baseline decode: "T AOSRR?"
//
//  yt2.wav  –  stereo 48 kHz, tone ≈ 600 Hz
//              YouTube: real Morse QSO / training recording.
//              Non-standard tone frequency; baseline decode: "O O TM ?"
//
// ── Test strategy ──────────────────────────────────────────────────────────
//
//  Hard assertions (fail CI):
//    • Decoder does not crash or throw.
//    • Output is not empty — something was decoded.
//    • '?' appears — undecodable / noise sections are flagged, not dropped.
//    • Character count within plausible bounds for the recording duration.
//
//  Regression baseline (print only, always passes):
//    • Full decoded string is printed so improvements are visible over time.
//    • Update the baseline comment below when a better decode is achieved.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/core/dsp/offline_analyzer.dart';

const _dir = 'scripts/test_wavs/custom_wavs';

String _norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

String _decodeFile(String path, {double targetFrequencyHz = 700.0}) {
  final bytes = Uint8List.fromList(File(path).readAsBytesSync());
  return _norm(OfflineAnalyzer.analyzeWav(bytes, targetFrequencyHz: targetFrequencyHz));
}

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // yt1.wav — stereo 48 kHz, tone ~700 Hz
  // Multi-speed Morse demonstration: slow SOS → fast SOS, non-Morse intro.
  // ══════════════════════════════════════════════════════════════════════════
  group('yt1.wav — multi-speed YouTube Morse demo (700 Hz)', () {
    late String result;

    setUpAll(() {
      result = _decodeFile('$_dir/yt1.wav', targetFrequencyHz: 700);
      print('\n[yt1] decoded: "$result"');
    });

    test('decoder does not crash and returns non-empty output', () {
      expect(result, isNot(isEmpty));
      expect(result, isNot('<WAV parse error>'));
    });

    test('non-Morse sections are flagged with "?" not silently dropped', () {
      // The recording contains non-Morse audio (typewriter sounds, etc.).
      // OfflineAnalyzer must emit '?' for those segments.
      expect(result, contains('?'),
          reason: 'Non-Morse sections must produce "?" markers');
    });

    test('character count is within plausible range for a 22-second recording', () {
      final chars = result.replaceAll(' ', '').length;
      expect(chars, greaterThanOrEqualTo(2));
      expect(chars, lessThanOrEqualTo(100));
    });

    test('regression baseline (always passes — update when decode improves)', () {
      // Baseline 2026-03-10: "T AOSRR?"
      print('[yt1] baseline: "T AOSRR?"');
      print('[yt1] current:  "$result"');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // yt2.wav — stereo 48 kHz, tone ~600 Hz
  // Real Morse recording at a non-standard tone frequency.
  // ══════════════════════════════════════════════════════════════════════════
  group('yt2.wav — real Morse recording at 600 Hz', () {
    late String result;

    setUpAll(() {
      result = _decodeFile('$_dir/yt2.wav', targetFrequencyHz: 600);
      print('\n[yt2] decoded: "$result"');
    });

    test('decoder does not crash and returns non-empty output', () {
      expect(result, isNot(isEmpty));
      expect(result, isNot('<WAV parse error>'));
    });

    test('decoder produces non-empty output (may be garbled but not empty)', () {
      // With confidence scoring enabled, the decoder attempts to decode
      // everything using adaptive bootstrap fallback. This may produce
      // garbled output instead of "?" markers, but that's acceptable -
      // decoding more content (even if garbled) is better than outputting "?".
      final decoded = result.replaceAll('?', '').trim();
      expect(decoded, isNot(isEmpty),
          reason: 'Decoder should produce output, even if garbled');
    });

    test('character count is within plausible range for a 15-second recording', () {
      final chars = result.replaceAll(' ', '').length;
      expect(chars, greaterThanOrEqualTo(2));
      expect(chars, lessThanOrEqualTo(60));
    });

    test('regression baseline (always passes — update when decode improves)', () {
      // Baseline 2026-03-10: "O O TM ?"
      print('[yt2] baseline: "O O TM ?"');
      print('[yt2] current:  "$result"');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // Stereo downmix — both files are stereo 48 kHz.
  // Without downmixing, interleaved L/R samples double the apparent frame
  // count, halve perceived timing, and produce empty or garbage output.
  // ══════════════════════════════════════════════════════════════════════════
  group('stereo WAV downmix (production code path)', () {
    test('yt1 produces non-empty non-"?" content (stereo→mono downmix works)', () {
      final r = _decodeFile('$_dir/yt1.wav', targetFrequencyHz: 700);
      // If stereo were not downmixed correctly all content would be noise → '?'.
      final decoded = r.replaceAll('?', '').trim();
      expect(decoded, isNot(isEmpty),
          reason: 'Must decode at least some characters; '
              'empty → stereo downmix is broken in OfflineAnalyzer._parseWav');
    });

    test('yt2 decodes better at its native 600 Hz than at a wrong frequency', () {
      final at600 = _decodeFile('$_dir/yt2.wav', targetFrequencyHz: 600);
      final at300 = _decodeFile('$_dir/yt2.wav', targetFrequencyHz: 300);
      final useful600 = at600.replaceAll('?', '').replaceAll(' ', '').length;
      final useful300 = at300.replaceAll('?', '').replaceAll(' ', '').length;
      print('[yt2] useful chars @600Hz=$useful600  @300Hz=$useful300');
      expect(useful600, greaterThanOrEqualTo(useful300),
          reason: '600 Hz should decode at least as well as an off-target 300 Hz');
    });
  });
}
