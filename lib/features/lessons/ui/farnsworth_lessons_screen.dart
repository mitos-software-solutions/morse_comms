import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../player/player_service.dart';
import '../../settings/bloc/settings_cubit.dart';
import '../bloc/farnsworth_cubit.dart';
import '../data/farnsworth_curriculum.dart';
import '../data/lesson_repository.dart';
import 'farnsworth_drill_screen.dart';
import 'lessons_info.dart';
import 'reference_screen.dart';

class FarnsworthLessonsScreen extends StatelessWidget {
  const FarnsworthLessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FarnsworthCubit(context.read<LessonRepository>()),
      child: const _FarnsworthView(),
    );
  }
}

class _FarnsworthView extends StatelessWidget {
  const _FarnsworthView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farnsworth Method'),
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
      body: BlocBuilder<FarnsworthCubit, FarnsworthState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _FarnsworthProgressHeader(state: state),
              ...List.generate(kFarnsworthLevels.length, (i) {
                final isCurrentLevel = i == state.levelIndex;
                final isUnlocked = i <= state.levelIndex;
                final best = state.bestAccuracy[i];
                return _FarnsworthLevelTile(
                  levelIndex: i,
                  isCurrent: isCurrentLevel,
                  isUnlocked: isUnlocked,
                  bestAccuracy: best,
                  onTap: isUnlocked
                      ? () => _openDrill(context, i)
                      : null,
                );
              }),
            ],
          );
        },
      ),
    );
  }

  void _openDrill(BuildContext context, int levelIndex) {
    final cubit = context.read<FarnsworthCubit>();
    final player = context.read<PlayerService>();
    final settings = context.read<SettingsCubit>().state;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FarnsworthDrillScreen(
          cubit: cubit,
          player: player,
          levelIndex: levelIndex,
          frequencyHz: settings.toneFrequency.round(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress header
// ---------------------------------------------------------------------------

class _FarnsworthProgressHeader extends StatelessWidget {
  final FarnsworthState state;
  const _FarnsworthProgressHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final level = state.level;
    final best = state.bestAccuracy[state.levelIndex];
    final colors = Theme.of(context).colorScheme;
    final isFarnsworth = level.effectiveWpm < level.charWpm;

    return Card(
      margin: const EdgeInsets.all(16),
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: colors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    level.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colors.onSecondaryContainer,
                        ),
                  ),
                ),
                Text(
                  'Level ${state.levelIndex + 1} / ${kFarnsworthLevels.length}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSecondaryContainer,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              level.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
            ),
            if (isFarnsworth) ...[
              const SizedBox(height: 6),
              Text(
                'Characters at ${level.charWpm} WPM · Copy speed ${level.effectiveWpm} WPM · All 36 chars',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: colors.onSecondaryContainer,
                      letterSpacing: 1,
                    ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                'Standard timing at ${level.charWpm} WPM · All 36 chars',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: colors.onSecondaryContainer,
                      letterSpacing: 1,
                    ),
              ),
            ],
            if (best != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: best,
                backgroundColor: colors.secondary.withAlpha(51),
                color: colors.secondary,
              ),
              const SizedBox(height: 4),
              Text(
                'Best accuracy: ${(best * 100).round()}%'
                '${best >= 0.9 ? ' — ready to advance!' : ''}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSecondaryContainer,
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

class _FarnsworthLevelTile extends StatelessWidget {
  final int levelIndex;
  final bool isCurrent;
  final bool isUnlocked;
  final double? bestAccuracy;
  final VoidCallback? onTap;

  const _FarnsworthLevelTile({
    required this.levelIndex,
    required this.isCurrent,
    required this.isUnlocked,
    required this.bestAccuracy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final level = kFarnsworthLevels[levelIndex];
    final isFarnsworth = level.effectiveWpm < level.charWpm;

    Widget? trailing;
    if (!isUnlocked) {
      trailing = Icon(Icons.lock_outline, color: colors.outline);
    } else if (bestAccuracy != null) {
      trailing = _AccuracyChip(accuracy: bestAccuracy!);
    } else if (isCurrent) {
      trailing = Icon(Icons.play_circle_outline, color: colors.secondary);
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isCurrent
            ? colors.secondary
            : isUnlocked
                ? colors.secondaryContainer
                : colors.surfaceContainerHighest,
        foregroundColor:
            isCurrent ? colors.onSecondary : colors.onSecondaryContainer,
        child: Text(
          '${level.effectiveWpm}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
      title: Text(
        level.label,
        style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal),
      ),
      subtitle: Text(
        isFarnsworth
            ? 'Char ${level.charWpm} WPM · Copy ${level.effectiveWpm} WPM · All 36 chars'
            : '${level.charWpm} WPM · All 36 chars',
        style: Theme.of(context).textTheme.bodySmall,
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
