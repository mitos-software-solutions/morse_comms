import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:morse_comms/core/dsp/decoder_pipeline.dart';
import 'package:morse_comms/features/decoder/bloc/decoder_bloc.dart';
import 'package:morse_comms/features/decoder/ui/decoder_screen.dart';
import 'package:morse_comms/features/player/player_service.dart';
import 'package:morse_comms/features/settings/bloc/settings_cubit.dart';
import 'package:morse_comms/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:morse_comms/core/morse/morse_encoder.dart';

import '../../helpers/fake_services.dart';

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

  // ── State-driven UI tests ───────────────────────────────────────────────────

  DecoderBloc bloc(WidgetTester tester) =>
      tester.element(find.byType(FilledButton).first).read<DecoderBloc>();

  group('state-driven UI', () {
  late SettingsCubit settingsCubit;
  late _StubPlayerService player;

  setUp(() async {
    settingsCubit = await _makeSettingsCubit();
    player = _StubPlayerService();
  });

  // ── Listening state ─────────────────────────────────────────────────────

  testWidgets('listening state — Stop button shown', (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    bloc(tester).emit(const DecoderState(
      status: DecoderStatus.listening,
      recordingSeconds: 3,
    ));
    await tester.pump();
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Stop'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Listen'), findsNothing);
  });

  testWidgets('listening state — recording header with timer visible',
      (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    bloc(tester).emit(const DecoderState(
      status: DecoderStatus.listening,
      recordingSeconds: 65,
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Recording  1:05'), findsOneWidget);
  });

  testWidgets('listening state — signal meter shown with snapshot',
      (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    bloc(tester).emit(DecoderState(
      status: DecoderStatus.listening,
      signalSnapshot:
          SignalSnapshot(power: 500.0, noiseFloor: 100.0, isTone: true),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('TONE'), findsOneWidget);
  });

  testWidgets('listening state — signal meter shows silence', (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    bloc(tester).emit(DecoderState(
      status: DecoderStatus.listening,
      signalSnapshot:
          SignalSnapshot(power: 10.0, noiseFloor: 100.0, isTone: false),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('silence'), findsOneWidget);
  });

  // ── Analyzing state ─────────────────────────────────────────────────────

  testWidgets('analyzing state — spinner and Analyzing… label shown',
      (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    bloc(tester)
        .emit(const DecoderState(status: DecoderStatus.analyzing));
    await tester.pump();
    await tester.pump();

    expect(find.text('Analyzing…'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('analyzing state — button is disabled', (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    bloc(tester)
        .emit(const DecoderState(status: DecoderStatus.analyzing));
    await tester.pump();
    await tester.pump();

    final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Analyzing…'));
    expect(btn.onPressed, isNull);
  });

  // ── Result state ────────────────────────────────────────────────────────

  testWidgets('result state — decoded text displayed', (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    bloc(tester).emit(const DecoderState(
      status: DecoderStatus.result,
      decodedText: 'HELLO WORLD',
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('HELLO WORLD'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Listen'), findsOneWidget);
  });

  testWidgets('result state — empty text shows no-morse placeholder',
      (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    bloc(tester).emit(const DecoderState(
      status: DecoderStatus.result,
      decodedText: '',
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('No Morse detected'), findsOneWidget);
  });

  testWidgets('result state — Play and Save shown when audioBytes present',
      (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    bloc(tester).emit(DecoderState(
      status: DecoderStatus.result,
      decodedText: 'SOS',
      audioBytes: makeMinimalWav(),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byTooltip('Play audio'), findsOneWidget);
    expect(find.byTooltip('Save'), findsOneWidget);
  });

  testWidgets('result state — Play button icon toggles when playing',
      (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    final wav = makeMinimalWav();
    bloc(tester).emit(DecoderState(
      status: DecoderStatus.result,
      decodedText: 'SOS',
      audioBytes: wav,
      isPlayingAudio: true,
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byTooltip('Stop playback'), findsOneWidget);
    expect(find.byTooltip('Play audio'), findsNothing);
  });

  // ── Quality badge ───────────────────────────────────────────────────────

  testWidgets('result state — MED quality badge shown (0.8)', (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    bloc(tester).emit(const DecoderState(
      status: DecoderStatus.result,
      decodedText: 'SOS',
      recordingQuality: 0.8,
    ));
    await tester.pump();
    await tester.pump();

    expect(
        find.text(
            'Recording quality: fair — some segments were unclear'),
        findsOneWidget);
  });

  testWidgets('result state — LOW quality badge shown (0.5)', (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    bloc(tester).emit(const DecoderState(
      status: DecoderStatus.result,
      decodedText: 'SOS',
      recordingQuality: 0.5,
    ));
    await tester.pump();
    await tester.pump();

    expect(
        find.text(
            'Recording quality: poor — output may be approximate'),
        findsOneWidget);
  });

  testWidgets('result state — HIGH quality (1.0) shows no badge',
      (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    bloc(tester).emit(const DecoderState(
      status: DecoderStatus.result,
      decodedText: 'SOS',
      recordingQuality: 1.0,
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Recording quality: fair — some segments were unclear'),
        findsNothing);
    expect(find.text('Recording quality: poor — output may be approximate'),
        findsNothing);
  });

  // ── Banners ─────────────────────────────────────────────────────────────

  testWidgets('permission denied banner shown', (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    bloc(tester).emit(const DecoderState(permissionDenied: true));
    await tester.pump();
    await tester.pump();

    expect(find.text('Microphone permission denied. '
        'Grant it in Settings → Apps → morse_comms.'), findsOneWidget);
  });

  testWidgets('error banner shown when errorMessage set', (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    bloc(tester).emit(const DecoderState(
      status: DecoderStatus.result,
      errorMessage: 'mic failed',
    ));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Error: mic failed'), findsOneWidget);
  });

  // ── Saved chip ──────────────────────────────────────────────────────────

  testWidgets('saved chip shown with filename after save', (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    bloc(tester).emit(const DecoderState(
      status: DecoderStatus.result,
      decodedText: 'SOS',
      savedPath: '/tmp/morse_20260313_120000.wav',
    ));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('morse_20260313_120000.wav'), findsOneWidget);
    expect(find.byTooltip('Share'), findsOneWidget);
  });

  // ── Toolbar Reset button ────────────────────────────────────────────────

  testWidgets('Reset button disabled when no result', (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    final btn = tester.widget<IconButton>(
      find
          .ancestor(
            of: find.byTooltip('New Recording'),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(btn.onPressed, isNull);
  });

  testWidgets('Reset button enabled when result exists', (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    bloc(tester).emit(const DecoderState(
      status: DecoderStatus.result,
      decodedText: 'SOS',
    ));
    await tester.pump();
    await tester.pump();

    final btn = tester.widget<IconButton>(
      find
          .ancestor(
            of: find.byTooltip('New Recording'),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('tapping Reset dispatches DecoderCleared', (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    final decoderBloc = bloc(tester);
    decoderBloc.emit(const DecoderState(
        status: DecoderStatus.result, decodedText: 'SOS'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('New Recording'));
    await tester.pump();
    await tester.pump();

    expect(decoderBloc.state.status, DecoderStatus.idle);
  });

  // ── Placeholder text coverage ───────────────────────────────────────────

  testWidgets('placeholder text is correct for analyzing state',
      (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    bloc(tester).emit(const DecoderState(status: DecoderStatus.analyzing));
    await tester.pump();
    await tester.pump();

    expect(find.text('Analyzing…'), findsWidgets);
  });

  testWidgets('placeholder text is correct for listening state',
      (tester) async {
    await tester.pumpWidget(
        _buildTestApp(settingsCubit: settingsCubit, player: player));
    await tester.pumpAndSettle();

    bloc(tester).emit(const DecoderState(status: DecoderStatus.listening));
    await tester.pump();
    await tester.pump();

    expect(
        find.text('Recording… press Stop when done'), findsOneWidget);
  });
  }); // state-driven UI
} // main
