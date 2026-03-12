import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/features/decoder/ui/decoder_screen.dart';

Widget _wrap(double quality) {
  return MaterialApp(
    home: Scaffold(
      body: RecordingQualityBadge(quality: quality),
    ),
  );
}

void main() {
  group('RecordingQualityBadge', () {
    group('MED quality (0.7 ≤ quality < 1.0)', () {
      testWidgets('shows fair-quality message at quality=0.7',
          (tester) async {
        await tester.pumpWidget(_wrap(0.7));
        expect(
          find.text(
              'Recording quality: fair — some segments were unclear'),
          findsOneWidget,
        );
      });

      testWidgets('shows fair-quality message at quality=0.8',
          (tester) async {
        await tester.pumpWidget(_wrap(0.8));
        expect(
          find.text(
              'Recording quality: fair — some segments were unclear'),
          findsOneWidget,
        );
      });

      testWidgets('shows info_outline icon at quality=0.8', (tester) async {
        await tester.pumpWidget(_wrap(0.8));
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      });
    });

    group('LOW quality (quality < 0.7)', () {
      testWidgets('shows poor-quality message at quality=0.69',
          (tester) async {
        await tester.pumpWidget(_wrap(0.69));
        expect(
          find.text(
              'Recording quality: poor — output may be approximate'),
          findsOneWidget,
        );
      });

      testWidgets('shows poor-quality message at quality=0.0',
          (tester) async {
        await tester.pumpWidget(_wrap(0.0));
        expect(
          find.text(
              'Recording quality: poor — output may be approximate'),
          findsOneWidget,
        );
      });

      testWidgets('shows warning_amber_rounded icon at quality=0.3',
          (tester) async {
        await tester.pumpWidget(_wrap(0.3));
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
        expect(find.byIcon(Icons.info_outline), findsNothing);
      });
    });

    group('boundary values', () {
      testWidgets('quality=0.699 is LOW (just below threshold)',
          (tester) async {
        await tester.pumpWidget(_wrap(0.699));
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      });

      testWidgets('quality=0.7 is MED (at threshold)', (tester) async {
        await tester.pumpWidget(_wrap(0.7));
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      });
    });
  });

  group('DecoderScreen recording quality badge visibility', () {
    testWidgets('badge is not shown in initial idle state',
        (tester) async {
      // The badge is only rendered when hasResult && quality < 1.0.
      // In the initial idle state quality=1.0, so no badge text appears.
      expect(
        find.text('Recording quality: poor — output may be approximate'),
        findsNothing,
      );
      expect(
        find.text('Recording quality: fair — some segments were unclear'),
        findsNothing,
      );
    });
  });
}
