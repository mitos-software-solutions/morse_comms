import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:morse_comms/features/lessons/data/lesson_repository.dart';
import 'package:morse_comms/features/lessons/ui/farnsworth_lessons_screen.dart';
import 'package:morse_comms/features/player/player_service.dart';
import 'package:morse_comms/core/morse/morse_encoder.dart';
import 'package:morse_comms/features/settings/bloc/settings_cubit.dart';
import 'package:morse_comms/features/settings/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLessonRepository implements LessonRepository {
  @override
  int unlockedCount = 2;

  @override
  int farnsworthLevelIndex = 1;

  @override
  double? bestAccuracy(int level) => null;

  @override
  Map<int, double> loadAllBestAccuracy() => {};

  @override
  Map<int, double> loadAllFarnsworthBestAccuracy() => {1: 0.92};

  @override
  double? farnsworthBestAccuracy(int levelIndex) =>
      levelIndex == 1 ? 0.92 : null;

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
  Future<void> setFarnsworthLevelIndex(int index) async {
    farnsworthLevelIndex = index;
  }
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

Widget _buildFarnsworthLessonsApp({
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
        home: FarnsworthLessonsScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('FarnsworthLessonsScreen shows Farnsworth Method title',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final player = _StubPlayerService();
    final settings = await _makeSettingsCubit();

    await tester.pumpWidget(
      _buildFarnsworthLessonsApp(repo: repo, player: player, settings: settings),
    );

    expect(find.text('Farnsworth Method'), findsOneWidget);
  });

  testWidgets('FarnsworthLessonsScreen shows progress header',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final player = _StubPlayerService();
    final settings = await _makeSettingsCubit();

    await tester.pumpWidget(
      _buildFarnsworthLessonsApp(repo: repo, player: player, settings: settings),
    );

    // Progress header should show speed icon and level info
    expect(find.byIcon(Icons.speed), findsOneWidget);
    expect(find.textContaining('Level'), findsAtLeastNWidgets(1));
  });

  testWidgets('FarnsworthLessonsScreen shows lesson tiles',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final player = _StubPlayerService();
    final settings = await _makeSettingsCubit();

    await tester.pumpWidget(
      _buildFarnsworthLessonsApp(repo: repo, player: player, settings: settings),
    );

    // Should show lesson tiles
    expect(find.byType(ListTile), findsAtLeastNWidgets(1));
  });

  testWidgets('FarnsworthLessonsScreen shows WPM in level tiles',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final player = _StubPlayerService();
    final settings = await _makeSettingsCubit();

    await tester.pumpWidget(
      _buildFarnsworthLessonsApp(repo: repo, player: player, settings: settings),
    );

    // Should show WPM text in tiles
    expect(find.textContaining('WPM'), findsAtLeastNWidgets(1));
  });

  testWidgets('FarnsworthLessonsScreen shows accuracy chip for completed level',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final player = _StubPlayerService();
    final settings = await _makeSettingsCubit();

    await tester.pumpWidget(
      _buildFarnsworthLessonsApp(repo: repo, player: player, settings: settings),
    );

    // Should show accuracy chip with percentage
    expect(find.textContaining('%'), findsAtLeastNWidgets(1));
  });

  testWidgets('FarnsworthLessonsScreen shows locked icon for locked levels',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final player = _StubPlayerService();
    final settings = await _makeSettingsCubit();

    await tester.pumpWidget(
      _buildFarnsworthLessonsApp(repo: repo, player: player, settings: settings),
    );

    // Should show lock icon for locked levels
    expect(find.byIcon(Icons.lock_outline), findsAtLeastNWidgets(1));
  });

  testWidgets('FarnsworthLessonsScreen opens reference screen from app bar',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final player = _StubPlayerService();
    final settings = await _makeSettingsCubit();

    await tester.pumpWidget(
      _buildFarnsworthLessonsApp(repo: repo, player: player, settings: settings),
    );

    // Tap the reference icon
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();

    // Reference screen should be visible
    expect(find.text('Morse Reference'), findsOneWidget);
  });

  testWidgets('FarnsworthLessonsScreen opens lessons info dialog',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final player = _StubPlayerService();
    final settings = await _makeSettingsCubit();

    await tester.pumpWidget(
      _buildFarnsworthLessonsApp(repo: repo, player: player, settings: settings),
    );

    // Tap the info icon
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();

    // Info dialog should appear with learning content
    expect(find.textContaining('Learning Morse Code'), findsOneWidget);
  });

  testWidgets('FarnsworthLessonsScreen navigates to drill when tapping unlocked level',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final player = _StubPlayerService();
    final settings = await _makeSettingsCubit();

    await tester.pumpWidget(
      _buildFarnsworthLessonsApp(repo: repo, player: player, settings: settings),
    );

    // Find and tap the first unlocked lesson tile
    final listTiles = find.byType(ListTile);
    expect(listTiles, findsAtLeastNWidgets(1));
    
    // Tap the first enabled tile
    await tester.tap(listTiles.first);
    await tester.pumpAndSettle();

    // Should navigate to drill screen (check for drill-specific widgets)
    expect(find.text('What did you hear?'), findsOneWidget);
  });

  testWidgets('FarnsworthLessonsScreen does not navigate when tapping locked level',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final player = _StubPlayerService();
    final settings = await _makeSettingsCubit();

    await tester.pumpWidget(
      _buildFarnsworthLessonsApp(repo: repo, player: player, settings: settings),
    );

    // Find a locked level (one with lock icon)
    final lockIcons = find.byIcon(Icons.lock_outline);
    if (lockIcons.evaluate().isNotEmpty) {
      // Try to tap near the lock icon (the tile should be disabled)
      final lockedTile = find.ancestor(
        of: lockIcons.first,
        matching: find.byType(ListTile),
      );
      
      // Tapping should not navigate
      await tester.tap(lockedTile);
      await tester.pumpAndSettle();

      // Should still be on Farnsworth lessons screen
      expect(find.text('Farnsworth Method'), findsOneWidget);
    }
  });

  testWidgets('FarnsworthLessonsScreen shows best accuracy in progress header',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final player = _StubPlayerService();
    final settings = await _makeSettingsCubit();

    await tester.pumpWidget(
      _buildFarnsworthLessonsApp(repo: repo, player: player, settings: settings),
    );

    // Should show best accuracy text
    expect(find.textContaining('Best accuracy'), findsOneWidget);
  });

  testWidgets('FarnsworthLessonsScreen shows char and copy speed in progress header',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final player = _StubPlayerService();
    final settings = await _makeSettingsCubit();

    await tester.pumpWidget(
      _buildFarnsworthLessonsApp(repo: repo, player: player, settings: settings),
    );

    // Should show WPM speed information
    expect(find.textContaining('WPM'), findsAtLeastNWidgets(1));
  });

  testWidgets('FarnsworthLessonsScreen shows all 36 chars text',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final player = _StubPlayerService();
    final settings = await _makeSettingsCubit();

    await tester.pumpWidget(
      _buildFarnsworthLessonsApp(repo: repo, player: player, settings: settings),
    );

    // Should mention all 36 characters
    expect(find.textContaining('36'), findsAtLeastNWidgets(1));
  });
}
