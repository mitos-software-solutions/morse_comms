import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:morse_comms/core/morse/morse_encoder.dart';
import 'package:morse_comms/features/encoder/ui/encoder_screen.dart';
import 'package:morse_comms/features/player/player_service.dart';
import 'package:morse_comms/features/settings/bloc/settings_cubit.dart';
import 'package:morse_comms/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple stub PlayerService for widget tests – avoids touching real audio.
class _StubPlayerService extends PlayerService {
  bool playCalled = false;
  bool stopCalled = false;

  @override
  Future<void> play(
    List<MorseTone> tones, {
    int frequencyHz = 700,
    double volume = 0.7,
  }) async {
    playCalled = true;
  }

  @override
  Future<void> stop() async {
    stopCalled = true;
  }

  @override
  Future<void> dispose() async {}
}

Future<SettingsCubit> _makeSettingsCubit() async {
  SharedPreferences.setMockInitialValues(const {});
  final sp = await SharedPreferences.getInstance();
  return SettingsCubit(SettingsRepository(sp));
}

Widget _buildTestApp({
  required SettingsCubit settingsCubit,
  required PlayerService player,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<SettingsCubit>.value(value: settingsCubit),
    ],
    child: RepositoryProvider<PlayerService>.value(
      value: player,
      child: const MaterialApp(
        home: EncoderScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('EncoderScreen shows title and input field',
      (WidgetTester tester) async {
    final settingsCubit = await _makeSettingsCubit();
    final player = _StubPlayerService();

    await tester.pumpWidget(_buildTestApp(
      settingsCubit: settingsCubit,
      player: player,
    ));

    expect(find.text('Morse Encoder'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Enter text'), findsOneWidget);
  });

  testWidgets('typing SOS shows Morse output on EncoderScreen',
      (WidgetTester tester) async {
    final settingsCubit = await _makeSettingsCubit();
    final player = _StubPlayerService();

    await tester.pumpWidget(_buildTestApp(
      settingsCubit: settingsCubit,
      player: player,
    ));

    // Enter SOS into the text field.
    await tester.enterText(find.byType(TextField), 'SOS');
    await tester.pumpAndSettle();

    // Expect Morse output to appear.
    expect(find.text('... --- ...'), findsOneWidget);
  });

  testWidgets('Play button is disabled with no input and enabled after typing',
      (WidgetTester tester) async {
    final settingsCubit = await _makeSettingsCubit();
    final player = _StubPlayerService();

    await tester.pumpWidget(_buildTestApp(
      settingsCubit: settingsCubit,
      player: player,
    ));

    final playButtonFinder = find.widgetWithText(FilledButton, 'Play');
    expect(playButtonFinder, findsOneWidget);

    // Initially disabled when there is no Morse output.
    final initialButton =
        tester.widget<FilledButton>(playButtonFinder);
    expect(initialButton.onPressed, isNull);

    // After typing text, button becomes enabled.
    await tester.enterText(find.byType(TextField), 'K');
    await tester.pumpAndSettle();

    final updatedButton =
        tester.widget<FilledButton>(playButtonFinder);
    expect(updatedButton.onPressed, isNotNull);
  });

  testWidgets('tapping Play calls PlayerService.play',
      (WidgetTester tester) async {
    final settingsCubit = await _makeSettingsCubit();
    final player = _StubPlayerService();

    await tester.pumpWidget(_buildTestApp(
      settingsCubit: settingsCubit,
      player: player,
    ));

    await tester.enterText(find.byType(TextField), 'K');
    await tester.pumpAndSettle();

    // Tap Play.
    await tester.tap(find.widgetWithText(FilledButton, 'Play'));
    await tester.pumpAndSettle();

    expect(player.playCalled, isTrue);
  });

  testWidgets('Recognised text card shows placeholder when empty',
      (WidgetTester tester) async {
    final settingsCubit = await _makeSettingsCubit();
    final player = _StubPlayerService();

    await tester.pumpWidget(_buildTestApp(
      settingsCubit: settingsCubit,
      player: player,
    ));

    expect(find.text('Recognised text'), findsOneWidget);
    expect(find.text('— recognised text —'), findsOneWidget);
  });

  testWidgets('Recognised text card shows transliteration details',
      (WidgetTester tester) async {
    final settingsCubit = await _makeSettingsCubit();
    final player = _StubPlayerService();

    await tester.pumpWidget(_buildTestApp(
      settingsCubit: settingsCubit,
      player: player,
    ));

    // Enter text with diacritics that will be transliterated.
    await tester.enterText(find.byType(TextField), 'héllo');
    await tester.pumpAndSettle();

    // Transliterated text appears in the secondary line.
    expect(find.text('HELLO'), findsOneWidget);
    // Explanatory caption is shown.
    expect(
      find.text('Transliterated to Latin for Morse encoding'),
      findsOneWidget,
    );
  });

  testWidgets('Morse output card shows placeholder then Morse',
      (WidgetTester tester) async {
    final settingsCubit = await _makeSettingsCubit();
    final player = _StubPlayerService();

    await tester.pumpWidget(_buildTestApp(
      settingsCubit: settingsCubit,
      player: player,
    ));

    // Initially shows placeholder text.
    expect(find.text('— morse output —'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'SOS');
    await tester.pumpAndSettle();

    expect(find.text('— morse output —'), findsNothing);
    expect(find.text('... --- ...'), findsOneWidget);
  });
}

