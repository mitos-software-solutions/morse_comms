import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/morse/farnsworth_timing.dart';
import '../../../core/morse/morse_encoder.dart';
import '../../../core/morse/morse_timing.dart';
import '../../player/player_service.dart';
import '../bloc/farnsworth_cubit.dart';
import '../data/farnsworth_curriculum.dart';
import 'drill_widgets.dart';

class FarnsworthDrillScreen extends StatelessWidget {
  final FarnsworthCubit cubit;
  final PlayerService player;
  final int levelIndex;
  final int frequencyHz;

  const FarnsworthDrillScreen({
    super.key,
    required this.cubit,
    required this.player,
    required this.levelIndex,
    required this.frequencyHz,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: cubit,
      child: _FarnsworthDrillView(
        player: player,
        levelIndex: levelIndex,
        frequencyHz: frequencyHz,
      ),
    );
  }
}

class _FarnsworthDrillView extends StatefulWidget {
  final PlayerService player;
  final int levelIndex;
  final int frequencyHz;

  const _FarnsworthDrillView({
    required this.player,
    required this.levelIndex,
    required this.frequencyHz,
  });

  @override
  State<_FarnsworthDrillView> createState() => _FarnsworthDrillViewState();
}

class _FarnsworthDrillViewState extends State<_FarnsworthDrillView> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final MorseEncoder _encoder;
  bool _isPlaying = false;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    final level = kFarnsworthLevels[widget.levelIndex];
    final charWpm =
        level.charWpm.clamp(MorseTiming.minWpm, MorseTiming.maxWpm);
    final effWpm = level.effectiveWpm.clamp(1, charWpm);
    _encoder = MorseEncoder(
      timing: FarnsworthTiming(charWpm: charWpm, effectiveWpm: effWpm),
    );
    context.read<FarnsworthCubit>().startSession();
  }

  @override
  void dispose() {
    widget.player.stop(); // stop any in-progress audio when screen is removed
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _play(String prompt) async {
    if (_isPlaying) return;
    setState(() => _isPlaying = true);
    final encoding = _encoder.encode(prompt);
    await widget.player.play(encoding.tones, frequencyHz: widget.frequencyHz);
    if (mounted) setState(() => _isPlaying = false);
    _focus.requestFocus();
  }

  Future<void> _stop() async {
    await widget.player.stop();
    if (mounted) setState(() => _isPlaying = false);
  }

  void _submit() {
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    context.read<FarnsworthCubit>().recordAnswer(input);
    _controller.clear();
    setState(() => _revealed = false);
  }

  @override
  Widget build(BuildContext context) {
    final level = kFarnsworthLevels[widget.levelIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text(level.label),
        leading: BackButton(
          onPressed: () async {
            await _stop();
            if (context.mounted) {
              context.read<FarnsworthCubit>().clearSession();
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: BlocBuilder<FarnsworthCubit, FarnsworthState>(
        builder: (context, state) {
          if (state.sessionComplete) {
            final nextLevel = state.canAdvance
                ? kFarnsworthLevels[state.levelIndex + 1]
                : null;
            final advanceLabel = nextLevel != null
                ? 'Advance — ${nextLevel.label}'
                : 'Next level';
            return DrillSessionSummary(
              sessionAccuracy: state.sessionAccuracy,
              canAdvance: state.canAdvance,
              rounds: state.rounds!,
              advanceLabel: advanceLabel,
              onAdvance: () async {
                await context.read<FarnsworthCubit>().advanceLevel();
                if (context.mounted) Navigator.pop(context);
              },
              onRepeat: () => context.read<FarnsworthCubit>().startSession(),
            );
          }

          final round = state.currentRoundData;
          if (round == null) return const SizedBox.shrink();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DrillRoundCounter(
                  current: state.currentRound + 1,
                  total: state.rounds!.length,
                ),
                const SizedBox(height: 8),
                _TimingBadge(level: level),
                const SizedBox(height: 16),
                DrillPlayCard(
                  isPlaying: _isPlaying,
                  onPlay: () => _play(round.prompt),
                  onStop: _stop,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  focusNode: _focus,
                  decoration: const InputDecoration(
                    labelText: 'What did you hear?',
                    hintText: 'Type the characters',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.hearing),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check),
                  label: const Text('Check'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _revealed ? null : () => setState(() => _revealed = true),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Reveal Answer'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                if (_revealed) ...[
                  const SizedBox(height: 16),
                  Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      round.prompt.toUpperCase(),
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                if (state.currentRound > 0)
                  DrillPreviousRounds(
                    rounds: state.rounds!,
                    currentRound: state.currentRound,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small badge showing char / effective WPM for the current level
// ---------------------------------------------------------------------------

class _TimingBadge extends StatelessWidget {
  final FarnsworthLevel level;
  const _TimingBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isFarnsworth = level.effectiveWpm < level.charWpm;
    final label = isFarnsworth
        ? 'Char speed ${level.charWpm} WPM · Copy speed ${level.effectiveWpm} WPM'
        : 'Standard timing · ${level.charWpm} WPM';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.speed, size: 14, color: colors.secondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colors.secondary),
        ),
      ],
    );
  }
}
