import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:morse_comms/features/settings/bloc/settings_cubit.dart';
import 'package:morse_comms/features/settings/data/settings_repository.dart';
import 'package:morse_comms/features/settings/data/stt_locale_loader.dart';
import 'package:morse_comms/features/settings/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSttLocaleLoader implements SttLocaleLoader {
  final List<SttLocale> locales;
  _FakeSttLocaleLoader([this.locales = const []]);

  @override
  Future<List<SttLocale>> load() async => List.of(locales);
}

Future<SettingsCubit> _makeSettingsCubit([
  Map<String, Object> prefs = const {},
  List<SttLocale> locales = const [],
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  return SettingsCubit(
    SettingsRepository(sp),
    localeLoader: _FakeSttLocaleLoader(locales),
  );
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

  // ---------------------------------------------------------------------------
  // Support section — Get involved
  // ---------------------------------------------------------------------------

  testWidgets('Get involved section shows title and description',
      (WidgetTester tester) async {
    final cubit = await _makeSettingsCubit();

    await tester.pumpWidget(_buildTestApp(cubit));

    await tester.dragUntilVisible(
      find.text('SUPPORT & CONTRIBUTE'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();

    expect(find.text('SUPPORT & CONTRIBUTE'), findsOneWidget);
    expect(find.text('Get involved'), findsOneWidget);
    expect(
      find.textContaining('free, open source, and has no ads'),
      findsOneWidget,
    );
  });

  testWidgets('View on GitHub button exists with code icon',
      (WidgetTester tester) async {
    final cubit = await _makeSettingsCubit();

    await tester.pumpWidget(_buildTestApp(cubit));

    await tester.dragUntilVisible(
      find.text('View on GitHub'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();

    final buttonFinder = find.widgetWithText(FilledButton, 'View on GitHub');
    expect(buttonFinder, findsOneWidget);

    expect(
      find.descendant(of: buttonFinder, matching: find.byIcon(Icons.code)),
      findsOneWidget,
    );
  });

  testWidgets('View on GitHub button meets 48x48 minimum touch target size',
      (WidgetTester tester) async {
    final cubit = await _makeSettingsCubit();

    await tester.pumpWidget(_buildTestApp(cubit));

    await tester.dragUntilVisible(
      find.text('View on GitHub'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();

    final buttonSize =
        tester.getSize(find.widgetWithText(FilledButton, 'View on GitHub'));
    expect(buttonSize.height, greaterThanOrEqualTo(48.0));
    expect(buttonSize.width, greaterThanOrEqualTo(48.0));
  });

  // ---------------------------------------------------------------------------
  // Support section — Buy me a coffee
  // ---------------------------------------------------------------------------

  testWidgets('Buy me a coffee section shows correct heading',
      (WidgetTester tester) async {
    final cubit = await _makeSettingsCubit();

    await tester.pumpWidget(_buildTestApp(cubit));

    await tester.dragUntilVisible(
      find.text('Buy me a coffee?'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buy me a coffee?'), findsOneWidget);
    expect(find.textContaining('virtual coffee'), findsOneWidget);
  });

  testWidgets('Both action buttons in the support section are FilledButtons',
      (WidgetTester tester) async {
    final cubit = await _makeSettingsCubit();

    await tester.pumpWidget(_buildTestApp(cubit));

    await tester.dragUntilVisible(
      find.text('Buy Me a Coffee'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'View on GitHub'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Buy Me a Coffee'), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // Frequency slider
  // ---------------------------------------------------------------------------

  testWidgets('Tone frequency slider updates Hz label on SettingsScreen',
      (WidgetTester tester) async {
    final cubit = await _makeSettingsCubit();

    await tester.pumpWidget(_buildTestApp(cubit));

    // Scroll until the frequency slider is visible.
    await tester.dragUntilVisible(
      find.text('600 Hz'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();

    // Initial label should show the default 600 Hz.
    expect(find.text('600 Hz'), findsOneWidget);

    // After scrolling to the frequency section the WPM slider may have
    // scrolled off-screen, so use .last rather than a fixed index.
    final sliderFinder = find.byType(Slider).last;
    await tester.drag(sliderFinder, const Offset(60, 0));
    await tester.pumpAndSettle();

    // Label should have changed away from 600 Hz.
    expect(find.text('600 Hz'), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // _LocalePickerDialog
  // ---------------------------------------------------------------------------

  Future<void> openLocaleDialog(WidgetTester tester) async {
    await tester.dragUntilVisible(
      find.text('Voice input language'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.tap(find.text('Voice input language').first);
    // The SpeechToText singleton registers a persistent setMethodCallHandler
    // that prevents pumpAndSettle from draining. Use pump/pump instead to
    // advance past the dialog open animation without waiting for full settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('locale picker dialog opens with spinner when no locales loaded',
      (WidgetTester tester) async {
    final cubit = await _makeSettingsCubit();
    await tester.pumpWidget(_buildTestApp(cubit));
    await openLocaleDialog(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('locale picker dialog shows radio tiles when locales are loaded',
      (WidgetTester tester) async {
    // Use IDs that don't match the default sttLocaleId ('en_US') so the tile
    // subtitle shows the raw ID and the locale names only appear in the dialog.
    const locales = [
      SttLocale(id: 'el_GR', name: 'Greek (Greece)'),
      SttLocale(id: 'ja_JP', name: 'Japanese (Japan)'),
    ];
    final cubit = await _makeSettingsCubit(const {}, locales);
    cubit.emit(cubit.state.copyWith(sttLocales: locales));

    await tester.pumpWidget(_buildTestApp(cubit));
    await openLocaleDialog(tester);

    expect(find.text('Greek (Greece)'), findsOneWidget);
    expect(find.text('Japanese (Japan)'), findsOneWidget);
    expect(find.byType(RadioListTile<String>), findsNWidgets(2));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Cancel button closes the locale picker dialog',
      (WidgetTester tester) async {
    final cubit = await _makeSettingsCubit();
    await tester.pumpWidget(_buildTestApp(cubit));
    await openLocaleDialog(tester);

    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('tapping a locale updates sttLocaleId and closes dialog',
      (WidgetTester tester) async {
    const locales = [
      SttLocale(id: 'el_GR', name: 'Greek (Greece)'),
      SttLocale(id: 'ja_JP', name: 'Japanese (Japan)'),
    ];
    final cubit = await _makeSettingsCubit(const {}, locales);
    cubit.emit(cubit.state.copyWith(sttLocales: locales));

    await tester.pumpWidget(_buildTestApp(cubit));
    await openLocaleDialog(tester);

    await tester.tap(find.text('Greek (Greece)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(cubit.state.sttLocaleId, 'el_GR');
    expect(find.byType(AlertDialog), findsNothing);
  });

  // ---------------------------------------------------------------------------
  // About section
  // ---------------------------------------------------------------------------

  testWidgets('About section renders Version and Open-source licences tiles',
      (WidgetTester tester) async {
    final cubit = await _makeSettingsCubit();

    await tester.pumpWidget(_buildTestApp(cubit));

    await tester.dragUntilVisible(
      find.text('ABOUT'),
      find.byType(ListView),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();

    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('Open-source licences'), findsOneWidget);
  });
}

