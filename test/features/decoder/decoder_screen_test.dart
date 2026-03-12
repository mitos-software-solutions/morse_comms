import 'dart:typed_data';

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

  @override
  Future<void> playWav(Uint8List bytes) async {}

  @override
  Future<void> stopWav() async {}
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

  testWidgets('Audio toolbar is always present with expected controls',
      (WidgetTester tester) async {
    final settingsCubit = await _makeSettingsCubit();
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildTestApp(settingsCubit: settingsCubit, player: player),
    );
    await tester.pumpAndSettle();

    // Toolbar always shows these three controls.
    expect(find.byTooltip('New Recording'), findsOneWidget);
    expect(find.byTooltip('Load Example'), findsOneWidget);
    expect(find.byTooltip('Open Recording'), findsOneWidget);
  });

  testWidgets('Play and Save are hidden in toolbar when no audio exists',
      (WidgetTester tester) async {
    final settingsCubit = await _makeSettingsCubit();
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildTestApp(settingsCubit: settingsCubit, player: player),
    );
    await tester.pumpAndSettle();

    // Play and Save only appear once audioBytes is populated.
    expect(find.byTooltip('Play audio'), findsNothing);
    expect(find.byTooltip('Save'), findsNothing);
  });

  testWidgets('App bar has no action buttons — title only',
      (WidgetTester tester) async {
    final settingsCubit = await _makeSettingsCubit();
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildTestApp(settingsCubit: settingsCubit, player: player),
    );
    await tester.pumpAndSettle();

    // App bar title present.
    expect(find.text('Morse Decoder'), findsOneWidget);
    // Old app bar actions are gone.
    expect(find.byTooltip('New Recording').evaluate().length, equals(1));
  });

  testWidgets('Listen button label never says Record Again',
      (WidgetTester tester) async {
    final settingsCubit = await _makeSettingsCubit();
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildTestApp(settingsCubit: settingsCubit, player: player),
    );
    await tester.pumpAndSettle();

    expect(find.text('Record Again'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Listen'), findsOneWidget);
  });
}
