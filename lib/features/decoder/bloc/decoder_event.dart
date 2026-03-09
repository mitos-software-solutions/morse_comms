part of 'decoder_bloc.dart';

sealed class DecoderEvent {}

/// User pressed the Listen button — start recording.
final class DecoderListenRequested extends DecoderEvent {}

/// User pressed Stop — stop recording and trigger offline analysis.
final class DecoderStopRequested extends DecoderEvent {}

/// User pressed Save Recording.
final class DecoderSaveRequested extends DecoderEvent {}

/// User pressed Share — export the saved WAV via the platform share sheet.
final class DecoderShareRequested extends DecoderEvent {}

/// User opened a WAV file from storage; bytes are ready for analysis.
final class DecoderFileAnalysisRequested extends DecoderEvent {
  final Uint8List wavBytes;
  final String filename;
  DecoderFileAnalysisRequested(this.wavBytes, this.filename);
}

/// User pressed Clear / New Recording — return to idle.
final class DecoderCleared extends DecoderEvent {}

// ── Internal events ───────────────────────────────────────────────────────────

/// Recording timer tick (fired every second while listening).
final class _TimerTick extends DecoderEvent {}

/// New signal snapshot from the mic (for the live signal meter).
final class _SignalUpdated extends DecoderEvent {
  final SignalSnapshot snapshot;
  _SignalUpdated(this.snapshot);
}

/// Offline analysis completed; carries the decoded text.
final class _AnalysisCompleted extends DecoderEvent {
  final String text;
  _AnalysisCompleted(this.text);
}

/// WAV file saved successfully; carries the full file path.
final class _SaveCompleted extends DecoderEvent {
  final String path;
  _SaveCompleted(this.path);
}

/// An error occurred during recording, analysis, or save.
final class _ErrorOccurred extends DecoderEvent {
  final String message;
  _ErrorOccurred(this.message);
}
