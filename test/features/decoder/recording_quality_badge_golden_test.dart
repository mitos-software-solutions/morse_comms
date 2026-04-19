import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:morse_comms/features/decoder/ui/decoder_screen.dart';

void main() {
  group('RecordingQualityBadge golden', () {
    Widget buildBadge(double quality, {bool dark = false}) {
      return MaterialApp(
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: RecordingQualityBadge(quality: quality),
          ),
        ),
      );
    }

    testGoldens('LOW quality light theme', (tester) async {
      await tester.pumpWidgetBuilder(
        buildBadge(0.5),
        surfaceSize: const Size(400, 80),
      );
      await screenMatchesGolden(tester, 'recording_quality_badge_low_light');
    });

    testGoldens('MED quality light theme', (tester) async {
      await tester.pumpWidgetBuilder(
        buildBadge(0.8),
        surfaceSize: const Size(400, 80),
      );
      await screenMatchesGolden(tester, 'recording_quality_badge_med_light');
    });

    testGoldens('LOW quality dark theme', (tester) async {
      await tester.pumpWidgetBuilder(
        buildBadge(0.5, dark: true),
        surfaceSize: const Size(400, 80),
      );
      await screenMatchesGolden(tester, 'recording_quality_badge_low_dark');
    });

    testGoldens('MED quality dark theme', (tester) async {
      await tester.pumpWidgetBuilder(
        buildBadge(0.8, dark: true),
        surfaceSize: const Size(400, 80),
      );
      await screenMatchesGolden(tester, 'recording_quality_badge_med_dark');
    });
  });
}
