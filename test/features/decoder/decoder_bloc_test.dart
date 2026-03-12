import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/core/dsp/decoder_pipeline.dart';
import 'package:morse_comms/features/decoder/bloc/decoder_bloc.dart';

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

      test('canSave is true when result from mic recording with no save', () {
        final state = DecoderState(
          status: DecoderStatus.result,
          isFileAnalysis: false,
          savedPath: null,
        );
        expect(state.canSave, isTrue);
      });

      test('canSave is false when already saved', () {
        final state = DecoderState(
          status: DecoderStatus.result,
          isFileAnalysis: false,
          savedPath: '/path/to/file.wav',
        );
        expect(state.canSave, isFalse);
      });

      test('canSave is false when file analysis', () {
        final state = DecoderState(
          status: DecoderStatus.result,
          isFileAnalysis: true,
          savedPath: null,
        );
        expect(state.canSave, isFalse);
      });

      test('canSave is false when not result status', () {
        const state = DecoderState(
          status: DecoderStatus.idle,
          isFileAnalysis: false,
          savedPath: null,
        );
        expect(state.canSave, isFalse);
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
