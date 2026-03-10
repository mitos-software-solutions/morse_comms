import 'package:flutter/material.dart';

import '../../../core/morse/morse_encoder.dart';
import '../../../core/morse/morse_table.dart';
import '../../../core/morse/morse_timing.dart';
import '../../player/player_service.dart';

// ---------------------------------------------------------------------------
// Static reference data
// ---------------------------------------------------------------------------

const _letters = [
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
];

const _digits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

const _punctuation = [
  '.', ',', '?', "'", '!', '/', '(', ')', '&', ':', ';', '=', '+', '-', '"', '@',
];

const _extendedLatin = [
  'À', 'Å', 'Ä', 'Æ', 'É', 'È', 'Ñ', 'Ö', 'Ø', 'Ü', 'Ĥ', 'Ĵ', 'Ŝ', 'Ŭ',
];

// Common CW abbreviations
const _abbreviations = [
  ('CQ',  'Calling all stations (anyone listening?)'),
  ('DE',  'From (precedes the sender\'s callsign)'),
  ('K',   'Go ahead / Over (any station may reply)'),
  ('KN',  'Go ahead — invited station only'),
  ('AR',  'End of message'),
  ('SK',  'End of contact / Sign off'),
  ('73',  'Best regards'),
  ('88',  'Love and kisses (informal)'),
  ('OM',  'Old man (fellow male operator)'),
  ('YL',  'Young lady (female operator)'),
  ('TNX', 'Thanks'),
  ('TU',  'Thank you'),
  ('HI',  'Laughter (ha ha)'),
  ('NR',  'Number'),
  ('UR',  'Your'),
  ('RST', 'Signal report: Readability / Strength / Tone'),
  ('QSL', 'I confirm receipt (also: confirmation card)'),
  ('QRZ', 'Who is calling me?'),
  ('QTH', 'My location is…'),
  ('QRM', 'Man-made interference'),
  ('QRN', 'Static / natural noise'),
  ('QSB', 'Signal fading'),
  ('QRT', 'Stop sending / Going off the air'),
  ('QRX', 'Please wait / Stand by'),
  ('QSY', 'Change frequency'),
  ('QSO', 'Radio contact'),
];

const _beginnerTips = [
  (
    Icons.hearing,
    'Train your ears, not your eyes',
    'Don\'t try to decode Morse by watching dots and dashes. '
        'Your goal is to recognise each character as a distinct sound pattern, like a spoken word.',
  ),
  (
    Icons.speed,
    'Always train at your target speed',
    'The Koch method works by drilling at full speed from day one. '
        'Slow practice teaches you to count symbols — fast practice teaches you to hear characters.',
  ),
  (
    Icons.calendar_today,
    'Short sessions beat long ones',
    '15–20 minutes every day is far more effective than 2 hours once a week. '
        'Your brain consolidates the patterns overnight.',
  ),
  (
    Icons.add_circle_outline,
    'Add one character at a time',
    'Start with K and M. Once you hit 90% accuracy, add R — and so on. '
        'Never move on until you can reliably identify the current set.',
  ),
  (
    Icons.record_voice_over,
    'Use sound mnemonics',
    '"Dit" = short (dot) · "Dah" = long (dash). '
        'Some learners invent word-based mnemonics: '
        'K sounds like "Kil-o-wat" (dah-dit-dah), '
        'M sounds like "More" (dah-dah).',
  ),
  (
    Icons.timer,
    'Understand the timing',
    'At 20 WPM a dot is 60 ms and a dash is 180 ms. '
        'Letter gaps are 3× a dot; word gaps are 7×. '
        'You shouldn\'t be counting — just feel the rhythm.',
  ),
  (
    Icons.wifi,
    'Listen to real CW traffic',
    'Tuning into amateur radio CW transmissions (even if you can\'t decode everything) '
        'trains your ear to real-world conditions and motivates practice.',
  ),
];

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ReferenceScreen extends StatefulWidget {
  final PlayerService player;
  final int wpm;

  const ReferenceScreen({super.key, required this.player, required this.wpm});

  @override
  State<ReferenceScreen> createState() => _ReferenceScreenState();
}

