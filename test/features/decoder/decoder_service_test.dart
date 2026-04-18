import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/features/decoder/data/decoder_service.dart';

// The `record` package calls `create` on its method channel when AudioRecorder
// is constructed. Register a no-op handler so tests don't need a real device.
void _setUpRecordChannelMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.llfbandit.record/messages'),
    (call) async => call.method == 'create' ? 0 : null,
  );
}

void _tearDownRecordChannelMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.llfbandit.record/messages'),
    null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DecoderService', () {
    late DecoderService svc;

    setUp(() {
      _setUpRecordChannelMock();
      svc = DecoderService();
    });

    tearDown(() async {
      await svc.dispose();
      _tearDownRecordChannelMock();
    });

    group('fresh instance state', () {
      test('recordedFrameCount is 0 before any recording', () {
        expect(svc.recordedFrameCount, 0);
      });

      test('buildRecordingWav returns empty Uint8List when nothing recorded', () {
        expect(svc.buildRecordingWav(), isEmpty);
      });

      test('analyzeRecording resolves to ("", 0.0) with no audio data',
          () async {
        final result = await svc.analyzeRecording();
        expect(result, equals(('', 0.0)));
      });

      test('signalStream is a broadcast stream', () {
        expect(svc.signalStream.isBroadcast, isTrue);
      });

      test('onSideTone is null when not provided', () {
        expect(svc.onSideTone, isNull);
      });
    });

    group('onSideTone callback', () {
      test('onSideTone is set when provided', () async {
        void cb(bool _) {}
        final svcWithCb = DecoderService(onSideTone: cb);
        expect(svcWithCb.onSideTone, isNotNull);
        await svcWithCb.dispose();
      });
    });

    group('SignalSnapshot', () {
      test('holds power, noiseFloor, and isTone correctly', () {
        final snapshot = SignalSnapshot(
          power: 100.0,
          noiseFloor: 10.0,
          isTone: true,
        );
        expect(snapshot.power, equals(100.0));
        expect(snapshot.noiseFloor, equals(10.0));
        expect(snapshot.isTone, isTrue);
      });

      test('isTone is false when power is below noise floor', () {
        final snapshot = SignalSnapshot(
          power: 5.0,
          noiseFloor: 10.0,
          isTone: false,
        );
        expect(snapshot.isTone, isFalse);
      });
    });
  });
}
