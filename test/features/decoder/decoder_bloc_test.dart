import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:morse_comms/core/dsp/decoder_pipeline.dart';
import 'package:morse_comms/features/decoder/bloc/decoder_bloc.dart';

import '../../helpers/fake_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DecoderBloc', () {
    group('Initial State', () {
      test('initial state is idle with empty decoded text', () {
        // Verify the initial state structure
        const initialState = DecoderState();
        expect(initialState.status, equals(DecoderStatus.idle));
        expect(initialState.decodedText, isEmpty);
        expect(initialState.permissionDenied, isFalse);
        expect(initialState.recordingSeconds, equals(0));
        expect(initialState.signalSnapshot, isNull);
        expect(initialState.savedPath, isNull);
        expect(initialState.errorMessage, isNull);
        expect(initialState.isFileAnalysis, isFalse);
        expect(initialState.audioBytes, isNull);
      });

      test('initial state canListen is true', () {
        const initialState = DecoderState();
        expect(initialState.canListen, isTrue);
      });

      test('initial state canSave is false', () {
        const initialState = DecoderState();
        expect(initialState.canSave, isFalse);
      });

      test('initial state canShare is false', () {
        const initialState = DecoderState();
        expect(initialState.canShare, isFalse);
      });
    });

    group('DecoderStatus Enum', () {
      test('DecoderStatus has idle value', () {
        expect(DecoderStatus.idle, isNotNull);
      });

      test('DecoderStatus has listening value', () {
        expect(DecoderStatus.listening, isNotNull);
      });

      test('DecoderStatus has analyzing value', () {
        expect(DecoderStatus.analyzing, isNotNull);
      });

      test('DecoderStatus has result value', () {
        expect(DecoderStatus.result, isNotNull);
      });
    });

    group('DecoderState copyWith', () {
      test('copyWith updates status', () {
        const initialState = DecoderState();
        final updated = initialState.copyWith(status: DecoderStatus.listening);
        
        expect(updated.status, equals(DecoderStatus.listening));
        expect(updated.decodedText, equals(initialState.decodedText));
      });

      test('copyWith updates decodedText', () {
        const initialState = DecoderState();
        final updated = initialState.copyWith(decodedText: 'SOS');
        
        expect(updated.decodedText, equals('SOS'));
        expect(updated.status, equals(initialState.status));
      });

      test('copyWith updates recordingSeconds', () {
        const initialState = DecoderState();
        final updated = initialState.copyWith(recordingSeconds: 10);
        
        expect(updated.recordingSeconds, equals(10));
      });

      test('copyWith updates permissionDenied', () {
        const initialState = DecoderState();
        final updated = initialState.copyWith(permissionDenied: true);
        
        expect(updated.permissionDenied, isTrue);
      });

      test('copyWith updates isFileAnalysis', () {
        const initialState = DecoderState();
        final updated = initialState.copyWith(isFileAnalysis: true);
        
        expect(updated.isFileAnalysis, isTrue);
      });

      test('copyWith updates savedPath', () {
        const initialState = DecoderState();
        final updated = initialState.copyWith(savedPath: '/path/to/file.wav');
        
        expect(updated.savedPath, equals('/path/to/file.wav'));
      });

      test('copyWith updates errorMessage', () {
        const initialState = DecoderState();
        final updated = initialState.copyWith(errorMessage: 'Error occurred');
        
        expect(updated.errorMessage, equals('Error occurred'));
      });

      test('copyWith updates audioBytes', () {
        const initialState = DecoderState();
        final audioBytes = Uint8List(100);
        final updated = initialState.copyWith(audioBytes: audioBytes);
        
        expect(updated.audioBytes, equals(audioBytes));
      });

      test('copyWith clears signal when clearSignal is true', () {
        final stateWithSignal = DecoderState(
          signalSnapshot: SignalSnapshot(
            power: 100.0,
            noiseFloor: 10.0,
            isTone: true,
          ),
        );
        final updated = stateWithSignal.copyWith(clearSignal: true);
        
        expect(updated.signalSnapshot, isNull);
      });

      test('copyWith clears error when clearError is true', () {
        const stateWithError = DecoderState(errorMessage: 'Error');
        final updated = stateWithError.copyWith(clearError: true);
        
        expect(updated.errorMessage, isNull);
      });

      test('copyWith clears savedPath when clearSavedPath is true', () {
        const stateWithPath = DecoderState(savedPath: '/path/to/file.wav');
        final updated = stateWithPath.copyWith(clearSavedPath: true);
        
        expect(updated.savedPath, isNull);
      });

      test('copyWith clears audioBytes when clearAudioBytes is true', () {
        final stateWithBytes = DecoderState(audioBytes: Uint8List(100));
        final updated = stateWithBytes.copyWith(clearAudioBytes: true);
        
        expect(updated.audioBytes, isNull);
      });
    });

    group('State Helpers', () {
      test('isListening returns true when status is listening', () {
        final state = DecoderState(status: DecoderStatus.listening);
        expect(state.isListening, isTrue);
      });

      test('isListening returns false when status is not listening', () {
        const state = DecoderState();
        expect(state.isListening, isFalse);
      });

      test('isAnalyzing returns true when status is analyzing', () {
        final state = DecoderState(status: DecoderStatus.analyzing);
        expect(state.isAnalyzing, isTrue);
      });

      test('isAnalyzing returns false when status is not analyzing', () {
        const state = DecoderState();
        expect(state.isAnalyzing, isFalse);
      });

      test('hasResult returns true when status is result', () {
        final state = DecoderState(status: DecoderStatus.result);
        expect(state.hasResult, isTrue);
      });

      test('hasResult returns false when status is not result', () {
        const state = DecoderState();
        expect(state.hasResult, isFalse);
      });

      test('canListen is true when idle', () {
        const state = DecoderState(status: DecoderStatus.idle);
        expect(state.canListen, isTrue);
      });

      test('canListen is true when result', () {
        final state = DecoderState(status: DecoderStatus.result);
        expect(state.canListen, isTrue);
      });

      test('canListen is false when listening', () {
        final state = DecoderState(status: DecoderStatus.listening);
        expect(state.canListen, isFalse);
      });

      test('canListen is false when analyzing', () {
        final state = DecoderState(status: DecoderStatus.analyzing);
        expect(state.canListen, isFalse);
      });

      test('canSave is true when audioBytes is not null', () {
        final state = DecoderState(audioBytes: Uint8List(100));
        expect(state.canSave, isTrue);
      });

      test('canSave is false when audioBytes is null', () {
        const state = DecoderState();
        expect(state.canSave, isFalse);
      });

      test('canSave is true for mic recording result', () {
        final state = DecoderState(
          status: DecoderStatus.result,
          isFileAnalysis: false,
          audioBytes: Uint8List(100),
        );
        expect(state.canSave, isTrue);
      });

      test('canSave is true for file analysis result', () {
        final state = DecoderState(
          status: DecoderStatus.result,
          isFileAnalysis: true,
          audioBytes: Uint8List(100),
        );
        expect(state.canSave, isTrue);
      });

      test('canSave is true even when already saved (user may re-save)', () {
        final state = DecoderState(
          status: DecoderStatus.result,
          savedPath: '/path/to/file.wav',
          audioBytes: Uint8List(100),
        );
        expect(state.canSave, isTrue);
      });

      test('canShare is true when savedPath is not null', () {
        final state = DecoderState(savedPath: '/path/to/file.wav');
        expect(state.canShare, isTrue);
      });

      test('canShare is false when savedPath is null', () {
        const state = DecoderState(savedPath: null);
        expect(state.canShare, isFalse);
      });
    });

    group('DecoderEvent Types', () {
      test('DecoderListenRequested event exists', () {
        final event = DecoderListenRequested();
        expect(event, isNotNull);
      });

      test('DecoderStopRequested event exists', () {
        final event = DecoderStopRequested();
        expect(event, isNotNull);
      });

      test('DecoderSaveRequested event exists', () {
        final event = DecoderSaveRequested();
        expect(event, isNotNull);
      });

      test('DecoderShareRequested event exists', () {
        final event = DecoderShareRequested();
        expect(event, isNotNull);
      });

      test('DecoderFileAnalysisRequested event exists', () {
        final wavBytes = Uint8List(100);
        final event = DecoderFileAnalysisRequested(wavBytes, 'test.wav');
        expect(event, isNotNull);
        expect(event.wavBytes, equals(wavBytes));
        expect(event.filename, equals('test.wav'));
      });

      test('DecoderCleared event exists', () {
        final event = DecoderCleared();
        expect(event, isNotNull);
      });

      test('DecoderAudioPlayRequested event exists', () {
        final event = DecoderAudioPlayRequested();
        expect(event, isNotNull);
      });

      test('DecoderAudioStopRequested event exists', () {
        final event = DecoderAudioStopRequested();
        expect(event, isNotNull);
      });

      test('DecoderAudioPlaybackCompleted event exists', () {
        final event = DecoderAudioPlaybackCompleted();
        expect(event, isNotNull);
      });
    });

    group('isPlayingAudio', () {
      test('initial isPlayingAudio is false', () {
        const state = DecoderState();
        expect(state.isPlayingAudio, isFalse);
      });

      test('copyWith updates isPlayingAudio to true', () {
        const state = DecoderState();
        final updated = state.copyWith(isPlayingAudio: true);
        expect(updated.isPlayingAudio, isTrue);
      });

      test('copyWith updates isPlayingAudio to false', () {
        const state = DecoderState(isPlayingAudio: true);
        final updated = state.copyWith(isPlayingAudio: false);
        expect(updated.isPlayingAudio, isFalse);
      });

      test('copyWith preserves isPlayingAudio when not specified', () {
        const state = DecoderState(isPlayingAudio: true);
        final updated = state.copyWith(decodedText: 'SOS');
        expect(updated.isPlayingAudio, isTrue);
      });

      test('isPlayingAudio is independent of recording status', () {
        final state = DecoderState(
          status: DecoderStatus.listening,
          isPlayingAudio: true,
        );
        expect(state.isListening, isTrue);
        expect(state.isPlayingAudio, isTrue);
      });
    });

    group('recordingQuality', () {
      test('initial recordingQuality is 1.0 (HIGH)', () {
        const state = DecoderState();
        expect(state.recordingQuality, equals(1.0));
      });

      test('copyWith updates recordingQuality', () {
        const state = DecoderState();
        final updated = state.copyWith(recordingQuality: 0.5);
        expect(updated.recordingQuality, equals(0.5));
      });

      test('copyWith preserves recordingQuality when not specified', () {
        const state = DecoderState(recordingQuality: 0.7);
        final updated = state.copyWith(decodedText: 'SOS');
        expect(updated.recordingQuality, equals(0.7));
      });

      test('quality >= 1.0 is HIGH — badge should be hidden', () {
        const state = DecoderState(
          status: DecoderStatus.result,
          recordingQuality: 1.0,
        );
        // Badge is hidden when quality >= 1.0
        expect(state.hasResult && state.recordingQuality >= 1.0, isTrue);
      });

      test('quality 0.7 is MED boundary — badge visible', () {
        const state = DecoderState(
          status: DecoderStatus.result,
          recordingQuality: 0.7,
        );
        expect(state.hasResult && state.recordingQuality < 1.0, isTrue);
        // 0.7 is NOT low (threshold is < 0.7)
        expect(state.recordingQuality < 0.7, isFalse);
      });

      test('quality 0.8 is MED — badge visible, not low', () {
        const state = DecoderState(
          status: DecoderStatus.result,
          recordingQuality: 0.8,
        );
        expect(state.hasResult && state.recordingQuality < 1.0, isTrue);
        expect(state.recordingQuality < 0.7, isFalse);
      });

      test('quality 0.69 is LOW — just below threshold', () {
        const state = DecoderState(
          status: DecoderStatus.result,
          recordingQuality: 0.69,
        );
        expect(state.hasResult && state.recordingQuality < 1.0, isTrue);
        expect(state.recordingQuality < 0.7, isTrue);
      });

      test('quality 0.0 is LOW — worst quality', () {
        const state = DecoderState(
          status: DecoderStatus.result,
          recordingQuality: 0.0,
        );
        expect(state.recordingQuality < 0.7, isTrue);
      });

      test('badge not shown when status is not result even if quality is low', () {
        const state = DecoderState(
          status: DecoderStatus.idle,
          recordingQuality: 0.3,
        );
        // Badge only shows when hasResult AND quality < 1.0
        expect(state.hasResult, isFalse);
      });
    });

    group('Event handlers', () {
      late MockDecoderService svc;
      late MockPlayerService player;
      late DecoderBloc bloc;

      setUpAll(() {
        registerFallbackValue(Uint8List(0));
      });

      setUp(() {
        svc = MockDecoderService();
        player = MockPlayerService();
        stubDecoderServiceOk(svc);
        stubPlayerServiceOk(player);
        bloc = DecoderBloc(service: svc, player: player);
      });

      tearDown(() async {
        await bloc.close();
      });

      // ── Helper ──────────────────────────────────────────────────────────

      Future<List<DecoderState>> collectStates(
        Future<void> Function() act, {
        Duration wait = const Duration(milliseconds: 100),
      }) async {
        final states = <DecoderState>[];
        final sub = bloc.stream.listen(states.add);
        await act();
        await Future.delayed(wait);
        await sub.cancel();
        return states;
      }

      // ── DecoderListenRequested ──────────────────────────────────────────

      test('listen — permission granted → listening state', () async {
        final states = await collectStates(
          () async => bloc.add(DecoderListenRequested()),
        );
        expect(states.any((s) => s.status == DecoderStatus.listening), isTrue);
      });

      test('listen — permission denied → permissionDenied=true', () async {
        stubDecoderServiceOk(svc, permissionGranted: false);
        final states = await collectStates(
          () async => bloc.add(DecoderListenRequested()),
        );
        expect(states.last.permissionDenied, isTrue);
        expect(states.last.status, DecoderStatus.idle);
      });

      test('listen — stops active playback before opening mic', () async {
        // Seed the bloc with isPlayingAudio=true by going through AudioPlay.
        final wavBytes = makeMinimalWav(Uint8List(88200)); // ~1 s of silence
        when(() => svc.buildRecordingWav()).thenReturn(wavBytes);
        bloc.emit(bloc.state.copyWith(
          audioBytes: wavBytes,
          isPlayingAudio: true,
        ));
        await collectStates(() async => bloc.add(DecoderListenRequested()));
        verify(() => player.stopWav()).called(1);
      });

      test('listen — clears previous result text', () async {
        bloc.emit(bloc.state.copyWith(
          status: DecoderStatus.result,
          decodedText: 'OLD',
        ));
        final states = await collectStates(
          () async => bloc.add(DecoderListenRequested()),
        );
        final listeningState =
            states.firstWhere((s) => s.status == DecoderStatus.listening);
        expect(listeningState.decodedText, isEmpty);
      });

      // ── DecoderStopRequested ────────────────────────────────────────────

      test('stop — transitions analyzing → result with decoded text', () async {
        bloc.emit(bloc.state.copyWith(status: DecoderStatus.listening));
        final states = await collectStates(
          () async => bloc.add(DecoderStopRequested()),
        );
        expect(states.any((s) => s.status == DecoderStatus.analyzing), isTrue);
        final result =
            states.firstWhere((s) => s.status == DecoderStatus.result);
        expect(result.decodedText, 'SOS');
        expect(result.recordingQuality, 0.9);
      });

      test('stop — analyzeRecording throws → error state', () async {
        when(() => svc.analyzeRecording())
            .thenThrow(Exception('mic failed'));
        bloc.emit(bloc.state.copyWith(status: DecoderStatus.listening));
        final states = await collectStates(
          () async => bloc.add(DecoderStopRequested()),
        );
        final err =
            states.firstWhere((s) => s.errorMessage != null, orElse: () => bloc.state);
        expect(err.errorMessage, isNotNull);
      });

      // ── DecoderSaveRequested ────────────────────────────────────────────

      test('save — success → savedPath set in state', () async {
        final states = await collectStates(
          () async => bloc.add(DecoderSaveRequested()),
        );
        expect(states.last.savedPath, '/tmp/morse_test.wav');
      });

      test('save — service throws → errorMessage set', () async {
        when(() => svc.saveRecording(any()))
            .thenThrow(Exception('disk full'));
        final states = await collectStates(
          () async => bloc.add(DecoderSaveRequested()),
        );
        expect(states.last.errorMessage, isNotNull);
      });

      // ── DecoderShareRequested ───────────────────────────────────────────

      test('share — savedPath null → shareRecording not called', () async {
        await collectStates(() async => bloc.add(DecoderShareRequested()));
        verifyNever(() => svc.shareRecording(any()));
      });

      test('share — savedPath set → shareRecording called', () async {
        bloc.emit(bloc.state.copyWith(savedPath: '/tmp/morse_test.wav'));
        await collectStates(() async => bloc.add(DecoderShareRequested()));
        verify(() => svc.shareRecording('/tmp/morse_test.wav')).called(1);
      });

      // ── DecoderFileAnalysisRequested ────────────────────────────────────

      test('analyzeFile — valid bytes → result with decoded text', () async {
        final bytes = makeMinimalWav();
        final states = await collectStates(
          () async =>
              bloc.add(DecoderFileAnalysisRequested(bytes, 'test.wav')),
        );
        expect(states.any((s) => s.status == DecoderStatus.analyzing), isTrue);
        final result =
            states.firstWhere((s) => s.status == DecoderStatus.result);
        expect(result.decodedText, 'SOS');
        expect(result.isFileAnalysis, isTrue);
        expect(result.audioBytes, isNotNull);
      });

      test('analyzeFile — service throws → error state', () async {
        when(() => svc.analyzeWavFile(any()))
            .thenThrow(Exception('corrupt wav'));
        final bytes = makeMinimalWav();
        final states = await collectStates(
          () async =>
              bloc.add(DecoderFileAnalysisRequested(bytes, 'bad.wav')),
        );
        expect(states.last.errorMessage, isNotNull);
      });

      // ── DecoderCleared ──────────────────────────────────────────────────

      test('clear — resets to initial state', () async {
        bloc.emit(bloc.state.copyWith(
          status: DecoderStatus.result,
          decodedText: 'SOS',
        ));
        final states = await collectStates(
          () async => bloc.add(DecoderCleared()),
        );
        expect(states.last.status, DecoderStatus.idle);
        expect(states.last.decodedText, isEmpty);
      });

      test('clear — stops playback if audio was playing', () async {
        bloc.emit(bloc.state.copyWith(isPlayingAudio: true));
        await collectStates(() async => bloc.add(DecoderCleared()));
        verify(() => player.stopWav()).called(1);
      });

      // ── DecoderAudioPlayRequested ───────────────────────────────────────

      test('audioPlay — audioBytes null → no state change', () async {
        final states = await collectStates(
          () async => bloc.add(DecoderAudioPlayRequested()),
        );
        expect(states, isEmpty);
      });

      test('audioPlay — valid bytes → isPlayingAudio=true, playWav called',
          () async {
        final bytes = makeMinimalWav();
        bloc.emit(bloc.state.copyWith(audioBytes: bytes));
        final states = await collectStates(
          () async => bloc.add(DecoderAudioPlayRequested()),
        );
        expect(states.first.isPlayingAudio, isTrue);
        verify(() => player.playWav(bytes)).called(1);
      });

      // ── DecoderAudioStopRequested ───────────────────────────────────────

      test('audioStop → isPlayingAudio=false, stopWav called', () async {
        bloc.emit(bloc.state.copyWith(isPlayingAudio: true));
        final states = await collectStates(
          () async => bloc.add(DecoderAudioStopRequested()),
        );
        expect(states.last.isPlayingAudio, isFalse);
        verify(() => player.stopWav()).called(1);
      });

      // ── DecoderAudioPlaybackCompleted ───────────────────────────────────

      test('audioPlaybackCompleted → isPlayingAudio=false', () async {
        bloc.emit(bloc.state.copyWith(isPlayingAudio: true));
        final states = await collectStates(
          () async => bloc.add(DecoderAudioPlaybackCompleted()),
        );
        expect(states.last.isPlayingAudio, isFalse);
      });

      // ── _estimateDurationMs ─────────────────────────────────────────────

      test('estimateDurationMs — valid WAV header returns > 0', () async {
        // 88200 bytes of PCM data at 88200 byte/s = 1000 ms
        final bytes = makeMinimalWav(Uint8List(88200));
        bloc.emit(bloc.state.copyWith(audioBytes: bytes));
        final states = await collectStates(
          () async => bloc.add(DecoderAudioPlayRequested()),
          wait: const Duration(milliseconds: 1200),
        );
        // Playback completes naturally (timer fired): isPlayingAudio → false
        expect(states.last.isPlayingAudio, isFalse);
      });

      test('estimateDurationMs — short WAV (< 44 bytes) returns 0', () async {
        final shortBytes = Uint8List(10);
        bloc.emit(bloc.state.copyWith(audioBytes: shortBytes));
        final states = await collectStates(
          () async => bloc.add(DecoderAudioPlayRequested()),
        );
        // isPlayingAudio goes true but no completion timer fires (duration=0)
        expect(states.last.isPlayingAudio, isTrue);
      });
    });

    group('SignalSnapshot', () {
      test('SignalSnapshot has power field', () {
        final snapshot = SignalSnapshot(
          power: 100.0,
          noiseFloor: 10.0,
          isTone: true,
        );
        expect(snapshot.power, equals(100.0));
      });

      test('SignalSnapshot has noiseFloor field', () {
        final snapshot = SignalSnapshot(
          power: 100.0,
          noiseFloor: 10.0,
          isTone: true,
        );
        expect(snapshot.noiseFloor, equals(10.0));
      });

      test('SignalSnapshot has isTone field', () {
        final snapshot = SignalSnapshot(
          power: 100.0,
          noiseFloor: 10.0,
          isTone: true,
        );
        expect(snapshot.isTone, isTrue);
      });

      test('SignalSnapshot can be created with isTone false', () {
        final snapshot = SignalSnapshot(
          power: 100.0,
          noiseFloor: 10.0,
          isTone: false,
        );
        expect(snapshot.isTone, isFalse);
      });
    });
  });
}
