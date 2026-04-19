import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:morse_comms/main.dart' as app;

/// Entry point: runs all integration test groups.
///
/// Each group is kept in its own file; this file just pulls them in so a
/// single `flutter test integration_test/app_test.dart` command runs everything.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('navigation', navigationTests);
  group('encoder flow', encoderFlowTests);
  group('decoder flow', decoderFlowTests);
  group('settings flow', settingsFlowTests);
  group('lessons flow', lessonsFlowTests);
}

// ── per-group callbacks ────────────────────────────────────────────────────

void navigationTests() {
  testWidgets('all four tabs are reachable', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Encoder is the initial route.
    expect(find.text('Morse Encoder'), findsOneWidget);

    await tester.tap(find.text('Decoder'));
    await tester.pumpAndSettle();
    expect(find.text('Morse Decoder'), findsOneWidget);

    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.text('Learn Morse'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });
}

void encoderFlowTests() {
  testWidgets('typing text produces Morse output', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // Ensure we are on the Encoder tab.
    expect(find.text('Morse Encoder'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'SOS');
    await tester.pumpAndSettle();

    // SOS in Morse is ···−−−···
    expect(find.textContaining('···'), findsOneWidget);
  });
}

void decoderFlowTests() {
  testWidgets('Load Example → SOS → decoded text contains SOS', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Decoder'));
    await tester.pumpAndSettle();

    // Open the "Load Example" popup menu (science icon).
    await tester.tap(find.byTooltip('Load Example'));
    await tester.pumpAndSettle();

    // Select the SOS example.
    await tester.tap(find.text('SOS (20 WPM)'));
    // Analysis is async — give it up to 30 s on a slow CI runner.
    await tester.pumpAndSettle(const Duration(seconds: 30));

    expect(find.textContaining('SOS'), findsOneWidget);
  });
}

void settingsFlowTests() {
  testWidgets('WPM change persists when navigating away and back',
      (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Confirm default 20 WPM label is visible.
    expect(find.text('20 WPM'), findsOneWidget);

    // Drag the WPM slider.
    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.pumpAndSettle();

    // Label should no longer read 20 WPM.
    expect(find.text('20 WPM'), findsNothing);

    // Navigate away and come back.
    await tester.tap(find.text('Encoder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // The updated WPM label should still not be 20 WPM.
    expect(find.text('20 WPM'), findsNothing);
  });
}

void lessonsFlowTests() {
  testWidgets('Koch and Farnsworth cards are visible', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Koch'), findsOneWidget);
    expect(find.textContaining('Farnsworth'), findsOneWidget);
  });
}
