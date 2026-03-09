import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/koch_curriculum.dart';
import '../data/lesson_repository.dart';
import 'lesson_state.dart';

export 'lesson_state.dart';

const _roundsPerSession = 5;
const _charsPerRound = 5;

class LessonCubit extends Cubit<LessonState> {
  final LessonRepository _repo;
  final _rng = Random();

  LessonCubit(this._repo)
      : super(LessonState(
          unlockedCount: _repo.unlockedCount,
          bestAccuracy: _repo.loadAllBestAccuracy(),
        ));

  /// Start a new drill session for the current unlocked set.
  void startSession() {
    final chars = charsAt(state.unlockedCount);
    final rounds = List.generate(
      _roundsPerSession,
      (_) => DrillRound(prompt: _randomPrompt(chars)),
    );
    emit(state.copyWith(
      rounds: () => rounds,
      currentRound: 0,
    ));
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

    // Persist best accuracy when session is complete.
    if (updated.sessionComplete) {
      final acc = updated.sessionAccuracy;
      await _repo.saveBestAccuracy(state.unlockedCount, acc);
      final newBest = Map<int, double>.from(state.bestAccuracy);
      final existing = newBest[state.unlockedCount] ?? 0;
      if (acc > existing) newBest[state.unlockedCount] = acc;
      emit(updated.copyWith(bestAccuracy: newBest));
    }
  }

  /// Unlock the next Koch character and reset the session.
  Future<void> advanceLevel() async {
    if (!state.canAdvance) return;
    final next = state.unlockedCount + 1;
    await _repo.setUnlockedCount(next);
    emit(LessonState(
      unlockedCount: next,
      bestAccuracy: Map.from(state.bestAccuracy),
    ));
  }

  /// Dismiss the current session without advancing.
  void clearSession() {
    emit(state.copyWith(rounds: () => null, currentRound: 0));
  }

  // ---------------------------------------------------------------------------

  String _randomPrompt(List<String> chars) {
    return List.generate(
      _charsPerRound,
      (_) => chars[_rng.nextInt(chars.length)],
    ).join();
  }
}
