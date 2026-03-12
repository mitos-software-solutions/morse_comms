part of 'decoder_bloc.dart';

/// Overall phase of the decoder feature.
enum DecoderStatus {
  /// Nothing recorded yet — show Listen button.
  idle,

  /// Mic is open and audio is being buffered.
  listening,

  /// Recording stopped; offline analysis is running.
  analyzing,

  /// Analysis complete; decoded text is available.
  result,
}

final class DecoderState {
  final DecoderStatus status;

  /// Decoded text produced by offline analysis.
  final String decodedText;

  /// True when the mic permission was denied.
  final bool permissionDenied;

  /// Seconds elapsed since recording started (increments ~every second).
  final int recordingSeconds;

  /// Most recent signal snapshot for the live meter (null when not listening).
  final SignalSnapshot? signalSnapshot;

  /// Full path of the saved WAV file, set after a successful save.
  final String? savedPath;

  /// Non-null when something went wrong.
  final String? errorMessage;

  /// True when the result comes from a user-opened file (not a mic recording).
  /// Hides the Save button since the audio is already on disk.
  final bool isFileAnalysis;

  /// Raw WAV bytes of the current audio (predefined example, user file, or
  /// mic recording). Non-null once analysis completes; used for preview playback.
  final Uint8List? audioBytes;

  /// Recording quality confidence [0.0–1.0] from the offline analyzer.
  /// 1.0 = HIGH (not shown), 0.7 = MED (subtle badge), below 0.7 = LOW (prominent badge).
  final double recordingQuality;

  const DecoderState({
    this.status = DecoderStatus.idle,
    this.decodedText = '',
    this.permissionDenied = false,
    this.recordingSeconds = 0,
    this.signalSnapshot,
    this.savedPath,
    this.errorMessage,
    this.isFileAnalysis = false,
    this.audioBytes,
    this.recordingQuality = 1.0,
  });

  bool get isListening => status == DecoderStatus.listening;
  bool get isAnalyzing => status == DecoderStatus.analyzing;
  bool get hasResult => status == DecoderStatus.result;

  /// Listen button is enabled when idle or after a result (new recording).
  bool get canListen =>
      status == DecoderStatus.idle || status == DecoderStatus.result;

  /// Save button is enabled when there is a result from a mic recording and no save yet.
  bool get canSave =>
      status == DecoderStatus.result && savedPath == null && !isFileAnalysis;

  /// Share button is enabled once a file has been saved internally.
  bool get canShare => savedPath != null;

  DecoderState copyWith({
    DecoderStatus? status,
    String? decodedText,
    bool? permissionDenied,
    int? recordingSeconds,
    SignalSnapshot? signalSnapshot,
    String? savedPath,
    String? errorMessage,
    bool? isFileAnalysis,
    Uint8List? audioBytes,
    double? recordingQuality,
    bool clearSignal = false,
    bool clearError = false,
    bool clearSavedPath = false,
    bool clearAudioBytes = false,
  }) =>
      DecoderState(
        status: status ?? this.status,
        decodedText: decodedText ?? this.decodedText,
        permissionDenied: permissionDenied ?? this.permissionDenied,
        recordingSeconds: recordingSeconds ?? this.recordingSeconds,
        signalSnapshot: clearSignal ? null : (signalSnapshot ?? this.signalSnapshot),
        savedPath: clearSavedPath ? null : (savedPath ?? this.savedPath),
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        isFileAnalysis: isFileAnalysis ?? this.isFileAnalysis,
        audioBytes: clearAudioBytes ? null : (audioBytes ?? this.audioBytes),
        recordingQuality: recordingQuality ?? this.recordingQuality,
      );
}
