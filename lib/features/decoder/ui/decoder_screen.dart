import 'dart:typed_data';

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
        actions: [
          // Load a bundled example WAV
          BlocBuilder<DecoderBloc, DecoderState>(
            buildWhen: (p, c) => p.isListening != c.isListening || p.isAnalyzing != c.isAnalyzing,
            builder: (context, state) {
              final bloc = context.read<DecoderBloc>();
              final busy = state.isListening || state.isAnalyzing;
              return PopupMenuButton<_ExampleWav>(
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
              );
            },
          ),
          // Open a saved WAV file for analysis
          BlocBuilder<DecoderBloc, DecoderState>(
            buildWhen: (p, c) => p.isListening != c.isListening || p.isAnalyzing != c.isAnalyzing,
            builder: (context, state) {
              final bloc = context.read<DecoderBloc>();
              return IconButton(
                icon: const Icon(Icons.folder_open_outlined),
                tooltip: 'Open Recording',
                onPressed: state.isListening || state.isAnalyzing
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
                        bloc.add(DecoderFileAnalysisRequested(bytes, file.name));
                      },
              );
            },
          ),
          // Clear / new recording
          BlocBuilder<DecoderBloc, DecoderState>(
            buildWhen: (p, c) => p.decodedText != c.decodedText || p.status != c.status,
            builder: (context, state) => IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'New Recording',
              onPressed: state.hasResult || state.status == DecoderStatus.idle && state.decodedText.isNotEmpty
                  ? () => context.read<DecoderBloc>().add(DecoderCleared())
                  : null,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Permission denied banner ──────────────────────────────
            BlocBuilder<DecoderBloc, DecoderState>(
              buildWhen: (p, c) => p.permissionDenied != c.permissionDenied,
              builder: (context, state) {
                if (!state.permissionDenied) return const SizedBox.shrink();
                return _Banner(
                  icon: Icons.mic_off,
                  message: 'Microphone permission denied. '
                      'Grant it in Settings → Apps → morse_comms.',
                  color: Theme.of(context).colorScheme.error,
                  background: Theme.of(context).colorScheme.errorContainer,
                  foreground: Theme.of(context).colorScheme.onErrorContainer,
                );
              },
            ),

            // ── Error banner ──────────────────────────────────────────
            BlocBuilder<DecoderBloc, DecoderState>(
              buildWhen: (p, c) => p.errorMessage != c.errorMessage,
              builder: (context, state) {
                final err = state.errorMessage;
                if (err == null) return const SizedBox.shrink();
                return _Banner(
                  icon: Icons.error_outline,
                  message: 'Error: $err',
                  color: Theme.of(context).colorScheme.error,
                  background: Theme.of(context).colorScheme.errorContainer,
                  foreground: Theme.of(context).colorScheme.onErrorContainer,
                );
              },
            ),

            // ── Recording timer + signal meter ────────────────────────
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

            // ── Analyzing spinner ─────────────────────────────────────
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Analyzing recording…',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // ── Saved chip + re-share ─────────────────────────────────
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
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
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

            // ── Decoded text display ──────────────────────────────────
            Expanded(
              child: BlocBuilder<DecoderBloc, DecoderState>(
                buildWhen: (p, c) =>
                    p.decodedText != c.decodedText || p.status != c.status,
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
                                  ? Theme.of(context).colorScheme.outline
                                  : null,
                            ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // ── Button row: Listen / Stop | Play | Save ──────────────
            BlocBuilder<DecoderBloc, DecoderState>(
              buildWhen: (p, c) =>
                  p.status != c.status ||
                  p.savedPath != c.savedPath ||
                  p.audioBytes != c.audioBytes,
              builder: (context, state) {
                final player = context.read<PlayerService>();
                return Row(
                  children: [
                    // Listen / Stop
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: state.isListening
                            ? () => context
                                .read<DecoderBloc>()
                                .add(DecoderStopRequested())
                            : state.isAnalyzing
                                ? null
                                : () => context
                                    .read<DecoderBloc>()
                                    .add(DecoderListenRequested()),
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
                        label: Text(state.isListening
                            ? 'Stop'
                            : state.isAnalyzing
                                ? 'Analyzing…'
                                : state.hasResult
                                    ? 'Record Again'
                                    : 'Listen'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: state.isListening
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ),
                    ),

                    // Play / Stop audio preview
                    if (state.audioBytes != null) ...[
                      const SizedBox(width: 8),
                      _AudioPlayButton(
                        audioBytes: state.audioBytes!,
                        player: player,
                      ),
                    ],

                    // Save to Downloads (Android) / Files app (iOS)
                    if (state.canSave) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showSaveDialog(context),
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Save'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
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
            Icon(isTone ? Icons.graphic_eq : Icons.remove, size: 16, color: color),
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

// ── Audio play/stop button ────────────────────────────────────────────────────

class _AudioPlayButton extends StatefulWidget {
  final Uint8List audioBytes;
  final PlayerService player;

  const _AudioPlayButton({required this.audioBytes, required this.player});

  @override
  State<_AudioPlayButton> createState() => _AudioPlayButtonState();
}

class _AudioPlayButtonState extends State<_AudioPlayButton> {
  bool _isPlaying = false;
  DateTime? _playStarted;
  static const _minPlayMs = 500; // avoid accidental double-tap

  int _estimateDurationMs(Uint8List bytes) {
    if (bytes.length < 44) return 0;
    final bd = ByteData.view(bytes.buffer);
    final byteRate = bd.getUint32(28, Endian.little);
    if (byteRate == 0) return 0;
    return ((bytes.length - 44) * 1000 / byteRate).round();
  }

  Future<void> _play() async {
    if (_isPlaying) return;
    setState(() {
      _isPlaying = true;
      _playStarted = DateTime.now();
    });
    await widget.player.playWav(widget.audioBytes);
    final durationMs = _estimateDurationMs(widget.audioBytes);
    if (durationMs > 0) {
      Future.delayed(Duration(milliseconds: durationMs), () {
        if (mounted && _isPlaying) setState(() => _isPlaying = false);
      });
    }
  }

  Future<void> _stop() async {
    final elapsed = _playStarted == null
        ? _minPlayMs
        : DateTime.now().difference(_playStarted!).inMilliseconds;
    if (elapsed < _minPlayMs) return; // debounce
    await widget.player.stopWav();
    if (mounted) setState(() => _isPlaying = false);
  }

  @override
  void didUpdateWidget(_AudioPlayButton old) {
    super.didUpdateWidget(old);
    if (old.audioBytes != widget.audioBytes && _isPlaying) {
      widget.player.stopWav();
      setState(() => _isPlaying = false);
    }
  }

  @override
  void dispose() {
    if (_isPlaying) widget.player.stopWav();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      icon: Icon(_isPlaying ? Icons.stop_circle_outlined : Icons.play_circle_outline),
      tooltip: _isPlaying ? 'Stop playback' : 'Play audio',
      onPressed: _isPlaying ? _stop : _play,
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(12),
      ),
    );
  }
}

// ── Example WAV assets ────────────────────────────────────────────────────────

enum _ExampleWav {
  sos('SOS (20 WPM)', 'assets/examples/sos_20wpm.wav'),
  paris('PARIS (20 WPM)', 'assets/examples/paris_20wpm.wav'),
  alphabet('Alphabet A–Z (20 WPM)', 'assets/examples/alphabet_20wpm.wav');

  const _ExampleWav(this.label, this.assetPath);
  final String label;
  final String assetPath;
}
