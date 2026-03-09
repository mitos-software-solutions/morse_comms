import 'package:flutter/material.dart';

/// Shows the general "Learning Morse Code" info bottom sheet.
///
/// Call from any screen that has a [?] info button.
void showLessonsInfo(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _LessonsInfoSheet(),
  );
}

class _LessonsInfoSheet extends StatelessWidget {
  const _LessonsInfoSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (_, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          children: const [
            _SheetHeader(),
            _InfoSection(
              icon: Icons.radio_outlined,
              title: 'Why Morse Code?',
              body:
                  'Morse code is one of the most resilient communication methods ever created. '
                  'A skilled operator needs only a battery, a wire, and a key — no cell towers, '
                  'no internet, no power grid. Amateur radio operators, preppers, '
                  'and military units rely on it when every other channel fails.\n\n'
                  'Learning to copy Morse by ear is a skill you carry in your head forever. '
                  'Once learned it never goes away, and it works across any radio band.',
            ),
            _InfoSection(
              icon: Icons.hearing_outlined,
              title: 'How It Works',
              body:
                  'Each letter, digit, and punctuation mark has a unique rhythm of short beeps '
                  '(dots ·) and long beeps (dashes —). You train your ear to recognise these '
                  'rhythms instantly, the way a musician recognises notes.\n\n'
                  'The goal is not to translate dot-dash patterns in your head — that is too slow. '
                  'You want each sound to trigger the character directly, without conscious thought.',
            ),
            _InfoSection(
              icon: Icons.school_outlined,
              title: 'Koch Method',
              accentIndex: 0,
              body:
                  'Start with exactly two characters — K and M — sent at your target speed. '
                  'When you can copy them with 90 % accuracy or better, one new character is added. '
                  'You never slow down; you always practise at the speed you plan to use.\n\n'
                  'This builds the correct ear reflexes from day one. '
                  'There is nothing to "unlearn" later.\n\n'
                  '36 levels · All characters by level 36',
            ),
            _InfoSection(
              icon: Icons.speed_outlined,
              title: 'Farnsworth Method',
              accentIndex: 1,
              body:
                  'All 36 characters are used from your very first session. '
                  'Each character is sent at full target speed so it sounds exactly right, '
                  'but the gaps between characters and words are stretched — giving you '
                  'extra time to think and write down what you heard.\n\n'
                  'Level by level the gaps narrow until they match the character speed '
                  'and you are copying at full standard timing. '
                  'Choose this path if you want broad exposure to the whole alphabet immediately.\n\n'
                  '10 levels · 5 WPM copy → 30 WPM copy',
            ),
            _InfoSection(
              icon: Icons.tips_and_updates_outlined,
              title: 'Practical Tips',
              body:
                  '• 10–15 minutes of focused daily practice beats one long session.\n'
                  '• Always press Play and listen before you type anything.\n'
                  '• Reach 90 % accuracy consistently before advancing a level.\n'
                  '• Both methods complement each other — feel free to use both.\n'
                  '• Use the Morse Reference card (book icon) whenever you want to '
                  'look up or hear any character.',
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _SheetHeader extends StatelessWidget {
  const _SheetHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Learning Morse Code',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'A skill that survives when everything else fails.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  /// 0 = primary colour (Koch), 1 = secondary colour (Farnsworth), null = default.
  final int? accentIndex;

  const _InfoSection({
    required this.icon,
    required this.title,
    required this.body,
    this.accentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accentColor = accentIndex == 0
        ? colors.primary
        : accentIndex == 1
            ? colors.secondary
            : colors.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: accentColor != colors.onSurfaceVariant
                            ? accentColor
                            : colors.onSurface,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.55,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
