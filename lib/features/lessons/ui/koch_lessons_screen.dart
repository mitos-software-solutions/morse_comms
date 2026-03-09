import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../player/player_service.dart';
import '../../settings/bloc/settings_cubit.dart';
import '../bloc/lesson_cubit.dart';
import '../data/koch_curriculum.dart';
import '../data/lesson_repository.dart';
import 'drill_screen.dart';
import 'lessons_info.dart';
import 'reference_screen.dart';

class KochLessonsScreen extends StatelessWidget {
  const KochLessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LessonCubit(context.read<LessonRepository>()),
      child: const _KochView(),
    );
  }
}

class _KochView extends StatelessWidget {
  const _KochView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Koch Method'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: 'Morse reference card',
            onPressed: () {
              final player = context.read<PlayerService>();
              final wpm = context.read<SettingsCubit>().state.wpm;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReferenceScreen(player: player, wpm: wpm),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About learning Morse',
            onPressed: () => showLessonsInfo(context),
          ),
        ],
      ),
      body: BlocBuilder<LessonCubit, LessonState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _KochProgressHeader(state: state),
              ...List.generate(kKochChars.length, (i) {
                final unlockedCount = i + 1;
                if (unlockedCount < kMinUnlockedCount) {
                  return const SizedBox.shrink();
                }
                final isCurrent = unlockedCount == state.unlockedCount;
                final isUnlocked = unlockedCount <= state.unlockedCount;
                final best = state.bestAccuracy[unlockedCount];
                return _KochLevelTile(
                  unlockedCount: unlockedCount,
                  isCurrent: isCurrent,
                  isUnlocked: isUnlocked,
                  bestAccuracy: best,
                  onTap: isUnlocked
                      ? () => _openDrill(context, unlockedCount)
                      : null,
                );
              }),
            ],
          );
        },
      ),
    );
  }

  void _openDrill(BuildContext context, int unlockedCount) {
    final cubit = context.read<LessonCubit>();
    final player = context.read<PlayerService>();
    final settings = context.read<SettingsCubit>().state;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillScreen(
          cubit: cubit,
          player: player,
          unlockedCount: unlockedCount,
          wpm: settings.wpm,
          frequencyHz: settings.toneFrequency.round(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress header
// ---------------------------------------------------------------------------

class _KochProgressHeader extends StatelessWidget {
  final LessonState state;
  const _KochProgressHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final chars = charsAt(state.unlockedCount);
    final best = state.bestAccuracy[state.unlockedCount];
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.all(16),
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.school, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    levelLabel(state.unlockedCount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onPrimaryContainer,
                        ),
                  ),
                ),
                Text(
                  'Level ${kochDisplayLevel(state.unlockedCount)} / $kKochTotalLevels',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Active characters: ${chars.join(' ')}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: colors.onPrimaryContainer,
                    letterSpacing: 2,
                  ),
            ),
            if (best != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: best,
                backgroundColor: colors.primary.withAlpha(51),
                color: colors.primary,
              ),
              const SizedBox(height: 4),
              Text(
                'Best accuracy: ${(best * 100).round()}%'
                '${best >= 0.9 ? ' — ready to advance!' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Level tile
// ---------------------------------------------------------------------------

class _KochLevelTile extends StatelessWidget {
  final int unlockedCount;
  final bool isCurrent;
  final bool isUnlocked;
  final double? bestAccuracy;
  final VoidCallback? onTap;

  const _KochLevelTile({
    required this.unlockedCount,
    required this.isCurrent,
    required this.isUnlocked,
    required this.bestAccuracy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final newChar = kKochChars[unlockedCount - 1];
    final allChars = charsAt(unlockedCount).join(' ');

    Widget? trailing;
    if (!isUnlocked) {
      trailing = Icon(Icons.lock_outline, color: colors.outline);
    } else if (bestAccuracy != null) {
      trailing = _AccuracyChip(accuracy: bestAccuracy!);
    } else if (isCurrent) {
      trailing = Icon(Icons.play_circle_outline, color: colors.primary);
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isCurrent
            ? colors.primary
            : isUnlocked
                ? colors.secondaryContainer
                : colors.surfaceContainerHighest,
        foregroundColor:
            isCurrent ? colors.onPrimary : colors.onSecondaryContainer,
        child: Text(newChar,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      title: Text(
        unlockedCount == kMinUnlockedCount
            ? 'Level 1 — Starting pair'
            : 'Level ${kochDisplayLevel(unlockedCount)} — Adds $newChar',
        style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
      ),
      subtitle: Text(
        allChars,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              letterSpacing: 1.5,
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing,
      enabled: onTap != null,
      onTap: onTap,
    );
  }
}

class _AccuracyChip extends StatelessWidget {
  final double accuracy;
  const _AccuracyChip({required this.accuracy});

  @override
  Widget build(BuildContext context) {
    final pct = (accuracy * 100).round();
    final color = accuracy >= 0.9
        ? Colors.green
        : accuracy >= 0.7
            ? Colors.orange
            : Colors.red;
    return Chip(
      label: Text('$pct%'),
      side: BorderSide(color: color),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
