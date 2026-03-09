import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/player/player_service.dart';
import '../../../features/settings/bloc/settings_cubit.dart';
import '../bloc/encoder_bloc.dart';

class EncoderScreen extends StatelessWidget {
  const EncoderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsCubit>().state;
    return BlocProvider(
      create: (_) => EncoderBloc(
        player: context.read<PlayerService>(),
        wpm: settings.wpm,
        frequencyHz: settings.toneFrequency.round(),
        sttLocaleId: settings.sttLocaleId,
      ),
      child: BlocListener<SettingsCubit, SettingsState>(
        listenWhen: (prev, cur) =>
            prev.wpm != cur.wpm ||
            prev.toneFrequency != cur.toneFrequency ||
            prev.sttLocaleId != cur.sttLocaleId,
        listener: (context, s) => context.read<EncoderBloc>().add(
              EncoderSettingsChanged(
                wpm: s.wpm,
                frequencyHz: s.toneFrequency.round(),
                sttLocaleId: s.sttLocaleId,
              ),
            ),
        child: const _EncoderView(),
      ),
    );
  }
}

class _EncoderView extends StatefulWidget {
  const _EncoderView();

  @override
  State<_EncoderView> createState() => _EncoderViewState();
}

class _EncoderViewState extends State<_EncoderView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sync text field when STT fills in text from the BLoC.
    return BlocListener<EncoderBloc, EncoderState>(
      listenWhen: (prev, cur) =>
          prev.inputText != cur.inputText &&
          cur.inputText != _controller.text,
      listener: (context, state) {
        _controller.text = state.inputText;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: state.inputText.length),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Morse Encoder'),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Input row: text field + mic button ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        labelText: 'Enter text',
                        hintText: 'Type or tap the mic',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.keyboard),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (text) => context
                          .read<EncoderBloc>()
                          .add(EncoderTextChanged(text)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // --- Mic button ---
                  BlocBuilder<EncoderBloc, EncoderState>(
                    buildWhen: (prev, cur) =>
                        prev.sttStatus != cur.sttStatus,
                    builder: (context, state) {
                      final isListening =
                          state.sttStatus == SttStatus.listening;
                      return SizedBox(
                        height: 56,
                        child: FilledButton(
                          onPressed: () {
                            if (isListening) {
                              context
                                  .read<EncoderBloc>()
                                  .add(EncoderSttStopRequested());
                            } else {
                              context
                                  .read<EncoderBloc>()
                                  .add(EncoderSttStartRequested());
                            }
                          },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            backgroundColor: isListening
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                            foregroundColor: isListening
                                ? Theme.of(context).colorScheme.onError
                                : Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                          ),
                          child: Icon(
                            isListening ? Icons.mic : Icons.mic_none,
                            size: 28,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              // --- Listening / error status ---
              BlocBuilder<EncoderBloc, EncoderState>(
                buildWhen: (prev, cur) => prev.sttStatus != cur.sttStatus,
                builder: (context, state) {
                  if (state.sttStatus == SttStatus.listening) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Listening… speak now',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (state.sttStatus == SttStatus.error) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Microphone unavailable — check permissions',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              const SizedBox(height: 24),

              // --- English / recognised text card ---
              BlocBuilder<EncoderBloc, EncoderState>(
                buildWhen: (prev, cur) =>
                    prev.inputText != cur.inputText ||
                    prev.transliteratedText != cur.transliteratedText,
                builder: (context, state) {
                  return _EnglishCard(state: state);
                },
              ),

              const SizedBox(height: 12),

              // --- Morse output card ---
              BlocBuilder<EncoderBloc, EncoderState>(
                buildWhen: (prev, cur) =>
                    prev.morseWritten != cur.morseWritten,
                builder: (context, state) {
                  return _OutputCard(
                    label: 'Morse',
                    text: state.morseWritten.isEmpty
                        ? null
                        : state.morseWritten,
                    placeholder: '— morse output —',
                    textStyle:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                              letterSpacing: 2,
                              fontFamily: 'monospace',
                            ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // --- Play / Stop button ---
              BlocBuilder<EncoderBloc, EncoderState>(
                buildWhen: (prev, cur) =>
                    prev.playback != cur.playback ||
                    prev.canPlay != cur.canPlay,
                builder: (context, state) {
                  final isPlaying =
                      state.playback == PlaybackStatus.playing;
                  return FilledButton.icon(
                    onPressed: state.morseWritten.isEmpty
                        ? null
                        : () {
                            if (isPlaying) {
                              context
                                  .read<EncoderBloc>()
                                  .add(EncoderStopRequested());
                            } else {
                              context
                                  .read<EncoderBloc>()
                                  .add(EncoderPlayRequested());
                            }
                          },
                    icon: Icon(isPlaying ? Icons.stop : Icons.volume_up),
                    label: Text(isPlaying ? 'Stop' : 'Play'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: isPlaying
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the recognised/typed English text. When transliteration was applied,
/// also shows the Latin form that was actually encoded, so the user can verify
/// both what was heard and what will be transmitted.
class _EnglishCard extends StatelessWidget {
  const _EnglishCard({required this.state});
  final EncoderState state;

  @override
  Widget build(BuildContext context) {
    final isEmpty = state.inputText.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recognised text',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: isEmpty
              ? Text(
                  '— recognised text —',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.inputText,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (state.wasTransliterated) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.translate,
                            size: 14,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              state.transliteratedText,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Transliterated to Latin for Morse encoding',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// Labelled output card used for both English and Morse displays.
class _OutputCard extends StatelessWidget {
  const _OutputCard({
    required this.label,
    required this.text,
    required this.placeholder,
    this.textStyle,
  });

  final String label;
  final String? text;
  final String placeholder;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final isEmpty = text == null || text!.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isEmpty ? placeholder : text!,
            style: textStyle?.copyWith(
              color: isEmpty
                  ? Theme.of(context).colorScheme.outline
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
