import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:morse_comms/core/morse/morse_encoder.dart';
import 'package:morse_comms/features/lessons/data/lesson_repository.dart';
import 'package:morse_comms/features/lessons/ui/lessons_screen.dart';
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
  final repo = LessonRepository(sp);
  final player = _StubPlayerService();

  return MultiBlocProvider(
    providers: [
      BlocProvider<SettingsCubit>.value(value: settings),
    ],
    child: MultiRepositoryProvider(
      providers: [
        RepositoryProvider<PlayerService>.value(value: player),
        RepositoryProvider<LessonRepository>.value(value: repo),
      ],
      child: MaterialApp(
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        debugShowCheckedModeBanner: false,
        home: const LessonsScreen(),
      ),
    ),
  );
}

void _setUpPackageInfoChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/package_info'),
    (call) async => {
      'appName': 'Morse Comms',
      'packageName': 'com.mitossoftwaresolutions.morsecomms',
      'version': '1.1.0',
      'buildNumber': '6',
      'buildSignature': '',
      'installerStore': null,
    },
  );
}

void _tearDownPackageInfoChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/package_info'),
    null,
  );
}

void main() {
  setUpAll(_setUpPackageInfoChannel);
  tearDownAll(_tearDownPackageInfoChannel);

  group('LessonsScreen golden', () {
    testGoldens('idle state light theme', (tester) async {
      await tester.pumpWidgetBuilder(
        await _buildApp(),
        surfaceSize: const Size(400, 700),
      );
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'lessons_screen_idle_light');
    });

    testGoldens('idle state dark theme', (tester) async {
      await tester.pumpWidgetBuilder(
        await _buildApp(dark: true),
        surfaceSize: const Size(400, 700),
      );
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'lessons_screen_idle_dark');
    });
  });
}
