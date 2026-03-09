import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/morse/morse_encoder.dart';
import '../../../core/morse/morse_timing.dart';
import '../../player/player_service.dart';
import '../bloc/lesson_cubit.dart';
import '../data/koch_curriculum.dart';
import 'drill_widgets.dart';

class DrillScreen extends StatelessWidget {
  final LessonCubit cubit;
  final PlayerService player;
  final int unlockedCount;
  final int wpm;
  final int frequencyHz;

  const DrillScreen({
    super.key,
    required this.cubit,
    required this.player,
    required this.unlockedCount,
    required this.wpm,
    required this.frequencyHz,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: cubit,
      child: _DrillView(
        player: player,
        wpm: wpm,
        frequencyHz: frequencyHz,
        unlockedCount: unlockedCount,
      ),
    );
  }
}

class _DrillView extends StatefulWidget {
  final PlayerService player;
  final int wpm;
  final int frequencyHz;
  final int unlockedCount;

  const _DrillView({
    required this.player,
    required this.wpm,
    required this.frequencyHz,
    required this.unlockedCount,
  });

  @override
  State<_DrillView> createState() => _DrillViewState();
}

class _DrillViewState extends State<_DrillView> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final MorseEncoder _encoder;
  bool _isPlaying = false;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    final clampedWpm = widget.wpm.clamp(MorseTiming.minWpm, MorseTiming.maxWpm);
    _encoder = MorseEncoder(timing: MorseTiming(wpm: clampedWpm));
    // Start the first session for this level.
    context.read<LessonCubit>().startSession();
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
    context.read<LessonCubit>().recordAnswer(input);
    _controller.clear();
    setState(() => _revealed = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(levelLabel(widget.unlockedCount)),
        leading: BackButton(
          onPressed: () async {
            await _stop();
            if (context.mounted) {
              context.read<LessonCubit>().clearSession();
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: BlocBuilder<LessonCubit, LessonState>(
        builder: (context, state) {
          if (state.sessionComplete) {
            final advanceLabel = state.canAdvance
                ? 'Advance — add ${kKochChars[state.unlockedCount]}'
                : 'Next level';
            return DrillSessionSummary(
              sessionAccuracy: state.sessionAccuracy,
              canAdvance: state.canAdvance,
              rounds: state.rounds!,
              advanceLabel: advanceLabel,
              onAdvance: () async {
                await context.read<LessonCubit>().advanceLevel();
                if (context.mounted) Navigator.pop(context);
              },
              onRepeat: () => context.read<LessonCubit>().startSession(),
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
                const SizedBox(height: 24),
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
