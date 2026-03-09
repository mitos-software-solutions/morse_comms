import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../player/player_service.dart';
import '../../settings/bloc/settings_cubit.dart';
import '../data/farnsworth_curriculum.dart';
import '../data/koch_curriculum.dart';
import '../data/lesson_repository.dart';
import 'farnsworth_lessons_screen.dart';
import 'koch_lessons_screen.dart';
import 'lessons_info.dart';
import 'reference_screen.dart';

class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key});

  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  late LessonRepository _repo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo = context.read<LessonRepository>();
  }

  Future<void> _openKoch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KochLessonsScreen()),
    );
    setState(() {});
  }

  Future<void> _openFarnsworth() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FarnsworthLessonsScreen()),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final kochUnlocked = _repo.unlockedCount;
    final kochLevel = kochDisplayLevel(kochUnlocked); // 1-based display level
    final kochTotal = kKochTotalLevels; // 35
    final kochBest = _repo.bestAccuracy(kochUnlocked);

    final farnsworthLevel = _repo.farnsworthLevelIndex;
    final farnsworthTotal = kFarnsworthLevels.length;
    final farnsworthBest = _repo.farnsworthBestAccuracy(farnsworthLevel);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn Morse'),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          _MethodCard(
            icon: Icons.school,
            title: 'Koch Method',
            subtitle: 'Build up character by character',
            description:
                'Start with just two characters — K and M — sent at your target speed. '
                'Once you can copy them at 90% accuracy, one new character is added. '
                'You never slow down, so you build the right reflexes from day one.',
            progressLabel: 'Level $kochLevel / $kochTotal',
            progressValue: kochLevel / kochTotal, // display level / total levels
            bestAccuracy: kochBest,
            accentColor: Theme.of(context).colorScheme.primary,
            onAccentColor: Theme.of(context).colorScheme.onPrimary,
            containerColor: Theme.of(context).colorScheme.primaryContainer,
            onContainerColor: Theme.of(context).colorScheme.onPrimaryContainer,
            onTap: _openKoch,
          ),
          const SizedBox(height: 16),
          _MethodCard(
            icon: Icons.speed,
            title: 'Farnsworth Method',
            subtitle: 'All 36 characters from day one',
            description:
                'Every character is used from your very first session, sent at full target speed. '
                'Extra space between characters gives you time to think. '
                'Level by level the gaps narrow until you copy at full speed.',
            progressLabel: 'Level ${farnsworthLevel + 1} / $farnsworthTotal',
            progressValue: (farnsworthLevel + 1) / farnsworthTotal,
            bestAccuracy: farnsworthBest,
            accentColor: Theme.of(context).colorScheme.secondary,
            onAccentColor: Theme.of(context).colorScheme.onSecondary,
            containerColor: Theme.of(context).colorScheme.secondaryContainer,
            onContainerColor: Theme.of(context).colorScheme.onSecondaryContainer,
            onTap: _openFarnsworth,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Method card
// ---------------------------------------------------------------------------

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final String progressLabel;
  final double progressValue;
  final double? bestAccuracy;
  final Color accentColor;
  final Color onAccentColor;
  final Color containerColor;
  final Color onContainerColor;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.progressLabel,
    required this.progressValue,
    required this.bestAccuracy,
    required this.accentColor,
    required this.onAccentColor,
    required this.containerColor,
    required this.onContainerColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final best = bestAccuracy;
    return Card(
      color: containerColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: accentColor,
                    foregroundColor: onAccentColor,
                    child: Icon(icon),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: onContainerColor,
                              ),
                        ),
                        Text(
                          subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: onContainerColor),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        progressLabel,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: onContainerColor,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Icon(Icons.arrow_forward_ios,
                          size: 14, color: onContainerColor),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: onContainerColor,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progressValue,
                backgroundColor: accentColor.withAlpha(51),
                color: accentColor,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              if (best != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Current level best: ${(best * 100).round()}%'
                  '${best >= 0.9 ? ' ✓' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: onContainerColor,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
