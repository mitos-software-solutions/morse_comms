import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:morse_comms/features/settings/bloc/settings_cubit.dart';
import 'package:morse_comms/features/settings/data/settings_repository.dart';
import 'package:morse_comms/features/settings/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsCubit> _makeSettingsCubit(
    [Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  return SettingsCubit(SettingsRepository(sp));
}

Widget _buildTestApp(SettingsCubit cubit) {
  return BlocProvider<SettingsCubit>.value(
    value: cubit,
    child: const MaterialApp(
      home: SettingsScreen(),
    ),
  );
}

void main() {
  testWidgets('SettingsScreen shows sections and controls',
      (WidgetTester tester) async {
    final cubit = await _makeSettingsCubit();

    await tester.pumpWidget(_buildTestApp(cubit));

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('MORSE SETTINGS'), findsOneWidget);
    expect(find.text('SPEECH RECOGNITION'), findsOneWidget);

    // Theme segmented button should be present.
    expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
  });

  testWidgets('WPM slider updates label on SettingsScreen',
      (WidgetTester tester) async {
    final cubit = await _makeSettingsCubit();

    await tester.pumpWidget(_buildTestApp(cubit));

    // Initial label should include "20 WPM" (default).
    expect(find.text('20 WPM'), findsOneWidget);

    // Drag the WPM slider a bit.
    final sliderFinder = find.byType(Slider).first;
    await tester.drag(sliderFinder, const Offset(50, 0));
    await tester.pumpAndSettle();

    // Label should have changed away from the initial "20 WPM".
    expect(find.text('20 WPM'), findsNothing);
  });

  testWidgets('Theme selector changes themeMode on SettingsScreen',
      (WidgetTester tester) async {
    final cubit = await _makeSettingsCubit();

    await tester.pumpWidget(_buildTestApp(cubit));

    // Tap the Dark theme segment.
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(cubit.state.themeMode, ThemeMode.dark);
  });

  testWidgets('Side-tone switch toggles sideTone in state',
      (WidgetTester tester) async {
    final cubit = await _makeSettingsCubit();

    await tester.pumpWidget(_buildTestApp(cubit));

    // Initial sideTone should be false.
    expect(cubit.state.sideTone, isFalse);

    // Tap the side-tone switch tile.
    await tester.tap(find.text('Side-tone while decoding'));
    await tester.pumpAndSettle();

    expect(cubit.state.sideTone, isTrue);
  });

  testWidgets('Donation button exists in widget tree',
      (WidgetTester tester) async {
    final cubit = await _makeSettingsCubit();

    await tester.pumpWidget(_buildTestApp(cubit));

    // Scroll down to make the donation button visible.
    await tester.dragUntilVisible(
      find.text('Buy Me a Coffee'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();

    // Verify the donation button exists.
    final buttonFinder = find.widgetWithText(FilledButton, 'Buy Me a Coffee');
    expect(buttonFinder, findsOneWidget);
  });

  testWidgets('Donation button has correct label text',
      (WidgetTester tester) async {
    final cubit = await _makeSettingsCubit();

    await tester.pumpWidget(_buildTestApp(cubit));

    // Scroll down to make the donation button visible.
    await tester.dragUntilVisible(
      find.text('Buy Me a Coffee'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();

    // Verify the button has the correct label text.
    expect(find.text('Buy Me a Coffee'), findsOneWidget);
  });

  testWidgets('Donation button has coffee icon', (WidgetTester tester) async {
    final cubit = await _makeSettingsCubit();

    await tester.pumpWidget(_buildTestApp(cubit));

    // Scroll down to make the donation button visible.
    await tester.dragUntilVisible(
      find.text('Buy Me a Coffee'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();

    // Find the button first.
    final buttonFinder = find.widgetWithText(FilledButton, 'Buy Me a Coffee');
    expect(buttonFinder, findsOneWidget);

    // Verify the button has a coffee icon.
    final iconFinder = find.descendant(
      of: buttonFinder,
      matching: find.byIcon(Icons.coffee),
    );
    expect(iconFinder, findsOneWidget);
  });

  testWidgets('Donation button meets 48x48 minimum touch target size',
      (WidgetTester tester) async {
    final cubit = await _makeSettingsCubit();

    await tester.pumpWidget(_buildTestApp(cubit));

    // Scroll down to make the donation button visible.
    await tester.dragUntilVisible(
      find.text('Buy Me a Coffee'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();

    // Find the button and check its size.
    final buttonFinder = find.widgetWithText(FilledButton, 'Buy Me a Coffee');
    expect(buttonFinder, findsOneWidget);

    final buttonSize = tester.getSize(buttonFinder);
    
    // Verify minimum touch target size of 48x48 logical pixels.
    expect(buttonSize.height, greaterThanOrEqualTo(48.0));
    expect(buttonSize.width, greaterThanOrEqualTo(48.0));
  });

  testWidgets('Donation button has accessibility label',
      (WidgetTester tester) async {
    final cubit = await _makeSettingsCubit();

    await tester.pumpWidget(_buildTestApp(cubit));

    // Scroll down to make the donation button visible.
    await tester.dragUntilVisible(
      find.text('Buy Me a Coffee'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();

    // Find the Semantics widget with our specific label.
    final semanticsFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == 'Opens external link to Buy Me a Coffee',
    );
    expect(semanticsFinder, findsOneWidget);

    // Verify the Semantics widget has button property set.
    final semanticsWidget = tester.widget<Semantics>(semanticsFinder);
    expect(semanticsWidget.properties.button, isTrue);
  });
}