class _ReferenceScreenState extends State<ReferenceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final MorseEncoder _encoder;
  String? _playingId; // key of the char / prosign currently playing

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    final clampedWpm =
        widget.wpm.clamp(MorseTiming.minWpm, MorseTiming.maxWpm);
    _encoder = MorseEncoder(timing: MorseTiming(wpm: clampedWpm));
  }

  @override
  void dispose() {
    _tabs.dispose();
    widget.player.stop();
    super.dispose();
  }

  // Play a character from kMorseTable
  Future<void> _playChar(String char) async {
    if (_playingId == char) {
      await widget.player.stop();
      if (mounted) setState(() => _playingId = null);
      return;
    }
    setState(() => _playingId = char);
    final tones = _encoder.encode(char).tones;
    await widget.player.play(tones);
    if (mounted) setState(() => _playingId = null);
  }

  // Play a prosign from a raw pattern string (no inter-character gaps)
  Future<void> _playProsign(String code, String pattern) async {
    if (_playingId == code) {
      await widget.player.stop();
      if (mounted) setState(() => _playingId = null);
      return;
    }
    setState(() => _playingId = code);
    final timing = _encoder.timing;
    final tones = <MorseTone>[];
    for (int i = 0; i < pattern.length; i++) {
      final isDash = pattern[i] == '-';
      tones.add(MorseTone(
        on: true,
        durationMs: isDash ? timing.dashMs : timing.dotMs,
      ));
      if (i < pattern.length - 1) {
        tones.add(MorseTone(on: false, durationMs: timing.symbolGapMs));
      }
    }
    await widget.player.play(tones);
    if (mounted) setState(() => _playingId = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Morse Reference'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.grid_view), text: 'Characters'),
            Tab(icon: Icon(Icons.school_outlined), text: 'Guide'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _CharactersTab(
            playingId: _playingId,
            onPlayChar: _playChar,
            onPlayProsign: _playProsign,
          ),
          const _GuideTab(),
        ],
      ),
    );
  }
}

// ===========================================================================
// CHARACTERS TAB
// ===========================================================================

class _CharactersTab extends StatelessWidget {
  final String? playingId;
  final Future<void> Function(String char) onPlayChar;
  final Future<void> Function(String code, String pattern) onPlayProsign;

