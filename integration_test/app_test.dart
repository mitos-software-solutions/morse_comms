import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:morse_comms/main.dart' as app;

// Integration tests share a single running app instance — the widget tree
// persists across logical sections. All flows live in one testWidgets call
// to avoid the GetIt double-registration error that occurs when app.main()
// is called more than once per process.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app integration flows', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    // ── 1. Navigation — all four tabs are reachable ───────────────────────
    expect(find.text('Morse Encoder'), findsOneWidget);

    await tester.tap(find.text('Decoder'));
    await tester.pumpAndSettle();
    expect(find.text('Morse Decoder'), findsOneWidget);

    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.text('Learn Morse'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    // 'APPEARANCE' is a section header unique to the Settings screen.
    // Asserting on it avoids the ambiguity where both the AppBar title and
    // the nav bar label are the string "Settings".
    expect(find.text('APPEARANCE'), findsOneWidget);

    // ── 2. Encoder — typing text produces Morse output ────────────────────
    await tester.tap(find.text('Encoder'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'SOS');
    await tester.pumpAndSettle();
    expect(find.textContaining('...'), findsOneWidget);

    // ── 3. Decoder — Load Example SOS decodes correctly ───────────────────
    await tester.tap(find.text('Decoder'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Load Example'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SOS (20 WPM)'));
    // DSP analysis is async — allow up to 30 s on slow CI runners.
    await tester.pumpAndSettle(const Duration(seconds: 30));

    expect(find.textContaining('SOS'), findsOneWidget);

    // ── 4. Settings — WPM change persists across navigation ───────────────
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('20 WPM'), findsOneWidget);

    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(find.text('20 WPM'), findsNothing);

    await tester.tap(find.text('Encoder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('20 WPM'), findsNothing);

    // ── 5. Lessons — browse Koch and Farnsworth drill screens ────────────
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Koch'), findsOneWidget);
    expect(find.textContaining('Farnsworth'), findsOneWidget);

    // Tap into Koch drill list and verify the screen opens.
    await tester.tap(find.textContaining('Koch'));
    await tester.pumpAndSettle();
    expect(find.text('Koch Method'), findsOneWidget);

    // Go back to Learn.
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Tap into Farnsworth drill list and verify the screen opens.
    await tester.tap(find.textContaining('Farnsworth'));
    await tester.pumpAndSettle();
    expect(find.text('Farnsworth Method'), findsOneWidget);

    // Go back to Learn.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Learn Morse'), findsOneWidget);
  });
}
