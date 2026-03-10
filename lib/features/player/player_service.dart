import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:injectable/injectable.dart';

import '../../core/morse/morse_encoder.dart';
import '../../core/morse/morse_timing.dart';

/// Plays a [MorseEncoding] tone sequence as audible beeps.
///
/// Lifecycle:
///   1. Call [init] once (e.g. in app startup).
///   2. Call [play] to start a sequence; call [stop] to interrupt it.
///   3. Call [dispose] when the app is closing.
@lazySingleton
class PlayerService {
  AudioSource? _source;
  SoundHandle? _activeHandle;

  // Flipped to true by stop(); the play loop checks this each iteration.
  bool _stopRequested = false;

  bool get isPlaying => _activeHandle != null;

  /// Initialise SoLoud and pre-load a sine waveform.
  Future<void> init() async {
    await SoLoud.instance.init();
    _source = await SoLoud.instance.loadWaveform(
      WaveForm.sin,
      false, // superWave
      1.0,   // scale
      0.0,   // detune
    );
  }

  /// Play [tones] at [frequencyHz] (default 700 Hz) and [volume] (0.0–1.0).
  ///
  /// Returns as soon as the full sequence has played, or when [stop] is called.
  /// Calling [play] while already playing stops the current sequence first.
  Future<void> play(
    List<MorseTone> tones, {
    int frequencyHz = MorseTiming.defaultFrequencyHz,
    double volume = 0.7,
  }) async {
    if (_source == null) throw StateError('PlayerService.init() not called');

    await stop(); // cancel any in-progress sequence

    SoLoud.instance.setWaveformFreq(_source!, frequencyHz.toDouble());
    _stopRequested = false;

    for (final tone in tones) {
      if (_stopRequested) break;

      if (tone.on) {
        _activeHandle = await SoLoud.instance.play(
          _source!,
          volume: volume,
          looping: true, // sustain until we stop it manually
        );
        await Future.delayed(Duration(milliseconds: tone.durationMs));
        if (_activeHandle != null) {
          await SoLoud.instance.stop(_activeHandle!);
          _activeHandle = null;
        }
      } else {
        await Future.delayed(Duration(milliseconds: tone.durationMs));
      }
    }

    _stopRequested = false;
  }

  /// Stop the currently playing sequence immediately.
  Future<void> stop() async {
    _stopRequested = true;
    if (_activeHandle != null) {
      await SoLoud.instance.stop(_activeHandle!);
      _activeHandle = null;
    }
  }

  // ── Side-tone (continuous tone for decoder monitoring) ──────────────────

  SoundHandle? _sideToneHandle;

  // Guards against two concurrent startTone() calls both slipping past the
  // _sideToneHandle != null check before either play() resolves, which would
  // create multiple simultaneous handles with all but the last one leaked.
  bool _sideToneStarting = false;

  // Set by stopTone() to cancel a startTone() that is still awaiting play().
  bool _sideToneStopRequested = false;

  /// Start a continuous tone at [frequencyHz] for side-tone monitoring.
  ///
  /// No-op if already playing, [init] has not been called, or a start is
  /// already in progress.
  Future<void> startTone({int frequencyHz = MorseTiming.defaultFrequencyHz}) async {
    if (_source == null || _sideToneHandle != null || _sideToneStarting) return;
    _sideToneStarting = true;
    _sideToneStopRequested = false;
    SoLoud.instance.setWaveformFreq(_source!, frequencyHz.toDouble());
    try {
      final handle = await SoLoud.instance.play(
        _source!,
        volume: 0.5,
        looping: true,
      );
      // If stopTone() was called while play() was awaiting, kill immediately.
      if (_sideToneStopRequested) {
        await SoLoud.instance.stop(handle);
      } else {
        _sideToneHandle = handle;
      }
    } finally {
      _sideToneStarting = false;
    }
  }

  /// Stop the side-tone started by [startTone].
  Future<void> stopTone() async {
    _sideToneStopRequested = true;
    final handle = _sideToneHandle;
    if (handle != null) {
      _sideToneHandle = null; // clear before await so startTone() can proceed
      await SoLoud.instance.stop(handle);
    }
  }

  // ── WAV file playback (decoder preview) ─────────────────────────────────

  AudioSource? _wavSource;
  SoundHandle? _wavHandle;

  /// Play a WAV file from raw bytes. Stops any current WAV playback first.
  ///
  /// Playback is non-looping; the caller is responsible for calling [stopWav]
  /// when done (or when the estimated duration elapses).
  Future<void> playWav(Uint8List bytes) async {
    await stopWav();
    try {
      _wavSource = await SoLoud.instance.loadMem('decoder_preview', bytes);
      _wavHandle = await SoLoud.instance.play(_wavSource!, looping: false);
    } catch (_) {
      await _disposeWavSource();
    }
  }

  /// Stop WAV playback started by [playWav] and free the audio source.
  Future<void> stopWav() async {
    final handle = _wavHandle;
    _wavHandle = null;
    if (handle != null) {
      try {
        await SoLoud.instance.stop(handle);
      } catch (_) {
        // handle may have already expired naturally
      }
    }
    await _disposeWavSource();
  }

  Future<void> _disposeWavSource() async {
    final src = _wavSource;
    _wavSource = null;
    if (src != null) {
      try {
        await SoLoud.instance.disposeSource(src);
      } catch (_) {}
    }
  }

  /// Release all resources. Call once when the app is shutting down.
  @disposeMethod
  Future<void> dispose() async {
    await stop();
    await stopTone();
    await stopWav();
    if (_source != null) {
      await SoLoud.instance.disposeSource(_source!);
      _source = null;
    }
    SoLoud.instance.deinit();
  }
}
