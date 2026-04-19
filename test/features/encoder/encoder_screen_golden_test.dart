import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:morse_comms/core/morse/morse_encoder.dart';
import 'package:morse_comms/features/encoder/ui/encoder_screen.dart';
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
        home: const EncoderScreen(),
      ),
    ),
  );
}

void main() {
  group('EncoderScreen golden', () {
    testGoldens('idle state light theme', (tester) async {
      await tester.pumpWidgetBuilder(
        await _buildApp(),
        surfaceSize: const Size(400, 700),
      );
      await screenMatchesGolden(tester, 'encoder_screen_idle_light');
    });

    testGoldens('idle state dark theme', (tester) async {
      await tester.pumpWidgetBuilder(
        await _buildApp(dark: true),
        surfaceSize: const Size(400, 700),
      );
      await screenMatchesGolden(tester, 'encoder_screen_idle_dark');
    });

    testGoldens('SOS typed light theme', (tester) async {
      await tester.pumpWidgetBuilder(
        await _buildApp(),
        surfaceSize: const Size(400, 700),
      );
      await tester.enterText(find.byType(TextField).first, 'SOS');
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'encoder_screen_sos_light');
    });

    testGoldens('SOS typed dark theme', (tester) async {
      await tester.pumpWidgetBuilder(
        await _buildApp(dark: true),
        surfaceSize: const Size(400, 700),
      );
      await tester.enterText(find.byType(TextField).first, 'SOS');
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'encoder_screen_sos_dark');
    });
  });
}
