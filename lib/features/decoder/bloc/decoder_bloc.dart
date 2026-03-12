import 'dart:async';
import 'dart:typed_data'; // ignore: depend_on_referenced_packages

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/decoder_service.dart';

part 'decoder_event.dart';
part 'decoder_state.dart';

class DecoderBloc extends Bloc<DecoderEvent, DecoderState> {
  final DecoderService _service;

  Timer? _recordingTimer;
  StreamSubscription<SignalSnapshot>? _signalSub;

  // Holds the WAV bytes for the current session, bridging the gap between
  // _onAnalyzeFile (bytes arrive) and _onAnalysisCompleted (result emitted).
  Uint8List? _pendingAudioBytes;

  DecoderBloc({required DecoderService service})
      : _service = service,
        super(const DecoderState()) {
    on<DecoderListenRequested>(_onListen);
    on<DecoderStopRequested>(_onStop);
    on<DecoderSaveRequested>(_onSave);
    on<DecoderShareRequested>(_onShare);
    on<DecoderFileAnalysisRequested>(_onAnalyzeFile);
    on<DecoderCleared>(_onClear);
    on<_TimerTick>(_onTimerTick);
    on<_SignalUpdated>(_onSignalUpdated);
    on<_AnalysisCompleted>(_onAnalysisCompleted);
    on<_SaveCompleted>(_onSaveCompleted);
    on<_ErrorOccurred>(_onError);
  }

  // ── Listen ────────────────────────────────────────────────────────────────

  Future<void> _onListen(
    DecoderListenRequested event,
    Emitter<DecoderState> emit,
  ) async {
    final permitted = await _service.hasPermission();
    if (!permitted) {
      emit(state.copyWith(permissionDenied: true));
      return;
    }

    _pendingAudioBytes = null;
    emit(state.copyWith(
      status: DecoderStatus.listening,
      decodedText: '',
      recordingSeconds: 0,
      permissionDenied: false,
      isFileAnalysis: false,
      clearSignal: true,
      clearError: true,
      clearSavedPath: true,
      clearAudioBytes: true,
    ));

    _signalSub = _service.signalStream
        .listen((snap) => add(_SignalUpdated(snap)));

    _recordingTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(_TimerTick()),
    );

    await _service.startListening();
  }

  // ── Stop → Analyze ────────────────────────────────────────────────────────

  Future<void> _onStop(
    DecoderStopRequested event,
    Emitter<DecoderState> emit,
  ) async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _signalSub?.cancel();
    _signalSub = null;

    await _service.stopListening();

    emit(state.copyWith(status: DecoderStatus.analyzing, clearSignal: true));

    try {
      final (text, confidence) = await _service.analyzeRecording();
      add(_AnalysisCompleted(text, confidence));
    } catch (e) {
      add(_ErrorOccurred(e.toString()));
    }
  }

  // ── Save → Share ──────────────────────────────────────────────────────────

  Future<void> _onSave(
    DecoderSaveRequested event,
    Emitter<DecoderState> emit,
  ) async {
    final now = DateTime.now();
    final filename =
        'morse_${now.year}${_pad(now.month)}${_pad(now.day)}'
        '_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    try {
      final savedPath = await _service.saveRecording(filename);
      add(_SaveCompleted(savedPath));
    } catch (e) {
      add(_ErrorOccurred(e.toString()));
    }
  }

  // ── Re-share (share icon in the saved chip) ───────────────────────────────

  Future<void> _onShare(
    DecoderShareRequested event,
    Emitter<DecoderState> emit,
  ) async {
    final path = state.savedPath;
    if (path == null) return;
    try {
      await _service.shareRecording(path);
    } catch (e) {
      add(_ErrorOccurred(e.toString()));
    }
  }

  // ── Analyze file ──────────────────────────────────────────────────────────

  Future<void> _onAnalyzeFile(
    DecoderFileAnalysisRequested event,
    Emitter<DecoderState> emit,
  ) async {
    _pendingAudioBytes = event.wavBytes;
    emit(state.copyWith(
      status: DecoderStatus.analyzing,
      decodedText: '',
      isFileAnalysis: true,
      clearError: true,
      clearSavedPath: true,
      clearSignal: true,
      clearAudioBytes: true,
    ));
    try {
      final (text, confidence) = await _service.analyzeWavFile(event.wavBytes);
      add(_AnalysisCompleted(text, confidence));
    } catch (e) {
      add(_ErrorOccurred(e.toString()));
    }
  }

  // ── Clear ─────────────────────────────────────────────────────────────────

  void _onClear(DecoderCleared event, Emitter<DecoderState> emit) {
    emit(const DecoderState());
  }

  // ── Internal event handlers ───────────────────────────────────────────────

  void _onTimerTick(_TimerTick event, Emitter<DecoderState> emit) {
    emit(state.copyWith(recordingSeconds: state.recordingSeconds + 1));
  }

  void _onSignalUpdated(_SignalUpdated event, Emitter<DecoderState> emit) {
    emit(state.copyWith(signalSnapshot: event.snapshot));
  }

  void _onAnalysisCompleted(
    _AnalysisCompleted event,
    Emitter<DecoderState> emit,
  ) {
    // For file analysis: bytes were stashed in _pendingAudioBytes.
    // For mic recording: build WAV from the accumulated PCM buffer.
    final audioBytes = state.isFileAnalysis
        ? _pendingAudioBytes
        : _service.buildRecordingWav();
    _pendingAudioBytes = null;
    emit(state.copyWith(
      status: DecoderStatus.result,
      decodedText: event.text,
      audioBytes: audioBytes,
      recordingQuality: event.confidence,
    ));
  }

  void _onSaveCompleted(_SaveCompleted event, Emitter<DecoderState> emit) {
    emit(state.copyWith(savedPath: event.path));
  }

  void _onError(_ErrorOccurred event, Emitter<DecoderState> emit) {
    emit(state.copyWith(
      status: DecoderStatus.result,
      errorMessage: event.message,
    ));
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  Future<void> close() async {
    _recordingTimer?.cancel();
    await _signalSub?.cancel();
    await _service.dispose();
    return super.close();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
