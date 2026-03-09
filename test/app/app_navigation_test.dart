import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/app/app.dart';
import 'package:morse_comms/core/morse/morse_encoder.dart';
import 'package:morse_comms/features/lessons/data/lesson_repository.dart';
import 'package:morse_comms/features/player/player_service.dart';
import 'package:morse_comms/features/settings/bloc/settings_cubit.dart';
import 'package:morse_comms/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubPlayerService extends PlayerService {
  bool playCalled = false;

  @override
  Future<void> play(
    List<MorseTone> tones, {
    int frequencyHz = 700,
    double volume = 0.7,
  }) async {
    playCalled = true;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _FakeLessonRepository implements LessonRepository {
  @override
  int unlockedCount = 1;

  @override
  int get farnsworthLevelIndex => 0;

  @override
  double? bestAccuracy(int level) => 0.9;

  @override
  Map<int, double> loadAllBestAccuracy() => {1: 0.9};

  @override
  Map<int, double> loadAllFarnsworthBestAccuracy() => {0: 0.9};

  @override
  double? farnsworthBestAccuracy(int levelIndex) => 0.9;

  @override
  Future<void> saveBestAccuracy(int level, double accuracy) async {}

  @override
  Future<void> saveFarnsworthBestAccuracy(
      int levelIndex, double accuracy) async {}

  @override
  Future<void> setUnlockedCount(int count) async {
    unlockedCount = count;
  }

  @override
  Future<void> setFarnsworthLevelIndex(int index) async {}
}

Future<SettingsCubit> _makeSettingsCubit() async {
  SharedPreferences.setMockInitialValues(const {});
  final sp = await SharedPreferences.getInstance();
  return SettingsCubit(SettingsRepository(sp));
}

Widget _buildApp({
  required PlayerService player,
  required LessonRepository lessons,
  required SettingsCubit settings,
}) {
  return MorseCommsApp(
    playerService: player,
    settingsCubit: settings,
    lessonRepository: lessons,
  );
}

void main() {
  testWidgets('App starts on Encoder tab',
      (WidgetTester tester) async {
    final player = _StubPlayerService();
    final lessons = _FakeLessonRepository();
    final settings = await _makeSettingsCubit();

    await tester.pumpWidget(_buildApp(
      player: player,
      lessons: lessons,
      settings: settings,
    ));
    await tester.pumpAndSettle();

    // Encoder screen app bar title should be visible by default.
    expect(find.text('Morse Encoder'), findsOneWidget);
    // Navigation bar should show Encoder as selected label.
    expect(find.text('Encoder'), findsOneWidget);
  });

  testWidgets('Bottom navigation switches between all main sections',
      (WidgetTester tester) async {
    final player = _StubPlayerService();
    final lessons = _FakeLessonRepository();
    final settings = await _makeSettingsCubit();

    await tester.pumpWidget(_buildApp(
      player: player,
      lessons: lessons,
      settings: settings,
    ));
    await tester.pumpAndSettle();

    // Go to Decoder tab.
    await tester.tap(find.text('Decoder'));
    await tester.pumpAndSettle();
    expect(find.text('Morse Decoder'), findsOneWidget);

    // Go to Learn tab.
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.text('Learn Morse'), findsOneWidget);

    // Go to Settings tab.
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    // App bar title for settings screen is "Settings".
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Settings'),
      ),
      findsOneWidget,
    );

    // Navigate back to Encoder.
    await tester.tap(find.text('Encoder'));
    await tester.pumpAndSettle();
    expect(find.text('Morse Encoder'), findsOneWidget);
  });
}

