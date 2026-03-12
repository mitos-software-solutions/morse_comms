import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../player/player_service.dart';
import '../../settings/bloc/settings_cubit.dart';
import '../bloc/decoder_bloc.dart';
import '../data/decoder_service.dart';

class DecoderScreen extends StatelessWidget {
  const DecoderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsCubit>().state;
    final player = context.read<PlayerService>();
    final int freqHz = settings.toneFrequency.round();

    void Function(bool)? sideToneCallback;
    if (settings.sideTone) {
      sideToneCallback = (isTone) {
        if (isTone) {
          player.startTone(frequencyHz: freqHz);
        } else {
          player.stopTone();
        }
      };
    }

    return BlocProvider(
      create: (_) => DecoderBloc(
        service: DecoderService(onSideTone: sideToneCallback),
        player: player,
      ),
      child: const _DecoderView(),
    );
  }
}

class _DecoderView extends StatelessWidget {
  const _DecoderView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<DecoderBloc, DecoderState>(
      listenWhen: (p, c) => c.savedPath != null && p.savedPath != c.savedPath,
      listener: (context, state) {
        Share.shareXFiles(
          [XFile(state.savedPath!, mimeType: 'audio/wav')],
          subject: 'Morse Recording',
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Morse Decoder'),
          centerTitle: true,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Audio toolbar ──────────────────────────────────────────────
            const _AudioToolbar(),
            const Divider(height: 1),

            // ── Scrollable content ─────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Permission denied banner ───────────────────────────
                    BlocBuilder<DecoderBloc, DecoderState>(
                      buildWhen: (p, c) =>
                          p.permissionDenied != c.permissionDenied,
                      builder: (context, state) {
                        if (!state.permissionDenied) {
                          return const SizedBox.shrink();
                        }
                        return _Banner(
                          icon: Icons.mic_off,
                          message: 'Microphone permission denied. '
                              'Grant it in Settings → Apps → morse_comms.',
                          color: Theme.of(context).colorScheme.error,
                          background:
                              Theme.of(context).colorScheme.errorContainer,
                          foreground:
                              Theme.of(context).colorScheme.onErrorContainer,
                        );
                      },
                    ),

                    // ── Error banner ───────────────────────────────────────
                    BlocBuilder<DecoderBloc, DecoderState>(
                      buildWhen: (p, c) =>
                          p.errorMessage != c.errorMessage,
                      builder: (context, state) {
                        final err = state.errorMessage;
                        if (err == null) return const SizedBox.shrink();
                        return _Banner(
                          icon: Icons.error_outline,
                          message: 'Error: $err',
                          color: Theme.of(context).colorScheme.error,
                          background:
                              Theme.of(context).colorScheme.errorContainer,
                          foreground:
                              Theme.of(context).colorScheme.onErrorContainer,
                        );
                      },
                    ),

                    // ── Recording timer + signal meter ─────────────────────
                    BlocBuilder<DecoderBloc, DecoderState>(
                      buildWhen: (p, c) =>
                          p.isListening != c.isListening ||
                          p.recordingSeconds != c.recordingSeconds ||
                          p.signalSnapshot != c.signalSnapshot,
                      builder: (context, state) {
                        if (!state.isListening) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _RecordingHeader(seconds: state.recordingSeconds),
                              const SizedBox(height: 8),
                              _SignalMeter(snapshot: state.signalSnapshot),
                            ],
                          ),
                        );
                      },
                    ),

