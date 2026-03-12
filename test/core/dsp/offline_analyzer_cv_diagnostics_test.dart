// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/core/dsp/offline_analyzer.dart';

/// CV (Coefficient of Variation) Diagnostic Tests
/// 
/// Purpose: Investigate why speed detection works on synthetic signals
/// but fails on YouTube recordings. Hypothesis: YouTube CV > 0.40 prevents
/// speed detection from triggering.
/// 
/// Priority: Improving YouTube recording accuracy (yt1.wav, yt2.wav)
/// 
/// Strategy: Add CV logging to OfflineAnalyzer._detectSpeedChanges() to
/// measure actual CV values during decoding. This test file documents the
/// investigation approach and expected findings.

const _dir = 'scripts/test_wavs/custom_wavs';

String _decodeFile(String path, {double targetFrequencyHz = 700.0}) {
  final bytes = Uint8List.fromList(File(path).readAsBytesSync());
  return OfflineAnalyzer.analyzeWav(bytes, targetFrequencyHz: targetFrequencyHz).trim();
}

void main() {
  group('CV Diagnostics - YouTube Recordings', () {
    test('yt1.wav CV measurement (with enhanced logging)', () {
      print('\n=== yt1.wav CV Diagnostic ===');
      print('NOTE: Add CV logging to OfflineAnalyzer._detectSpeedChanges() to see:');
      print('  - Full segment CV');
      print('  - Sub-segment CVs at each potential split point');
      print('  - Speed ratios and whether CV threshold is met');
      print('');
      print('Expected: CV > 0.40 prevents speed detection from triggering');
      print('');
      
      final result = _decodeFile('$_dir/yt1.wav', targetFrequencyHz: 700);
      print('Decoded result: "$result"');
      print('');
      print('Analysis:');
      print('  - If result is still "T AOSRR?" → speed detection not triggering');
      print('  - Check CV values in logs to confirm CV > 0.40');
      print('  - If CV < 0.40 but still not splitting → other issue');
    });

    test('yt2.wav CV measurement (with enhanced logging)', () {
      print('\n=== yt2.wav CV Diagnostic ===');
      print('NOTE: Add CV logging to OfflineAnalyzer._detectSpeedChanges() to see:');
      print('  - Segment CVs for both segments');
      print('  - Why segments are marked invalid');
      print('');
      print('Expected: High CV or low ratio causes "?" output');
      print('');
      
      final result = _decodeFile('$_dir/yt2.wav', targetFrequencyHz: 600);
      print('Decoded result: "$result"');
      print('');
      print('Analysis:');
      print('  - Current result is "? ?" (worse than baseline)');
      print('  - Check CV values and ratio for each segment');
      print('  - Determine if CV threshold or ratio validation is the issue');
    });

    test('CV threshold recommendations', () {
      print('\n=== CV Threshold Analysis ===');
      print('');
      print('Current threshold: CV < 0.40 for BOTH sub-segments');
      print('');
      print('Hypothesis:');
      print('  - Clean synthetic signals: CV ≈ 0.10-0.20 ✓');
      print('  - YouTube recordings: CV ≈ 0.45-0.60 ✗');
      print('');
      print('Potential solutions:');
      print('  1. Raise CV threshold to 0.50 or 0.55');
      print('  2. Use alternative validation (MAD, IQR, ratio confidence)');
      print('  3. Hybrid: CV < 0.50 OR ratio > 2.0');
      print('');
      print('Next steps:');
      print('  1. Add CV logging to _detectSpeedChanges()');
      print('  2. Run yt1.wav and yt2.wav tests');
      print('  3. Analyze actual CV values');
      print('  4. Implement targeted fix based on findings');
    });
  });
}
