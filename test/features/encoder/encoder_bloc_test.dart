import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/core/morse/morse_encoder.dart';
import 'package:morse_comms/core/morse/morse_timing.dart';
import 'package:morse_comms/features/encoder/bloc/encoder_bloc.dart';
import 'package:morse_comms/features/encoder/data/speech_service.dart';
import 'package:morse_comms/features/player/player_service.dart';

// ---------------------------------------------------------------------------
// Stub PlayerService — no audio hardware involved.
// ---------------------------------------------------------------------------

class _StubPlayerService extends PlayerService {
  bool playCalled = false;
  bool stopCalled = false;
  List<MorseTone>? lastTones;
  int? lastFrequencyHz;

  @override
  Future<void> play(
    List<MorseTone> tones, {
    int frequencyHz = MorseTiming.defaultFrequencyHz,
    double volume = 0.7,
  }) async {
    playCalled = true;
    lastTones = tones;
    lastFrequencyHz = frequencyHz;
  }

  @override
  Future<void> stop() async {
    stopCalled = true;
  }

  @override
  Future<void> dispose() async {}
}

// ---------------------------------------------------------------------------
// Stub SpeechService — no platform channel involved.
// ---------------------------------------------------------------------------

class _StubSpeechService extends SpeechService {
  bool startCalled = false;
  bool stopCalled = false;
  String? lastLocaleId;
  bool startReturns = true;

  void Function(String words, bool isFinal)? capturedOnResult;
  VoidCallback? capturedOnDone;

  @override
  Future<bool> startListening({
    required void Function(String words, bool isFinal) onResult,
    VoidCallback? onDone,
    String localeId = 'en_US',
  }) async {
    startCalled = true;
    lastLocaleId = localeId;
    capturedOnResult = onResult;
    capturedOnDone = onDone;
    return startReturns;
  }

  @override
  Future<void> stopListening() async {
    stopCalled = true;
  }

