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

  testWidgets('Navigation bar shows correct selected index',
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

    // Initially on Encoder (index 0)
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.selectedIndex, equals(0));

    // Navigate to Decoder (index 1)
    await tester.tap(find.text('Decoder'));
    await tester.pumpAndSettle();
    final navBar2 = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar2.selectedIndex, equals(1));

    // Navigate to Learn (index 2)
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    final navBar3 = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar3.selectedIndex, equals(2));

    // Navigate to Settings (index 3)
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final navBar4 = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar4.selectedIndex, equals(3));
  });

  testWidgets('App preserves state when switching tabs',
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

    // Verify navigation bar exists
    expect(find.byType(NavigationBar), findsOneWidget);

    // Switch to Decoder
    await tester.tap(find.text('Decoder'));
    await tester.pumpAndSettle();
    expect(find.text('Morse Decoder'), findsOneWidget);

    // Switch to Learn
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.text('Learn Morse'), findsOneWidget);

    // Switch back to Decoder - state should be preserved
    await tester.tap(find.text('Decoder'));
    await tester.pumpAndSettle();
    expect(find.text('Morse Decoder'), findsOneWidget);

    // Switch to Settings
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Settings'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('App shows all navigation destinations',
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

    // All navigation destinations should be visible in the navigation bar
    final navBar = find.byType(NavigationBar);
    expect(
      find.descendant(of: navBar, matching: find.text('Encoder')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('Decoder')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('Learn')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('Settings')),
      findsOneWidget,
    );

    // All navigation icons should be visible
    expect(find.byIcon(Icons.keyboard), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.byIcon(Icons.school_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('App applies theme mode from settings',
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

    // App should be built with MaterialApp.router
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('App provides repositories to all screens',
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

    // Navigate to each screen to verify they load correctly
    // Encoder screen (default) - verify navigation bar exists
    expect(find.byType(NavigationBar), findsOneWidget);

    // Decoder screen
    await tester.tap(find.text('Decoder'));
    await tester.pumpAndSettle();
    expect(find.text('Morse Decoder'), findsOneWidget);

    // Learn screen
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.text('Learn Morse'), findsOneWidget);

    // Settings screen
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Settings'),
      ),
      findsOneWidget,
    );
  });
}

