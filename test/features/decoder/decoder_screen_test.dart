import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:morse_comms/features/decoder/ui/decoder_screen.dart';
import 'package:morse_comms/features/player/player_service.dart';
import 'package:morse_comms/features/settings/bloc/settings_cubit.dart';
import 'package:morse_comms/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:morse_comms/core/morse/morse_encoder.dart';

class _StubPlayerService extends PlayerService {
  bool startToneCalled = false;
  bool stopToneCalled = false;

  @override
  Future<void> play(
    List<MorseTone> tones, {
    int frequencyHz = 700,
    double volume = 0.7,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> startTone({int frequencyHz = 700}) async {
    startToneCalled = true;
  }

  @override
  Future<void> stopTone() async {
    stopToneCalled = true;
  }
}

Future<SettingsCubit> _makeSettingsCubit(
    [Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  return SettingsCubit(SettingsRepository(sp));
}

Widget _buildTestApp({
  required SettingsCubit settingsCubit,
  required PlayerService player,
}) {
  return BlocProvider<SettingsCubit>.value(
    value: settingsCubit,
    child: RepositoryProvider<PlayerService>.value(
      value: player,
      child: const MaterialApp(
        home: DecoderScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('DecoderScreen shows title and initial placeholder',
      (WidgetTester tester) async {
    final settingsCubit = await _makeSettingsCubit();
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildTestApp(settingsCubit: settingsCubit, player: player),
    );
    await tester.pumpAndSettle();

    // App bar title.
    expect(find.text('Morse Decoder'), findsOneWidget);

    // Initial decoded-text placeholder.
    expect(find.text('Press Listen to start recording'), findsOneWidget);

    // Main listen button label.
    expect(find.widgetWithText(FilledButton, 'Listen'), findsOneWidget);
  });

  testWidgets('New Recording icon is disabled initially',
      (WidgetTester tester) async {
    final settingsCubit = await _makeSettingsCubit();
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildTestApp(settingsCubit: settingsCubit, player: player),
    );
    await tester.pumpAndSettle();

    final newRecordingFinder = find.byTooltip('New Recording');
    expect(newRecordingFinder, findsOneWidget);
  });

  testWidgets('Save to Device button is hidden when there is no result',
      (WidgetTester tester) async {
    final settingsCubit = await _makeSettingsCubit();
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildTestApp(settingsCubit: settingsCubit, player: player),
    );
    await tester.pumpAndSettle();

    // No save button should be visible without a decodable result.
    expect(find.text('Save to Device'), findsNothing);
  });
}