  @override
  void dispose() {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

EncoderBloc _makeBloc({
  _StubPlayerService? player,
  _StubSpeechService? speech,
  int wpm = MorseTiming.defaultWpm,
  int frequencyHz = MorseTiming.defaultFrequencyHz,
  String sttLocaleId = 'en_US',
}) {
  return EncoderBloc(
    player: player ?? _StubPlayerService(),
    speechService: speech ?? _StubSpeechService(),
    wpm: wpm,
    frequencyHz: frequencyHz,
    sttLocaleId: sttLocaleId,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('EncoderBloc — initial state', () {
    test('starts with empty text and idle playback', () {
      final bloc = _makeBloc();
      expect(bloc.state.inputText, '');
      expect(bloc.state.morseWritten, '');
      expect(bloc.state.transliteratedText, '');
      expect(bloc.state.playback, PlaybackStatus.idle);
      expect(bloc.state.sttStatus, SttStatus.idle);
      bloc.close();
    });

    test('canPlay is false when morseWritten is empty', () {
      final bloc = _makeBloc();
      expect(bloc.state.canPlay, isFalse);
      bloc.close();
    });

    test('wasTransliterated is false on initial state', () {
      final bloc = _makeBloc();
      expect(bloc.state.wasTransliterated, isFalse);
      bloc.close();
    });
  });

  group('EncoderBloc — EncoderTextChanged', () {
    test('encodes SOS correctly', () async {
      final bloc = _makeBloc();
      bloc.add(EncoderTextChanged('SOS'));
      await Future.delayed(Duration.zero);
      expect(bloc.state.morseWritten, '... --- ...');
      await bloc.close();
    });

    test('encodes single character', () async {
      final bloc = _makeBloc();
      bloc.add(EncoderTextChanged('K'));
      await Future.delayed(Duration.zero);
      expect(bloc.state.morseWritten, '-.-');
      await bloc.close();
    });

    test('stores inputText in state', () async {
      final bloc = _makeBloc();
      bloc.add(EncoderTextChanged('hello'));
      await Future.delayed(Duration.zero);
      expect(bloc.state.inputText, 'hello');
      await bloc.close();
    });

    test('empty text clears morseWritten', () async {
      final bloc = _makeBloc();
      bloc.add(EncoderTextChanged('SOS'));
      await Future.delayed(Duration.zero);
      bloc.add(EncoderTextChanged(''));
      await Future.delayed(Duration.zero);
      expect(bloc.state.morseWritten, '');
      await bloc.close();
    });

    test('canPlay becomes true after valid text is entered', () async {
      final bloc = _makeBloc();
      bloc.add(EncoderTextChanged('K'));
      await Future.delayed(Duration.zero);
      expect(bloc.state.canPlay, isTrue);
      await bloc.close();
    });

    test('resets playback to idle on text change', () async {
      final bloc = _makeBloc();
      bloc.add(EncoderTextChanged('SOS'));
      await Future.delayed(Duration.zero);
      expect(bloc.state.playback, PlaybackStatus.idle);
      await bloc.close();
    });
  });

  group('EncoderBloc — transliteration', () {
    test('ASCII input: wasTransliterated is false', () async {
      final bloc = _makeBloc();
      bloc.add(EncoderTextChanged('HELLO'));
      await Future.delayed(Duration.zero);
      expect(bloc.state.wasTransliterated, isFalse);
      await bloc.close();
    });

    test('ASCII with mixed case: wasTransliterated is false', () async {
      final bloc = _makeBloc();
      bloc.add(EncoderTextChanged('Hello'));
      await Future.delayed(Duration.zero);
      expect(bloc.state.wasTransliterated, isFalse);
      await bloc.close();
    });

    test('diacritics input: wasTransliterated is true', () async {
      final bloc = _makeBloc();
      bloc.add(EncoderTextChanged('héllo'));
      await Future.delayed(Duration.zero);
      expect(bloc.state.wasTransliterated, isTrue);
      expect(bloc.state.transliteratedText, 'HELLO');
      await bloc.close();
    });

    test('Cyrillic input is transliterated and encoded', () async {
      final bloc = _makeBloc();
      bloc.add(EncoderTextChanged('СОС')); // Cyrillic SOS
      await Future.delayed(Duration.zero);
      expect(bloc.state.wasTransliterated, isTrue);
      expect(bloc.state.transliteratedText, 'SOS');
      expect(bloc.state.morseWritten, '... --- ...');
      await bloc.close();
    });

    test('transliteratedText stored even for pure ASCII (uppercased form)', () async {
      final bloc = _makeBloc();
      bloc.add(EncoderTextChanged('sos'));
      await Future.delayed(Duration.zero);
      expect(bloc.state.transliteratedText, 'SOS');
      expect(bloc.state.wasTransliterated, isFalse); // 'SOS' == 'sos'.toUpperCase()
      await bloc.close();
    });

    test('diacritics stripped: é→E, ü→U, ñ→N', () async {
      final bloc = _makeBloc();
      bloc.add(EncoderTextChanged('éün'));
      await Future.delayed(Duration.zero);
      expect(bloc.state.transliteratedText, 'EUN');
      expect(bloc.state.wasTransliterated, isTrue);
      await bloc.close();
    });
  });

  group('EncoderBloc — EncoderSettingsChanged', () {
    test('re-encodes existing text at new WPM (morseWritten unchanged, timing changes)', () async {
      final bloc = _makeBloc(wpm: 20);
      bloc.add(EncoderTextChanged('SOS'));
      await Future.delayed(Duration.zero);
      final beforeMorse = bloc.state.morseWritten;

      bloc.add(EncoderSettingsChanged(wpm: 30, frequencyHz: 700, sttLocaleId: 'en_US'));
      await Future.delayed(Duration.zero);
      expect(bloc.state.morseWritten, beforeMorse);
      await bloc.close();
    });

    test('updates frequencyHz used for playback', () async {
      final player = _StubPlayerService();
      final bloc = _makeBloc(player: player, wpm: 20, frequencyHz: 600);
      bloc.add(EncoderTextChanged('K'));
      await Future.delayed(Duration.zero);

      bloc.add(EncoderSettingsChanged(wpm: 20, frequencyHz: 800, sttLocaleId: 'en_US'));
      await Future.delayed(Duration.zero);

      bloc.add(EncoderPlayRequested());
      await Future.delayed(Duration.zero);
      expect(player.lastFrequencyHz, 800);
      await bloc.close();
    });

    test('does not emit when input text is empty', () async {
      final bloc = _makeBloc();
      bloc.add(EncoderSettingsChanged(wpm: 15, frequencyHz: 700, sttLocaleId: 'en_US'));
      await Future.delayed(Duration.zero);
      expect(bloc.state.morseWritten, '');
      await bloc.close();
    });

    test('re-encodes text after WPM change produces same symbols', () async {
      final bloc15 = _makeBloc(wpm: 15);
      bloc15.add(EncoderTextChanged('PARIS'));
      await Future.delayed(Duration.zero);
      final morse15 = bloc15.state.morseWritten;

      final bloc30 = _makeBloc(wpm: 30);
      bloc30.add(EncoderTextChanged('PARIS'));
      await Future.delayed(Duration.zero);
      final morse30 = bloc30.state.morseWritten;

      expect(morse15, morse30);
      await Future.wait([bloc15.close(), bloc30.close()]);
    });

    test('updates sttLocaleId for future STT sessions', () async {
      final speech = _StubSpeechService();
      final bloc = _makeBloc(speech: speech, sttLocaleId: 'en_US');

      bloc.add(EncoderSettingsChanged(wpm: 20, frequencyHz: 700, sttLocaleId: 'es_ES'));
      await Future.delayed(Duration.zero);

      bloc.add(EncoderSttStartRequested());
      await Future.delayed(Duration.zero);

      expect(speech.lastLocaleId, 'es_ES');
      await bloc.close();
    });
  });

  group('EncoderBloc — EncoderPlayRequested', () {
    test('calls player.play() with encoded tones', () async {
      final player = _StubPlayerService();
      final bloc = _makeBloc(player: player);
      bloc.add(EncoderTextChanged('K'));
      await Future.delayed(Duration.zero);

      bloc.add(EncoderPlayRequested());
      await Future.delayed(Duration.zero);
      expect(player.playCalled, isTrue);
      expect(player.lastTones, isNotEmpty);
      await bloc.close();
    });

    test('passes the configured frequencyHz to player', () async {
      final player = _StubPlayerService();
      final bloc = _makeBloc(player: player, frequencyHz: 550);
      bloc.add(EncoderTextChanged('M'));
      await Future.delayed(Duration.zero);
      bloc.add(EncoderPlayRequested());
      await Future.delayed(Duration.zero);
      expect(player.lastFrequencyHz, 550);
      await bloc.close();
    });

    test('does nothing when morseWritten is empty', () async {
      final player = _StubPlayerService();
      final bloc = _makeBloc(player: player);
      bloc.add(EncoderPlayRequested());
      await Future.delayed(Duration.zero);
      expect(player.playCalled, isFalse);
      await bloc.close();
    });
  });

  group('EncoderBloc — EncoderStopRequested', () {
    test('calls player.stop()', () async {
      final player = _StubPlayerService();
      final bloc = _makeBloc(player: player);
      bloc.add(EncoderStopRequested());
      await Future.delayed(Duration.zero);
      expect(player.stopCalled, isTrue);
      await bloc.close();
    });

    test('emits idle playback status after stop', () async {
      final player = _StubPlayerService();
      final bloc = _makeBloc(player: player);
      bloc.add(EncoderTextChanged('SOS'));
      await Future.delayed(Duration.zero);
      bloc.add(EncoderStopRequested());
      await Future.delayed(Duration.zero);
      expect(bloc.state.playback, PlaybackStatus.idle);
      await bloc.close();
    });
  });

  group('EncoderBloc — STT events', () {
    test('EncoderSttStartRequested sets status to listening', () async {
      final speech = _StubSpeechService();
      final bloc = _makeBloc(speech: speech);
      bloc.add(EncoderSttStartRequested());
      await Future.delayed(Duration.zero);
      expect(bloc.state.sttStatus, SttStatus.listening);
      await bloc.close();
    });

    test('EncoderSttStartRequested passes configured locale to SpeechService', () async {
      final speech = _StubSpeechService();
      final bloc = _makeBloc(speech: speech, sttLocaleId: 'fr_FR');
      bloc.add(EncoderSttStartRequested());
      await Future.delayed(Duration.zero);
      expect(speech.lastLocaleId, 'fr_FR');
      await bloc.close();
    });

    test('mic unavailable sets sttStatus to error', () async {
      final speech = _StubSpeechService()..startReturns = false;
      final bloc = _makeBloc(speech: speech);
      bloc.add(EncoderSttStartRequested());
      await Future.delayed(Duration.zero);
      expect(bloc.state.sttStatus, SttStatus.error);
      await bloc.close();
    });

    test('EncoderSttResult partial: updates text but keeps sttStatus listening', () async {
      final speech = _StubSpeechService();
      final bloc = _makeBloc(speech: speech);
      bloc.add(EncoderSttStartRequested());
      await Future.delayed(Duration.zero);

      bloc.add(EncoderSttResult('hello', isFinal: false));
      await Future.delayed(Duration.zero);
      expect(bloc.state.inputText, 'hello');
      expect(bloc.state.morseWritten, isNotEmpty);
      expect(bloc.state.sttStatus, SttStatus.listening);
      await bloc.close();
    });

    test('EncoderSttResult final: updates text and sets sttStatus to idle', () async {
      final speech = _StubSpeechService();
      final bloc = _makeBloc(speech: speech);
      bloc.add(EncoderSttStartRequested());
      await Future.delayed(Duration.zero);

      bloc.add(EncoderSttResult('SOS', isFinal: true));
      await Future.delayed(Duration.zero);
      expect(bloc.state.inputText, 'SOS');
      expect(bloc.state.morseWritten, '... --- ...');
      expect(bloc.state.sttStatus, SttStatus.idle);
      await bloc.close();
    });

    test('EncoderSttResult with empty words is ignored', () async {
      final speech = _StubSpeechService();
      final bloc = _makeBloc(speech: speech);
      bloc.add(EncoderTextChanged('SOS'));
      await Future.delayed(Duration.zero);

      bloc.add(EncoderSttResult('', isFinal: true));
      await Future.delayed(Duration.zero);
      // State unchanged
      expect(bloc.state.morseWritten, '... --- ...');
      await bloc.close();
    });

    test('EncoderSttCompleted sets sttStatus to idle if still listening', () async {
      final speech = _StubSpeechService();
      final bloc = _makeBloc(speech: speech);
      bloc.add(EncoderSttStartRequested());
      await Future.delayed(Duration.zero);
      expect(bloc.state.sttStatus, SttStatus.listening);

      bloc.add(EncoderSttCompleted());
      await Future.delayed(Duration.zero);
      expect(bloc.state.sttStatus, SttStatus.idle);
      await bloc.close();
    });

    test('EncoderSttCompleted is a no-op if already idle', () async {
      final speech = _StubSpeechService();
      final bloc = _makeBloc(speech: speech);
      expect(bloc.state.sttStatus, SttStatus.idle);

      bloc.add(EncoderSttCompleted());
      await Future.delayed(Duration.zero);
      expect(bloc.state.sttStatus, SttStatus.idle);
      await bloc.close();
    });

    test('EncoderSttStopRequested calls stopListening and resets status', () async {
      final speech = _StubSpeechService();
      final bloc = _makeBloc(speech: speech);
      bloc.add(EncoderSttStartRequested());
      await Future.delayed(Duration.zero);

      bloc.add(EncoderSttStopRequested());
      await Future.delayed(Duration.zero);
      expect(speech.stopCalled, isTrue);
      expect(bloc.state.sttStatus, SttStatus.idle);
      await bloc.close();
    });

    test('STT result for Cyrillic is transliterated correctly', () async {
      final speech = _StubSpeechService();
      final bloc = _makeBloc(speech: speech);
      bloc.add(EncoderSttResult('СОС', isFinal: true)); // Cyrillic СОС
      await Future.delayed(Duration.zero);
      expect(bloc.state.transliteratedText, 'SOS');
      expect(bloc.state.morseWritten, '... --- ...');
      await bloc.close();
    });
  });

  group('EncoderBloc — EncoderState.canPlay', () {
    test('is false when morseWritten is empty', () {
      final bloc = _makeBloc();
      expect(bloc.state.canPlay, isFalse);
      bloc.close();
    });

    test('is true when morseWritten is non-empty and playback is idle', () async {
      final bloc = _makeBloc();
      bloc.add(EncoderTextChanged('K'));
      await Future.delayed(Duration.zero);
      expect(bloc.state.canPlay, isTrue);
      await bloc.close();
    });
  });
}
