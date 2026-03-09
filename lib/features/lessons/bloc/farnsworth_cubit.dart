import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/farnsworth_curriculum.dart';
import '../data/lesson_repository.dart';
import 'lesson_state.dart';

export 'lesson_state.dart' show DrillRound;

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class FarnsworthState {
  /// 0-indexed into [kFarnsworthLevels].
  final int levelIndex;

  /// Best session accuracy per level index.
  final Map<int, double> bestAccuracy;

  // --- Drill session (null = no active session) ---
  final List<DrillRound>? rounds;
  final int currentRound;

  const FarnsworthState({
    required this.levelIndex,
    required this.bestAccuracy,
    this.rounds,
    this.currentRound = 0,
  });

  FarnsworthLevel get level => kFarnsworthLevels[levelIndex];

  bool get inSession => rounds != null;

  bool get sessionComplete =>
      rounds != null && currentRound >= rounds!.length;

  double get sessionAccuracy {
    if (rounds == null) return 0;
    final answered = rounds!.where((r) => r.accuracy != null).toList();
    if (answered.isEmpty) return 0;
    return answered.map((r) => r.accuracy!).reduce((a, b) => a + b) /
        answered.length;
  }

  bool get canAdvance =>
      sessionComplete &&
      sessionAccuracy >= 0.9 &&
      levelIndex < kFarnsworthLevels.length - 1;

  DrillRound? get currentRoundData =>
      (rounds != null && currentRound < rounds!.length)
          ? rounds![currentRound]
          : null;

  FarnsworthState copyWith({
    int? levelIndex,
    Map<int, double>? bestAccuracy,
    List<DrillRound>? Function()? rounds,
    int? currentRound,
  }) {
    return FarnsworthState(
      levelIndex: levelIndex ?? this.levelIndex,
      bestAccuracy: bestAccuracy ?? this.bestAccuracy,
      rounds: rounds != null ? rounds() : this.rounds,
      currentRound: currentRound ?? this.currentRound,
    );
  }
}

// ---------------------------------------------------------------------------
// Cubit
// ---------------------------------------------------------------------------

const _farnsworthRoundsPerSession = 5;
const _farnsworthCharsPerRound = 5;

class FarnsworthCubit extends Cubit<FarnsworthState> {
  final LessonRepository _repo;
  final _rng = Random();

  FarnsworthCubit(this._repo)
      : super(FarnsworthState(
          levelIndex: _repo.farnsworthLevelIndex,
          bestAccuracy: _repo.loadAllFarnsworthBestAccuracy(),
        ));

  /// Start a new drill session for the current level using all 36 chars.
  void startSession() {
    final rounds = List.generate(
      _farnsworthRoundsPerSession,
      (_) => DrillRound(prompt: _randomPrompt()),
    );
    emit(state.copyWith(rounds: () => rounds, currentRound: 0));
  }

  /// Score the user's answer for the current round and advance.
  Future<void> recordAnswer(String rawInput) async {
    final round = state.currentRoundData;
    if (round == null) return;

    final input = rawInput.trim().toUpperCase();
    final prompt = round.prompt;
    int correct = 0;
    for (int i = 0; i < min(input.length, prompt.length); i++) {
      if (input[i] == prompt[i]) correct++;
    }

    final updatedRounds = List<DrillRound>.from(state.rounds!);
    updatedRounds[state.currentRound] =
        round.copyWith(answer: input, correct: correct);

    final nextRound = state.currentRound + 1;
    final updated = state.copyWith(
      rounds: () => updatedRounds,
      currentRound: nextRound,
    );
    emit(updated);

    if (updated.sessionComplete) {
      final acc = updated.sessionAccuracy;
      await _repo.saveFarnsworthBestAccuracy(state.levelIndex, acc);
      final newBest = Map<int, double>.from(state.bestAccuracy);
      final existing = newBest[state.levelIndex] ?? 0;
      if (acc > existing) newBest[state.levelIndex] = acc;
      emit(updated.copyWith(bestAccuracy: newBest));
    }
  }

  /// Unlock the next Farnsworth level and reset the session.
  Future<void> advanceLevel() async {
    if (!state.canAdvance) return;
    final next = state.levelIndex + 1;
    await _repo.setFarnsworthLevelIndex(next);
    emit(FarnsworthState(
      levelIndex: next,
      bestAccuracy: Map.from(state.bestAccuracy),
    ));
  }

  /// Dismiss the current session without advancing.
  void clearSession() {
    emit(state.copyWith(rounds: () => null, currentRound: 0));
  }

  // ---------------------------------------------------------------------------

  String _randomPrompt() {
    return List.generate(
      _farnsworthCharsPerRound,
      (_) => kFarnsworthChars[_rng.nextInt(kFarnsworthChars.length)],
    ).join();
  }
}
