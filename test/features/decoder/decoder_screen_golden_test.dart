import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:morse_comms/core/morse/morse_encoder.dart';
import 'package:morse_comms/features/decoder/bloc/decoder_bloc.dart';
import 'package:morse_comms/features/decoder/ui/decoder_screen.dart';
import 'package:morse_comms/features/player/player_service.dart';
import 'package:morse_comms/features/settings/bloc/settings_cubit.dart';
import 'package:morse_comms/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubPlayerService extends PlayerService {
  @override
  Future<void> play(List<MorseTone> tones,
      {int frequencyHz = 700, double volume = 0.7}) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> startTone({int frequencyHz = 700}) async {}
  @override
  Future<void> stopTone() async {}
  @override
  Future<void> playWav(Uint8List bytes) async {}
  @override
  Future<void> stopWav() async {}
  @override
  Future<void> dispose() async {}
}

Future<Widget> _buildApp({bool dark = false}) async {
  SharedPreferences.setMockInitialValues(const {});
  final sp = await SharedPreferences.getInstance();
  final settings = SettingsCubit(SettingsRepository(sp));
  final player = _StubPlayerService();

  return BlocProvider<SettingsCubit>.value(
    value: settings,
    child: RepositoryProvider<PlayerService>.value(
      value: player,
      child: MaterialApp(
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        debugShowCheckedModeBanner: false,
        home: const DecoderScreen(),
      ),
    ),
  );
}

DecoderBloc _bloc(WidgetTester tester) =>
    tester.element(find.byType(FilledButton).first).read<DecoderBloc>();

void _setUpRecordChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.llfbandit.record/messages'),
    (call) async => call.method == 'create' ? 0 : null,
  );
}

void _tearDownRecordChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.llfbandit.record/messages'),
    null,
  );
}

void main() {
  setUpAll(_setUpRecordChannel);
  tearDownAll(_tearDownRecordChannel);

  group('DecoderScreen golden', () {
    testGoldens('idle state light theme', (tester) async {
      await tester.pumpWidgetBuilder(
        await _buildApp(),
        surfaceSize: const Size(400, 700),
      );
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'decoder_screen_idle_light');
    });

    testGoldens('idle state dark theme', (tester) async {
      await tester.pumpWidgetBuilder(
        await _buildApp(dark: true),
        surfaceSize: const Size(400, 700),
      );
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'decoder_screen_idle_dark');
    });

    testGoldens('result state with SOS light theme', (tester) async {
      await tester.pumpWidgetBuilder(
        await _buildApp(),
        surfaceSize: const Size(400, 700),
      );
      await tester.pumpAndSettle();
      _bloc(tester).emit(DecoderState(
        status: DecoderStatus.result,
        decodedText: 'SOS',
        audioBytes: Uint8List(0),
        recordingQuality: 1.0,
      ));
      await tester.pump();
      await tester.pump();
      await screenMatchesGolden(tester, 'decoder_screen_result_light');
    });

    testGoldens('result state with SOS dark theme', (tester) async {
      await tester.pumpWidgetBuilder(
        await _buildApp(dark: true),
        surfaceSize: const Size(400, 700),
      );
      await tester.pumpAndSettle();
      _bloc(tester).emit(DecoderState(
        status: DecoderStatus.result,
        decodedText: 'SOS',
        audioBytes: Uint8List(0),
        recordingQuality: 1.0,
      ));
      await tester.pump();
      await tester.pump();
      await screenMatchesGolden(tester, 'decoder_screen_result_dark');
    });
  });
}