                    // ── Analyzing spinner ──────────────────────────────────
                    BlocBuilder<DecoderBloc, DecoderState>(
                      buildWhen: (p, c) => p.isAnalyzing != c.isAnalyzing,
                      builder: (context, state) {
                        if (!state.isAnalyzing) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Analyzing recording…',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // ── Saved chip + re-share ──────────────────────────────
                    BlocBuilder<DecoderBloc, DecoderState>(
                      buildWhen: (p, c) => p.savedPath != c.savedPath,
                      builder: (context, state) {
                        final path = state.savedPath;
                        if (path == null) return const SizedBox.shrink();
                        final filename = path.split('/').last;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 16,
                                  color: Colors.green.shade600),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Saved: $filename',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Colors.green.shade700,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.share_outlined),
                                iconSize: 18,
                                tooltip: 'Share',
                                visualDensity: VisualDensity.compact,
                                color: Colors.green.shade700,
                                onPressed: () => context
                                    .read<DecoderBloc>()
                                    .add(DecoderShareRequested()),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // ── Decoded text display ───────────────────────────────
                    Expanded(
                      child: BlocBuilder<DecoderBloc, DecoderState>(
                        buildWhen: (p, c) =>
                            p.decodedText != c.decodedText ||
                            p.status != c.status,
                        builder: (context, state) {
                          final placeholder = _placeholderText(state);
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: SingleChildScrollView(
                              reverse: true,
                              child: Text(
                                state.decodedText.isEmpty
                                    ? placeholder
                                    : state.decodedText,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      letterSpacing: 1.5,
                                      color: state.decodedText.isEmpty
                                          ? Theme.of(context)
                                              .colorScheme
                                              .outline
                                          : null,
                                    ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // ── Recording quality badge ────────────────────────────
                    BlocBuilder<DecoderBloc, DecoderState>(
                      buildWhen: (p, c) =>
                          p.recordingQuality != c.recordingQuality ||
                          p.status != c.status,
                      builder: (context, state) {
                        if (!state.hasResult ||
                            state.recordingQuality >= 1.0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: RecordingQualityBadge(
                              quality: state.recordingQuality),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // ── Listen / Stop button (full width, always present) ──
                    BlocBuilder<DecoderBloc, DecoderState>(
                      buildWhen: (p, c) => p.status != c.status,
                      builder: (context, state) {
                        final bloc = context.read<DecoderBloc>();
                        return FilledButton.icon(
                          onPressed: state.isListening
                              ? () => bloc.add(DecoderStopRequested())
                              : state.isAnalyzing
                                  ? null
                                  : () => bloc.add(DecoderListenRequested()),
                          icon: state.isListening
                              ? const Icon(Icons.stop)
                              : state.isAnalyzing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Icon(Icons.mic),
                          label: Text(
                            state.isListening
                                ? 'Stop'
                                : state.isAnalyzing
                                    ? 'Analyzing…'
                                    : 'Listen',
                          ),
                          style: FilledButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: state.isListening
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
          ],
        ),
      ),
    );
  }

  String _placeholderText(DecoderState state) {
    return switch (state.status) {
      DecoderStatus.idle => 'Press Listen to start recording',
      DecoderStatus.listening => 'Recording… press Stop when done',
      DecoderStatus.analyzing => 'Analyzing…',
      DecoderStatus.result =>
        state.decodedText.isEmpty ? 'No Morse detected' : state.decodedText,
    };
  }
}

// ── Audio toolbar ──────────────────────────────────────────────────────────────

class _AudioToolbar extends StatelessWidget {
  const _AudioToolbar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DecoderBloc, DecoderState>(
      buildWhen: (p, c) =>
          p.status != c.status ||
          p.audioBytes != c.audioBytes ||
          p.isPlayingAudio != c.isPlayingAudio ||
          p.decodedText != c.decodedText,
      builder: (context, state) {
        final bloc = context.read<DecoderBloc>();
        final busy = state.isListening || state.isAnalyzing;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              // New / Reset
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'New Recording',
                onPressed: state.hasResult ||
                        (state.status == DecoderStatus.idle &&
                            state.decodedText.isNotEmpty)
                    ? () => bloc.add(DecoderCleared())
                    : null,
              ),

              // Load example WAV
              PopupMenuButton<_ExampleWav>(
                icon: const Icon(Icons.science_outlined),
                tooltip: 'Load Example',
                enabled: !busy,
                onSelected: (example) async {
                  final data = await rootBundle.load(example.assetPath);
                  final bytes = data.buffer.asUint8List();
                  bloc.add(DecoderFileAnalysisRequested(bytes, example.label));
                },
                itemBuilder: (_) => _ExampleWav.values
                    .map((e) => PopupMenuItem(
                          value: e,
                          child: Text(e.label),
                        ))
                    .toList(),
              ),

              // Load from storage
              IconButton(
                icon: const Icon(Icons.folder_open_outlined),
                tooltip: 'Open Recording',
                onPressed: busy
                    ? null
                    : () async {
                        const typeGroup = XTypeGroup(
                          label: 'WAV files',
                          extensions: ['wav'],
                        );
                        final file = await openFile(
                          acceptedTypeGroups: [typeGroup],
                        );
                        if (file == null) return;
                        final bytes = await file.readAsBytes();
                        bloc.add(
                            DecoderFileAnalysisRequested(bytes, file.name));
                      },
              ),

              const Spacer(),

              // Play / Stop audio — only when audio is available
              if (state.audioBytes != null) ...[
                IconButton(
                  icon: Icon(
                    state.isPlayingAudio
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline,
                  ),
                  tooltip:
                      state.isPlayingAudio ? 'Stop playback' : 'Play audio',
                  onPressed: () => bloc.add(
                    state.isPlayingAudio
                        ? DecoderAudioStopRequested()
                        : DecoderAudioPlayRequested(),
                  ),
                ),

                // Save
                IconButton(
                  icon: const Icon(Icons.save_alt),
                  tooltip: 'Save',
                  onPressed: () => _showSaveDialog(context),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showSaveDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Save to Device'),
        content: const Text(
          'A share sheet will open.\n\n'
          '• Android: tap "Save to Downloads" or "My Files"\n'
          '• iOS: tap "Save to Files"\n\n'
          'The WAV file will then be available in your device\'s file manager '
          'and can be reloaded here via the folder icon.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<DecoderBloc>().add(DecoderSaveRequested());
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

// ── Recording header ──────────────────────────────────────────────────────────

class _RecordingHeader extends StatelessWidget {
  final int seconds;
  const _RecordingHeader({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final timeLabel = '$m:${s.toString().padLeft(2, '0')}';
    return Row(
      children: [
        Icon(Icons.fiber_manual_record,
            size: 12, color: Theme.of(context).colorScheme.error),
        const SizedBox(width: 6),
        Text(
          'Recording  $timeLabel',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

// ── Signal meter ──────────────────────────────────────────────────────────────

class _SignalMeter extends StatelessWidget {
  final SignalSnapshot? snapshot;
  const _SignalMeter({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final level = (snapshot?.normalizedToThreshold ?? 0.0).clamp(0.0, 3.0);
    final isTone = snapshot?.isTone ?? false;
    final color = isTone
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(isTone ? Icons.graphic_eq : Icons.remove,
                size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              isTone ? 'TONE' : 'silence',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight:
                        isTone ? FontWeight.bold : FontWeight.normal,
                  ),
            ),
            const Spacer(),
            Text(
              '${(level * 100).toStringAsFixed(0)}%',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (level / 3.0).clamp(0.0, 1.0),
            minHeight: 8,
            color: color,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

// ── Banner ────────────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  final Color background;
  final Color foreground;

  const _Banner({
    required this.icon,
    required this.message,
    required this.color,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: foreground)),
          ),
        ],
      ),
    );
  }
}

// ── Recording quality badge ───────────────────────────────────────────────────

/// Badge displayed below the decoded-text box when analysis confidence is below 1.0.
///
/// Exposed for widget tests via `@visibleForTesting`.
@visibleForTesting
class RecordingQualityBadge extends StatelessWidget {
  final double quality;
  const RecordingQualityBadge({super.key, required this.quality});

  @override
  Widget build(BuildContext context) {
    final isLow = quality < 0.7;
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = isLow
        ? colorScheme.errorContainer
        : colorScheme.tertiaryContainer;
    final fgColor = isLow
        ? colorScheme.onErrorContainer
        : colorScheme.onTertiaryContainer;
    final icon = isLow ? Icons.warning_amber_rounded : Icons.info_outline;
    final label = isLow
        ? 'Recording quality: poor — output may be approximate'
        : 'Recording quality: fair — some segments were unclear';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: fgColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: fgColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Example WAV assets ────────────────────────────────────────────────────────

enum _ExampleWav {
  sos('SOS (20 WPM)', 'assets/examples/sos_20wpm.wav'),
  alphabet('Alphabet A–Z (20 WPM)', 'assets/examples/alphabet_20wpm.wav'),
  helloWorld('Hello World (20 dB)', 'assets/examples/hello_world_20db.wav'),
  stereoHelloWorld('Stereo Hello World (48k)', 'assets/examples/stereo_hello_world_48k.wav');

  const _ExampleWav(this.label, this.assetPath);
  final String label;
  final String assetPath;
}
