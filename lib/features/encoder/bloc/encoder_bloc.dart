import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/morse/morse_encoder.dart';
import '../../../core/morse/morse_timing.dart';
import '../../../core/morse/transliterator.dart';
import '../../player/player_service.dart';
import '../data/speech_service.dart';

part 'encoder_event.dart';
part 'encoder_state.dart';

class EncoderBloc extends Bloc<EncoderEvent, EncoderState> {
  final PlayerService _player;
  final SpeechService _speech;
  late MorseEncoder _encoder;
  late int _frequencyHz;
  late String _sttLocaleId;

  EncoderBloc({
    required PlayerService player,
    SpeechService? speechService,
    int wpm = MorseTiming.defaultWpm,
    int frequencyHz = MorseTiming.defaultFrequencyHz,
    String sttLocaleId = 'en_US',
  })  : _player = player,
        _speech = speechService ?? SpeechService(),
        super(const EncoderState()) {
    _encoder = MorseEncoder(timing: MorseTiming(wpm: wpm));
    _frequencyHz = frequencyHz;
    _sttLocaleId = sttLocaleId;
    on<EncoderTextChanged>(_onTextChanged);
    on<EncoderPlayRequested>(_onPlayRequested);
    on<EncoderStopRequested>(_onStopRequested);
    on<EncoderSettingsChanged>(_onSettingsChanged);
    on<EncoderSttStartRequested>(_onSttStartRequested);
    on<EncoderSttStopRequested>(_onSttStopRequested);
    on<EncoderSttResult>(_onSttResult);
    on<EncoderSttCompleted>(_onSttCompleted);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Transliterates [text] then encodes it. Returns both the transliterated
  /// string and the [MorseEncoding].
  ({String transliterated, MorseEncoding encoding}) _process(String text) {
    final transliterated = MorseTransliterator.transliterate(text);
    final encoding = _encoder.encode(transliterated);
    return (transliterated: transliterated, encoding: encoding);
  }

  // ---------------------------------------------------------------------------
  // Event handlers
  // ---------------------------------------------------------------------------

  void _onTextChanged(EncoderTextChanged event, Emitter<EncoderState> emit) {
    final result = _process(event.text);
    emit(state.copyWith(
      inputText: event.text,
      transliteratedText: result.transliterated,
      morseWritten: result.encoding.written,
      playback: PlaybackStatus.idle,
    ));
  }

  Future<void> _onPlayRequested(
    EncoderPlayRequested event,
    Emitter<EncoderState> emit,
  ) async {
    if (!state.canPlay) return;

    final result = _process(state.inputText);
    emit(state.copyWith(playback: PlaybackStatus.playing));

    await _player.play(result.encoding.tones, frequencyHz: _frequencyHz);

    if (!isClosed) emit(state.copyWith(playback: PlaybackStatus.idle));
  }

  void _onSettingsChanged(
    EncoderSettingsChanged event,
    Emitter<EncoderState> emit,
  ) {
    _frequencyHz = event.frequencyHz;
    _sttLocaleId = event.sttLocaleId;
    _encoder = MorseEncoder(timing: MorseTiming(wpm: event.wpm));
    if (state.inputText.isNotEmpty) {
      final result = _process(state.inputText);
      emit(state.copyWith(
        transliteratedText: result.transliterated,
        morseWritten: result.encoding.written,
      ));
    }
  }

  Future<void> _onStopRequested(
    EncoderStopRequested event,
    Emitter<EncoderState> emit,
  ) async {
    await _player.stop();
    emit(state.copyWith(playback: PlaybackStatus.idle));
  }

  Future<void> _onSttStartRequested(
    EncoderSttStartRequested event,
    Emitter<EncoderState> emit,
  ) async {
    emit(state.copyWith(sttStatus: SttStatus.listening));

    final success = await _speech.startListening(
      localeId: _sttLocaleId,
      onResult: (words, isFinal) {
        if (!isClosed) add(EncoderSttResult(words, isFinal: isFinal));
      },
      onDone: () {
        if (!isClosed) add(EncoderSttCompleted());
      },
    );

    if (!success && !isClosed) {
      emit(state.copyWith(sttStatus: SttStatus.error));
    }
  }

  Future<void> _onSttStopRequested(
    EncoderSttStopRequested event,
    Emitter<EncoderState> emit,
  ) async {
    await _speech.stopListening();
    emit(state.copyWith(sttStatus: SttStatus.idle));
  }

  void _onSttResult(EncoderSttResult event, Emitter<EncoderState> emit) {
    if (event.words.isEmpty) return;
    final result = _process(event.words);
    emit(state.copyWith(
      inputText: event.words,
      transliteratedText: result.transliterated,
      morseWritten: result.encoding.written,
      sttStatus: event.isFinal ? SttStatus.idle : SttStatus.listening,
    ));
  }

  void _onSttCompleted(EncoderSttCompleted event, Emitter<EncoderState> emit) {
    if (state.sttStatus == SttStatus.listening) {
      emit(state.copyWith(sttStatus: SttStatus.idle));
    }
  }

  @override
  Future<void> close() async {
    await _player.stop();
    _speech.dispose();
    return super.close();
  }
}
