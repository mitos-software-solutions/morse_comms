import '../data/koch_curriculum.dart';

/// One round inside a drill session.
class DrillRound {
  final String prompt; // e.g. "KMRSK" — what was played
  final String? answer; // what the user typed (null = not yet answered)
  final int? correct; // char-level correct count

  const DrillRound({required this.prompt, this.answer, this.correct});

  double? get accuracy =>
      answer == null ? null : (correct ?? 0) / prompt.length;

  DrillRound copyWith({String? answer, int? correct}) => DrillRound(
        prompt: prompt,
        answer: answer ?? this.answer,
        correct: correct ?? this.correct,
      );
}

class LessonState {
  /// How many Koch characters are currently unlocked (2 … kKochChars.length).
  final int unlockedCount;

  /// Best session accuracy per unlockedCount level.
  final Map<int, double> bestAccuracy;

  // --- Drill session (null = no active session) ---
  final List<DrillRound>? rounds;
  final int currentRound;

  const LessonState({
    required this.unlockedCount,
    required this.bestAccuracy,
    this.rounds,
    this.currentRound = 0,
  });

  bool get inSession => rounds != null;

  bool get sessionComplete =>
      rounds != null && currentRound >= rounds!.length;

  /// Mean accuracy across all answered rounds (0.0–1.0).
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
      unlockedCount < kKochChars.length;

  DrillRound? get currentRoundData =>
      (rounds != null && currentRound < rounds!.length)
          ? rounds![currentRound]
          : null;

  LessonState copyWith({
    int? unlockedCount,
    Map<int, double>? bestAccuracy,
    List<DrillRound>? Function()? rounds,
    int? currentRound,
  }) {
    return LessonState(
      unlockedCount: unlockedCount ?? this.unlockedCount,
      bestAccuracy: bestAccuracy ?? this.bestAccuracy,
      rounds: rounds != null ? rounds() : this.rounds,
      currentRound: currentRound ?? this.currentRound,
    );
  }
}
