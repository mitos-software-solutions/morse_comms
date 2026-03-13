import 'dart:async';
import 'dart:typed_data';

import 'package:mocktail/mocktail.dart';
import 'package:morse_comms/features/decoder/data/decoder_service.dart';
import 'package:morse_comms/features/player/player_service.dart';

/// Mocktail mock for [DecoderService].
/// Does not instantiate any platform plugins.
class MockDecoderService extends Mock implements DecoderService {}

/// Mocktail mock for [PlayerService].
/// Does not instantiate SoLoud.
class MockPlayerService extends Mock implements PlayerService {}

// ── Minimal WAV bytes (44-byte header + 2 bytes of silence) ──────────────────

/// Returns a valid 16-bit mono 44100 Hz WAV with [pcmBytes] as payload.
/// Defaults to 2 bytes of silence so duration estimation returns > 0 ms.
Uint8List makeMinimalWav([Uint8List? pcmBytes]) {
  pcmBytes ??= Uint8List(2);
  final dataLen = pcmBytes.length;
  final header = ByteData(44);

  void setFourCC(int offset, int value) {
    header.setUint8(offset, (value >> 24) & 0xFF);
    header.setUint8(offset + 1, (value >> 16) & 0xFF);
    header.setUint8(offset + 2, (value >> 8) & 0xFF);
    header.setUint8(offset + 3, value & 0xFF);
  }

  setFourCC(0, 0x52494646); // 'RIFF'
  header.setUint32(4, 36 + dataLen, Endian.little);
  setFourCC(8, 0x57415645); // 'WAVE'
  setFourCC(12, 0x666d7420); // 'fmt '
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, 44100, Endian.little); // sample rate
  header.setUint32(28, 88200, Endian.little); // byte rate (44100 × 2)
  header.setUint16(32, 2, Endian.little); // block align
  header.setUint16(34, 16, Endian.little); // bits per sample
  setFourCC(36, 0x64617461); // 'data'
  header.setUint32(40, dataLen, Endian.little);

  final result = Uint8List(44 + dataLen);
  result.setAll(0, header.buffer.asUint8List());
  result.setAll(44, pcmBytes);
  return result;
}

// ── Stub helpers ──────────────────────────────────────────────────────────────

/// Stubs the standard "all-OK" behaviour on a [MockDecoderService].
void stubDecoderServiceOk(
  MockDecoderService svc, {
  bool permissionGranted = true,
  String decodeResult = 'SOS',
  double confidence = 0.9,
  String savedPath = '/tmp/morse_test.wav',
}) {
  when(() => svc.hasPermission()).thenAnswer((_) async => permissionGranted);
  when(() => svc.startListening()).thenAnswer((_) async {});
  when(() => svc.stopListening()).thenAnswer((_) async => 10);
  when(() => svc.analyzeRecording())
      .thenAnswer((_) async => (decodeResult, confidence));
  when(() => svc.analyzeWavFile(any()))
      .thenAnswer((_) async => (decodeResult, confidence));
  when(() => svc.saveRecording(any())).thenAnswer((_) async => savedPath);
  when(() => svc.shareRecording(any())).thenAnswer((_) async {});
  when(() => svc.buildRecordingWav()).thenReturn(makeMinimalWav());
  when(() => svc.signalStream).thenAnswer((_) => const Stream.empty());
  when(() => svc.dispose()).thenAnswer((_) async {});
}

/// Stubs a [MockPlayerService] with no-op playback methods.
void stubPlayerServiceOk(MockPlayerService player) {
  when(() => player.playWav(any())).thenAnswer((_) async {});
  when(() => player.stopWav()).thenAnswer((_) async {});
  when(() => player.dispose()).thenAnswer((_) async {});
}
