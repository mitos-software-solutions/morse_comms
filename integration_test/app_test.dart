import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:morse_comms/main.dart' as app;

// In integration tests the real app persists between testWidgets calls.
// app.main() must only be called once — calling it again re-registers GetIt
// services and calls runApp() inside an already-running test, both of which
// throw. The flag below ensures exactly one launch per test process.
bool _appLaunched = false;

Future<void> _launchOnce(WidgetTester tester) async {
  if (!_appLaunched) {
    _appLaunched = true;
    app.main();
  }
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('navigation — all four tabs are reachable', (tester) async {
    await _launchOnce(tester);

    // Initial route is Encoder.
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

  testWidgets('encoder — typing text produces Morse output', (tester) async {
    await _launchOnce(tester);

    await tester.tap(find.text('Encoder'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'SOS');
    await tester.pumpAndSettle();

    expect(find.textContaining('···'), findsOneWidget);
  });

  testWidgets('decoder — Load Example SOS decodes correctly', (tester) async {
    await _launchOnce(tester);

    await tester.tap(find.text('Decoder'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Load Example'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SOS (20 WPM)'));
    // DSP analysis is async — allow up to 30 s on slow CI runners.
    await tester.pumpAndSettle(const Duration(seconds: 30));

    expect(find.textContaining('SOS'), findsOneWidget);
  });

  testWidgets('settings — WPM change persists across navigation', (tester) async {
    await _launchOnce(tester);

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
  });

  testWidgets('lessons — Koch and Farnsworth cards are visible', (tester) async {
    await _launchOnce(tester);

    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Koch'), findsOneWidget);
    expect(find.textContaining('Farnsworth'), findsOneWidget);
  });
}
