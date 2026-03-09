import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/features/lessons/ui/reference_screen.dart';
import 'package:morse_comms/features/player/player_service.dart';
import 'package:morse_comms/core/morse/morse_encoder.dart';

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

Widget _buildReferenceApp(PlayerService player) {
  return MaterialApp(
    home: ReferenceScreen(
      player: player,
      wpm: 20,
    ),
  );
}

void main() {
  testWidgets('ReferenceScreen shows tabs and groups',
      (WidgetTester tester) async {
    final player = _StubPlayerService();

    await tester.pumpWidget(_buildReferenceApp(player));

    // App bar and tabs.
    expect(find.text('Morse Reference'), findsOneWidget);
    expect(find.text('Characters'), findsOneWidget);
    expect(find.text('Guide'), findsOneWidget);

    // Characters tab content: at least one character tile and one prosign tile.
    expect(find.byType(GridView), findsWidgets);
  });

  testWidgets('ReferenceScreen can switch to Guide tab',
      (WidgetTester tester) async {
    final player = _StubPlayerService();

    await tester.pumpWidget(_buildReferenceApp(player));

    // Tap "Guide" tab.
    await tester.tap(find.text('Guide'));
    await tester.pumpAndSettle();

    // Intro card and guide content should be present.
    expect(find.text('What is Morse Code?'), findsOneWidget);
  });
}

