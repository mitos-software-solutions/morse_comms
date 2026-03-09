part of 'encoder_bloc.dart';

sealed class EncoderEvent {}

/// User typed or cleared text in the input field.
final class EncoderTextChanged extends EncoderEvent {
  final String text;
  EncoderTextChanged(this.text);
}

/// User pressed Play.
final class EncoderPlayRequested extends EncoderEvent {}

/// User pressed Stop.
final class EncoderStopRequested extends EncoderEvent {}

/// Settings (WPM, tone frequency, or STT locale) changed while the encoder is active.
final class EncoderSettingsChanged extends EncoderEvent {
  final int wpm;
  final int frequencyHz;
  final String sttLocaleId;
  EncoderSettingsChanged({
    required this.wpm,
    required this.frequencyHz,
    required this.sttLocaleId,
  });
}

/// User tapped the mic button to start speech recognition.
final class EncoderSttStartRequested extends EncoderEvent {}

/// User tapped the mic button again to stop recognition early.
final class EncoderSttStopRequested extends EncoderEvent {}

/// Internal — fired by the SpeechService callback when words are recognised.
final class EncoderSttResult extends EncoderEvent {
  final String words;
  final bool isFinal;
  EncoderSttResult(this.words, {required this.isFinal});
}

/// Internal — fired when the STT session ends naturally (silence / timeout).
final class EncoderSttCompleted extends EncoderEvent {}
