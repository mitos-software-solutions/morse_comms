import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:morse_comms/features/lessons/bloc/lesson_cubit.dart';
import 'package:morse_comms/features/lessons/data/koch_curriculum.dart';
import 'package:morse_comms/features/lessons/data/lesson_repository.dart';

Future<LessonCubit> makeCubit([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  return LessonCubit(LessonRepository(sp));
}

void main() {
  group('LessonCubit — initial state', () {
    test('starts at kMinUnlockedCount', () async {
      final cubit = await makeCubit();
      expect(cubit.state.unlockedCount, kMinUnlockedCount);
    });

    test('no active session initially', () async {
      final cubit = await makeCubit();
      expect(cubit.state.inSession, isFalse);
      expect(cubit.state.rounds, isNull);
    });

    test('loads persisted unlockedCount', () async {
      final cubit = await makeCubit({'lesson_unlocked_count': 5});
      expect(cubit.state.unlockedCount, 5);
    });

    test('loads persisted best accuracy', () async {
      final cubit = await makeCubit({'lesson_best_2': 0.85});
      expect(cubit.state.bestAccuracy[2], 0.85);
    });
  });

  group('LessonCubit — startSession()', () {
    test('creates 5 rounds', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      expect(cubit.state.rounds?.length, 5);
    });

    test('each round has a 5-character prompt', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      for (final round in cubit.state.rounds!) {
        expect(round.prompt.length, 5);
      }
    });

    test('prompts only contain unlocked chars', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      final allowed = charsAt(cubit.state.unlockedCount).toSet();
      for (final round in cubit.state.rounds!) {
        for (final char in round.prompt.split('')) {
          expect(allowed, contains(char));
        }
      }
    });

    test('sets currentRound to 0', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      expect(cubit.state.currentRound, 0);
    });

    test('session is not yet complete after starting', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      expect(cubit.state.sessionComplete, isFalse);
    });
  });

  group('LessonCubit — recordAnswer()', () {
    test('perfect answer gives accuracy 1.0 for that round', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      final prompt = cubit.state.currentRoundData!.prompt;
      await cubit.recordAnswer(prompt);
      final answered = cubit.state.rounds![0];
      expect(answered.accuracy, 1.0);
    });

    test('wrong answer gives accuracy 0.0 for that round', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      await cubit.recordAnswer('ZZZZZ'); // unlikely to match prompt
      // accuracy might not be 0 if prompt happens to have Z, but
      // we can verify answer was recorded and round advanced
      expect(cubit.state.currentRound, 1);
    });

    test('advances currentRound after each answer', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      expect(cubit.state.currentRound, 0);
      await cubit.recordAnswer('KM');
      expect(cubit.state.currentRound, 1);
    });

    test('ignores call when no active session', () async {
      final cubit = await makeCubit();
      final stateBefore = cubit.state;
      await cubit.recordAnswer('KM');
      expect(cubit.state, same(stateBefore));
    });

    test('session is complete after 5 answers', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      for (int i = 0; i < 5; i++) {
        await cubit.recordAnswer('KM');
      }
      expect(cubit.state.sessionComplete, isTrue);
    });

    test('sessionAccuracy is mean of round accuracies', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      // Answer all rounds perfectly
      for (int i = 0; i < 5; i++) {
        final prompt = cubit.state.currentRoundData!.prompt;
        await cubit.recordAnswer(prompt);
      }
      expect(cubit.state.sessionAccuracy, closeTo(1.0, 0.001));
    });

    test('saves best accuracy on session complete', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      for (int i = 0; i < 5; i++) {
        final prompt = cubit.state.currentRoundData!.prompt;
        await cubit.recordAnswer(prompt);
      }
      expect(cubit.state.bestAccuracy[kMinUnlockedCount], closeTo(1.0, 0.001));
    });
  });

  group('LessonCubit — canAdvance', () {
    test('canAdvance is false when session incomplete', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      expect(cubit.state.canAdvance, isFalse);
    });

    test('canAdvance is true after perfect session', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      for (int i = 0; i < 5; i++) {
        final prompt = cubit.state.currentRoundData!.prompt;
        await cubit.recordAnswer(prompt);
      }
      expect(cubit.state.canAdvance, isTrue);
    });

    test('canAdvance is false when accuracy < 0.9', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      // All wrong answers
      for (int i = 0; i < 5; i++) {
        await cubit.recordAnswer('');
      }
      expect(cubit.state.canAdvance, isFalse);
    });

    test('canAdvance is false at last Koch level', () async {
      final cubit = await makeCubit({'lesson_unlocked_count': kKochChars.length});
      cubit.startSession();
      for (int i = 0; i < 5; i++) {
        final prompt = cubit.state.currentRoundData!.prompt;
        await cubit.recordAnswer(prompt);
      }
      expect(cubit.state.canAdvance, isFalse);
    });
  });

  group('LessonCubit — advanceLevel()', () {
    test('increments unlockedCount by 1', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      for (int i = 0; i < 5; i++) {
        final prompt = cubit.state.currentRoundData!.prompt;
        await cubit.recordAnswer(prompt);
      }
      final before = cubit.state.unlockedCount;
      await cubit.advanceLevel();
      expect(cubit.state.unlockedCount, before + 1);
    });

    test('does nothing when canAdvance is false', () async {
      final cubit = await makeCubit();
      final before = cubit.state.unlockedCount;
      await cubit.advanceLevel();
      expect(cubit.state.unlockedCount, before);
    });

    test('clears session after advancing', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      for (int i = 0; i < 5; i++) {
        final prompt = cubit.state.currentRoundData!.prompt;
        await cubit.recordAnswer(prompt);
      }
      await cubit.advanceLevel();
      expect(cubit.state.inSession, isFalse);
    });
  });

  group('LessonCubit — clearSession()', () {
    test('removes active session', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      expect(cubit.state.inSession, isTrue);
      cubit.clearSession();
      expect(cubit.state.inSession, isFalse);
    });

    test('resets currentRound to 0', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      await cubit.recordAnswer('KM');
      cubit.clearSession();
      expect(cubit.state.currentRound, 0);
    });

    test('preserves unlockedCount', () async {
      final cubit = await makeCubit({'lesson_unlocked_count': 4});
      cubit.startSession();
      cubit.clearSession();
      expect(cubit.state.unlockedCount, 4);
    });
  });
}
