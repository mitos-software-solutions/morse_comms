/// Shared drill UI widgets used by both KochDrillScreen and FarnsworthDrillScreen.
library;

import 'package:flutter/material.dart';

import '../bloc/lesson_state.dart';

// ---------------------------------------------------------------------------
// Play card
// ---------------------------------------------------------------------------

class DrillPlayCard extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onStop;

  const DrillPlayCard({
    super.key,
    required this.isPlaying,
    required this.onPlay,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.surfaceContainerHighest,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isPlaying ? onStop : onPlay,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Icon(
                isPlaying ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                size: 56,
                color: isPlaying ? colors.error : colors.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                isPlaying ? 'Tap to stop' : 'Tap to play',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                isPlaying
                    ? 'Playing… tap to stop early'
                    : 'Listen carefully — then type what you heard',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Round counter
// ---------------------------------------------------------------------------

class DrillRoundCounter extends StatelessWidget {
  final int current;
  final int total;
  const DrillRoundCounter({super.key, required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(value: (current - 1) / total),
        ),
        const SizedBox(width: 12),
        Text(
          'Round $current / $total',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Previous rounds log
// ---------------------------------------------------------------------------

class DrillPreviousRounds extends StatelessWidget {
  final List<DrillRound> rounds;
  final int currentRound;

  const DrillPreviousRounds({
    super.key,
    required this.rounds,
    required this.currentRound,
  });

  @override
  Widget build(BuildContext context) {
    final answered = rounds
        .take(currentRound)
        .where((r) => r.answer != null)
        .toList()
        .reversed
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PREVIOUS ROUNDS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        ...answered.map((r) => DrillRoundResultTile(round: r)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Single round result tile
// ---------------------------------------------------------------------------

class DrillRoundResultTile extends StatelessWidget {
  final DrillRound round;
  const DrillRoundResultTile({super.key, required this.round});

  @override
  Widget build(BuildContext context) {
    final pct = ((round.accuracy ?? 0) * 100).round();
    final color = pct == 100
        ? Colors.green
        : pct >= 60
            ? Colors.orange
            : Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontFamily: 'monospace'),
                children: _buildDiff(round.prompt, round.answer ?? ''),
              ),
            ),
          ),
          Text(
            '$pct%',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _buildDiff(String prompt, String answer) {
    final spans = <TextSpan>[];
    for (int i = 0; i < prompt.length; i++) {
      final expected = prompt[i];
      final got = i < answer.length ? answer[i] : '_';
      final match = expected == got;
      spans.add(TextSpan(
        text: got,
        style: TextStyle(color: match ? Colors.green : Colors.red),
      ));
    }
    return spans;
  }
}

// ---------------------------------------------------------------------------
// Session summary
// ---------------------------------------------------------------------------

class DrillSessionSummary extends StatelessWidget {
  final double sessionAccuracy;
  final bool canAdvance;
  final List<DrillRound> rounds;
  final String advanceLabel;
  final VoidCallback onRepeat;
  final Future<void> Function() onAdvance;

  const DrillSessionSummary({
    super.key,
    required this.sessionAccuracy,
    required this.canAdvance,
    required this.rounds,
    required this.advanceLabel,
    required this.onRepeat,
    required this.onAdvance,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (sessionAccuracy * 100).round();
    final colors = Theme.of(context).colorScheme;
    final passed = sessionAccuracy >= 0.9;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            passed ? Icons.emoji_events : Icons.replay,
            size: 64,
            color: passed ? Colors.amber : colors.outline,
          ),
          const SizedBox(height: 16),
          Text(
            passed ? 'Excellent!' : 'Keep practising',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Session accuracy: $pct%',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            passed
                ? 'You scored ≥90% — you can advance to the next level!'
                : 'Aim for 90% accuracy to unlock the next level.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 32),
          ...rounds.asMap().entries.map((e) {
            final i = e.key;
            final r = e.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text('Round ${i + 1}: ',
                      style: Theme.of(context).textTheme.bodySmall),
                  Expanded(child: DrillRoundResultTile(round: r)),
                ],
              ),
            );
          }),
          const SizedBox(height: 32),
          if (canAdvance)
            FilledButton.icon(
              onPressed: onAdvance,
              icon: const Icon(Icons.arrow_forward),
              label: Text(advanceLabel),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRepeat,
            icon: const Icon(Icons.replay),
            label: const Text('Drill again'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
