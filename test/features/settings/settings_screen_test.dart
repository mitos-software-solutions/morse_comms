import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:morse_comms/features/settings/bloc/settings_cubit.dart';
import 'package:morse_comms/features/settings/bloc/settings_state.dart';
import 'package:morse_comms/features/settings/data/settings_repository.dart';
import 'package:morse_comms/features/settings/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsCubit> _makeSettingsCubit([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  return SettingsCubit(SettingsRepository(sp));
}

class _FakeSettingsCubit extends SettingsCubit {
  _FakeSettingsCubit(SettingsRepository repo) : super(repo);

  @override
  Future<void> loadSttLocales() async {
    emit(state.copyWith(sttLocales: const [
      SttLocale(id: 'en_US', name: 'English (US)'),
      SttLocale(id: 'de_DE', name: 'German'),
    ]));
  }
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

}


