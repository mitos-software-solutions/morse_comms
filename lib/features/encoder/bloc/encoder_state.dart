part of 'encoder_bloc.dart';

enum PlaybackStatus { idle, playing }

enum SttStatus { idle, listening, error }

final class EncoderState {
  final String inputText;
  /// The transliterated (Latin/ASCII) version passed to the encoder.
  /// Empty when no transliteration was needed (pure ASCII input).
  final String transliteratedText;
  final String morseWritten; // e.g. "... --- ..."
  final PlaybackStatus playback;
  final SttStatus sttStatus;

  const EncoderState({
    this.inputText = '',
    this.transliteratedText = '',
    this.morseWritten = '',
    this.playback = PlaybackStatus.idle,
    this.sttStatus = SttStatus.idle,
  });

  bool get canPlay => morseWritten.isNotEmpty && playback == PlaybackStatus.idle;

  /// True when the input was transliterated and the UI should show
  /// the transliterated form alongside the original.
  bool get wasTransliterated =>
      transliteratedText.isNotEmpty &&
      transliteratedText != inputText.toUpperCase();

  EncoderState copyWith({
    String? inputText,
    String? transliteratedText,
    String? morseWritten,
    PlaybackStatus? playback,
    SttStatus? sttStatus,
  }) =>
      EncoderState(
        inputText: inputText ?? this.inputText,
        transliteratedText: transliteratedText ?? this.transliteratedText,
        morseWritten: morseWritten ?? this.morseWritten,
        playback: playback ?? this.playback,
        sttStatus: sttStatus ?? this.sttStatus,
      );
}
