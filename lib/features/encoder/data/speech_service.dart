import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wraps [SpeechToText] for the encoder feature.
///
/// Initialises lazily on first [startListening] call. The [onStatus]
/// callback set during [initialize] forwards to [_onSessionDone], which is
/// updated on every [startListening] call, so it always points at the most
/// recent session's done-callback.
class SpeechService {
  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;
  VoidCallback? _onSessionDone;

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    _initialized = await _stt.initialize(
      onStatus: (status) {
        if (status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) {
          _onSessionDone?.call();
        }
      },
    );
    return _initialized;
  }

  /// Starts an English STT session.
  ///
  /// Returns `false` if the microphone is unavailable or permission was denied.
  /// [onResult] fires for every partial and final recognition result.
  /// [onDone] fires when the session ends (silence timeout or explicit stop).
  Future<bool> startListening({
    required void Function(String words, bool isFinal) onResult,
    VoidCallback? onDone,
    String localeId = 'en_US',
  }) async {
    _onSessionDone = onDone;
    final ready = await _ensureInitialized();
    if (!ready) return false;

    _stt.listen(
      onResult: (SpeechRecognitionResult result) =>
          onResult(result.recognizedWords, result.finalResult),
      localeId: localeId,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );
    return true;
  }

  Future<void> stopListening() => _stt.stop();

  bool get isListening => _stt.isListening;

  void dispose() => _stt.cancel();
}