  const _CharactersTab({
    required this.playingId,
    required this.onPlayChar,
    required this.onPlayProsign,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _GroupHeader('Letters (A – Z)'),
        _CharGrid(chars: _letters, playingId: playingId, onPlay: onPlayChar),
        const SizedBox(height: 16),
        _GroupHeader('Digits (0 – 9)'),
        _CharGrid(chars: _digits, playingId: playingId, onPlay: onPlayChar),
        const SizedBox(height: 16),
        _GroupHeader('Punctuation'),
        _CharGrid(
            chars: _punctuation, playingId: playingId, onPlay: onPlayChar),
        const SizedBox(height: 16),
        _GroupHeader('Extended Latin & Esperanto'),
        _CharGrid(
            chars: _extendedLatin, playingId: playingId, onPlay: onPlayChar),
        const SizedBox(height: 16),
        _GroupHeader('Prosigns'),
        const _ProsignNote(),
        const SizedBox(height: 8),
        ...kProsigns.map(
          (p) => _ProsignTile(
            prosign: p,
            isPlaying: playingId == p.code,
            onPlay: () => onPlayProsign(p.code, p.pattern),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;
  const _GroupHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.4,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _CharGrid extends StatelessWidget {
  final List<String> chars;
  final String? playingId;
  final Future<void> Function(String) onPlay;

  const _CharGrid({
    required this.chars,
    required this.playingId,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 56,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: chars.length,
      itemBuilder: (_, i) => _CharTile(
        char: chars[i],
        isPlaying: playingId == chars[i],
        onPlay: () => onPlay(chars[i]),
      ),
    );
  }
}

class _CharTile extends StatelessWidget {
  final String char;
  final bool isPlaying;
  final VoidCallback onPlay;

  const _CharTile({
    required this.char,
    required this.isPlaying,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final pattern = kMorseTable[char] ?? '';
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: isPlaying ? colors.primaryContainer : colors.surfaceContainerHighest,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPlay,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  char,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isPlaying ? colors.primary : null,
                      ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  pattern,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                isPlaying ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                size: 20,
                color: isPlaying ? colors.primary : colors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProsignNote extends StatelessWidget {
  const _ProsignNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        'Prosigns are sent as one continuous unit — no gaps between letters.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
            ),
      ),
    );
  }
}

class _ProsignTile extends StatelessWidget {
  final MorseProsign prosign;
  final bool isPlaying;
  final VoidCallback onPlay;

  const _ProsignTile({
    required this.prosign,
    required this.isPlaying,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isPlaying ? colors.primaryContainer : null,
      child: ListTile(
        onTap: onPlay,
        leading: CircleAvatar(
          backgroundColor: isPlaying ? colors.primary : colors.secondaryContainer,
          foregroundColor:
              isPlaying ? colors.onPrimary : colors.onSecondaryContainer,
          child: Text(
            prosign.code.length <= 2 ? prosign.code : prosign.code[0],
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Text(prosign.code,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Text(
              prosign.pattern,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                  ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prosign.description),
            if (prosign.note != null)
              Text(
                prosign.note!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: colors.outline,
                    ),
              ),
          ],
        ),
        isThreeLine: prosign.note != null,
        trailing: Icon(
          isPlaying ? Icons.stop_circle_outlined : Icons.play_circle_outline,
          color: isPlaying ? colors.primary : colors.outline,
        ),
      ),
    );
  }
}

// ===========================================================================
// GUIDE TAB
// ===========================================================================

class _GuideTab extends StatelessWidget {
  const _GuideTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _intro(context),
        const SizedBox(height: 16),
        _timingCard(context),
        const SizedBox(height: 16),
        _GroupHeader('Beginner Tips'),
        ..._beginnerTips.map((t) => _TipCard(icon: t.$1, title: t.$2, body: t.$3)),
        const SizedBox(height: 16),
        _GroupHeader('Common Abbreviations & Q-Codes'),
        ..._abbreviations.map((a) => _AbbrevTile(code: a.$1, meaning: a.$2)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _intro(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  'What is Morse Code?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colors.onPrimaryContainer,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Morse code represents letters, digits and punctuation as '
              'sequences of short signals (dots / "dits") and long signals '
              '(dashes / "dahs"). It was developed in the 1830s and remains '
              'a reliable communication method when voice is impractical — '
              'especially in low-power or noisy radio conditions.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'International Morse Code (ITU) is fully standardised: every '
              'country uses the same patterns, making it a universal '
              'language across amateur radio, maritime, and survival contexts.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timingCard(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TIMING — THE ONLY RULE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _TimingRow(label: 'Dot (dit)', units: 1, color: colors.primary),
            _TimingRow(label: 'Dash (dah)', units: 3, color: colors.primary),
            _TimingRow(
                label: 'Gap within character', units: 1, color: colors.outline),
            _TimingRow(
                label: 'Gap between letters', units: 3, color: colors.outline),
            _TimingRow(
                label: 'Gap between words', units: 7, color: colors.outline),
            const SizedBox(height: 10),
            Text(
              'At 20 WPM, 1 unit = 60 ms.  A dot is 60 ms; a dash is 180 ms.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimingRow extends StatelessWidget {
  final String label;
  final int units;
  final Color color;

  const _TimingRow({
    required this.label,
    required this.units,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            flex: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...List.generate(
                  units,
                  (_) => Container(
                    width: 14,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text('$units unit${units > 1 ? 's' : ''}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _TipCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(body,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AbbrevTile extends StatelessWidget {
  final String code;
  final String meaning;

  const _AbbrevTile({required this.code, required this.meaning});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(
              code,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                    fontFamily: 'monospace',
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(meaning,
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
