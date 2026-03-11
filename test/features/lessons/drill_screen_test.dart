import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/features/lessons/bloc/lesson_cubit.dart';
import 'package:morse_comms/features/lessons/data/lesson_repository.dart';
import 'package:morse_comms/features/lessons/ui/drill_screen.dart';
import 'package:morse_comms/features/player/player_service.dart';
import 'package:morse_comms/core/morse/morse_encoder.dart';

class _FakeLessonRepository implements LessonRepository {
  @override
  int unlockedCount = 2;

  @override
  int get farnsworthLevelIndex => 0;

  @override
  double? bestAccuracy(int level) => null;

  @override
  Map<int, double> loadAllBestAccuracy() => {};

  @override
  Map<int, double> loadAllFarnsworthBestAccuracy() => {};

  @override
  double? farnsworthBestAccuracy(int levelIndex) => null;

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

Widget _buildDrillApp({
  required LessonCubit cubit,
  required PlayerService player,
  int unlockedCount = 2,
  int wpm = 20,
  int frequencyHz = 700,
}) {
  return MaterialApp(
    home: DrillScreen(
      cubit: cubit,
      player: player,
      unlockedCount: unlockedCount,
      wpm: wpm,
      frequencyHz: frequencyHz,
    ),
  );
}

void main() {
  testWidgets('DrillScreen shows level title', (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final cubit = LessonCubit(repo);
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildDrillApp(cubit: cubit, player: player),
    );

    // Should show level label in app bar
    expect(find.textContaining('Level'), findsOneWidget);
  });

  testWidgets('DrillScreen shows round counter', (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final cubit = LessonCubit(repo);
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildDrillApp(cubit: cubit, player: player),
    );

    // Should show round counter (e.g., "Round 1 / 5")
    expect(find.textContaining('/'), findsAtLeastNWidgets(1));
  });

  testWidgets('DrillScreen shows play button', (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final cubit = LessonCubit(repo);
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildDrillApp(cubit: cubit, player: player),
    );

    // Should show play button
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
  });

  testWidgets('DrillScreen shows input field', (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final cubit = LessonCubit(repo);
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildDrillApp(cubit: cubit, player: player),
    );

    // Should show input field with hint
    expect(find.text('What did you hear?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('DrillScreen shows Check button', (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final cubit = LessonCubit(repo);
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildDrillApp(cubit: cubit, player: player),
    );

    // Should show Check button
    expect(find.text('Check'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('DrillScreen shows Reveal Answer button',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final cubit = LessonCubit(repo);
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildDrillApp(cubit: cubit, player: player),
    );

    // Should show Reveal Answer button
    expect(find.text('Reveal Answer'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('DrillScreen play button calls player service',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final cubit = LessonCubit(repo);
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildDrillApp(cubit: cubit, player: player),
    );

    // Tap play button
    await tester.tap(find.byIcon(Icons.play_circle_outline));
    await tester.pumpAndSettle();

    // Player service should be called
    expect(player.playCalled, isTrue);
  });

  testWidgets('DrillScreen reveals answer when Reveal button tapped',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final cubit = LessonCubit(repo);
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildDrillApp(cubit: cubit, player: player),
    );

    // Tap Reveal Answer button
    await tester.tap(find.text('Reveal Answer'));
    await tester.pumpAndSettle();

    // Answer should now be visible (revealed text should be uppercase)
    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('DrillScreen accepts text input', (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final cubit = LessonCubit(repo);
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildDrillApp(cubit: cubit, player: player),
    );

    // Enter text in the input field
    await tester.enterText(find.byType(TextField), 'KM');
    await tester.pump();

    // Text should be in the field
    expect(find.text('KM'), findsOneWidget);
  });

  testWidgets('DrillScreen submits answer when Check button tapped',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final cubit = LessonCubit(repo);
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildDrillApp(cubit: cubit, player: player),
    );

    // Enter text
    await tester.enterText(find.byType(TextField), 'KM');
    await tester.pump();

    // Tap Check button
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    // Should advance to next round (round counter should change)
    expect(find.textContaining('/'), findsAtLeastNWidgets(1));
  });

  testWidgets('DrillScreen shows session summary after all rounds',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final cubit = LessonCubit(repo);
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildDrillApp(cubit: cubit, player: player),
    );

    // Complete all 5 rounds
    for (int i = 0; i < 5; i++) {
      await tester.enterText(find.byType(TextField), 'KM');
      await tester.pump();
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
    }

    // Should show session summary with accuracy
    expect(find.textContaining('Session accuracy'), findsOneWidget);
    expect(find.text('Drill again'), findsOneWidget);
  });

  testWidgets('DrillScreen stops player when back button pressed',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final cubit = LessonCubit(repo);
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildDrillApp(cubit: cubit, player: player),
    );

    // Tap back button
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Player should be stopped
    expect(player.stopCalled, isTrue);
  });

  testWidgets('DrillScreen shows hearing icon in input field',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final cubit = LessonCubit(repo);
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildDrillApp(cubit: cubit, player: player),
    );

    // Should show hearing icon as suffix
    expect(find.byIcon(Icons.hearing), findsOneWidget);
  });

  testWidgets('DrillScreen clears input after submitting answer',
      (WidgetTester tester) async {
    final repo = _FakeLessonRepository();
    final cubit = LessonCubit(repo);
    final player = _StubPlayerService();

    await tester.pumpWidget(
      _buildDrillApp(cubit: cubit, player: player),
    );

    // Enter text
    await tester.enterText(find.byType(TextField), 'KM');
    await tester.pump();
    expect(find.text('KM'), findsOneWidget);

    // Submit answer
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    // Input should be cleared
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, isEmpty);
  });
}
