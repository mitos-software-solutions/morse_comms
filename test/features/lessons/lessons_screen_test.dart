import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:morse_comms/features/lessons/data/lesson_repository.dart';
import 'package:morse_comms/features/lessons/ui/lessons_screen.dart';
import 'package:morse_comms/features/player/player_service.dart';
import 'package:morse_comms/core/morse/morse_encoder.dart';
import 'package:morse_comms/features/settings/bloc/settings_cubit.dart';
import 'package:morse_comms/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLessonRepository implements LessonRepository {
  @override
  int unlockedCount = 1;

  @override
  int get farnsworthLevelIndex => 0;

  @override
  double? bestAccuracy(int level) => 0.95;

  @override
  Map<int, double> loadAllBestAccuracy() => {1: 0.95};

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

Widget _buildLessonsApp({
  required LessonRepository repo,
  required PlayerService player,
  required SettingsCubit settings,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<SettingsCubit>.value(value: settings),
    ],
    child: MultiRepositoryProvider(
      providers: [
        RepositoryProvider<LessonRepository>.value(value: repo),
        RepositoryProvider<PlayerService>.value(value: player),
      ],
      child: const MaterialApp(
        home: LessonsScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('LessonsScreen shows Learn Morse and method cards',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final player = _StubPlayerService();
    final settings = await _makeSettingsCubit();

    await tester.pumpWidget(
      _buildLessonsApp(repo: repo, player: player, settings: settings),
    );

    expect(find.text('Learn Morse'), findsOneWidget);
    expect(find.text('Koch Method'), findsOneWidget);
    expect(find.text('Farnsworth Method'), findsOneWidget);
  });

  testWidgets('LessonsScreen opens reference screen from app bar action',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final player = _StubPlayerService();
    final settings = await _makeSettingsCubit();

    await tester.pumpWidget(
      _buildLessonsApp(repo: repo, player: player, settings: settings),
    );

    // Tap the reference icon (menu_book_outlined).
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();

    // Reference screen title should be visible.
    expect(find.text('Morse Reference'), findsOneWidget);
  });

  testWidgets('LessonsScreen opens lessons info dialog',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final player = _StubPlayerService();
    final settings = await _makeSettingsCubit();

    await tester.pumpWidget(
      _buildLessonsApp(repo: repo, player: player, settings: settings),
    );

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    // Expect some content from lessons_info dialog to appear.
    expect(find.textContaining('Koch'), findsOneWidget);
  });
}

