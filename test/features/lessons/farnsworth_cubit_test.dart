import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:morse_comms/features/lessons/bloc/farnsworth_cubit.dart';
import 'package:morse_comms/features/lessons/data/farnsworth_curriculum.dart';
import 'package:morse_comms/features/lessons/data/lesson_repository.dart';

Future<FarnsworthCubit> makeCubit([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  return FarnsworthCubit(LessonRepository(sp));
}

void main() {
  group('FarnsworthCubit — initial state', () {
    test('starts at levelIndex 0', () async {
      final cubit = await makeCubit();
      expect(cubit.state.levelIndex, 0);
    });

    test('no active session initially', () async {
      final cubit = await makeCubit();
      expect(cubit.state.inSession, isFalse);
    });

    test('loads persisted levelIndex', () async {
      final cubit = await makeCubit({'farnsworth_level_index': 3});
      expect(cubit.state.levelIndex, 3);
    });

    test('loads persisted best accuracy', () async {
      final cubit = await makeCubit({'farnsworth_best_0': 0.75});
      expect(cubit.state.bestAccuracy[0], 0.75);
    });

    test('level getter returns correct FarnsworthLevel', () async {
      final cubit = await makeCubit({'farnsworth_level_index': 2});
      expect(cubit.state.level, kFarnsworthLevels[2]);
    });
  });

  group('FarnsworthCubit — startSession()', () {
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

    test('prompts only use the full 36-character Farnsworth set', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      final allowed = kFarnsworthChars.toSet();
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
  });

  group('FarnsworthCubit — recordAnswer()', () {
    test('perfect answer gives accuracy 1.0', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      final prompt = cubit.state.currentRoundData!.prompt;
      await cubit.recordAnswer(prompt);
      expect(cubit.state.rounds![0].accuracy, 1.0);
    });

    test('advances currentRound after answer', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      await cubit.recordAnswer('A');
      expect(cubit.state.currentRound, 1);
    });

    test('session is complete after 5 answers', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      for (int i = 0; i < 5; i++) {
        await cubit.recordAnswer('A');
      }
      expect(cubit.state.sessionComplete, isTrue);
    });

    test('saves best accuracy on session complete', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      for (int i = 0; i < 5; i++) {
        final prompt = cubit.state.currentRoundData!.prompt;
        await cubit.recordAnswer(prompt);
      }
      expect(cubit.state.bestAccuracy[0], closeTo(1.0, 0.001));
    });

    test('does not lower an existing best accuracy', () async {
      final cubit = await makeCubit({'farnsworth_best_0': 0.95});
      cubit.startSession();
      for (int i = 0; i < 5; i++) {
        await cubit.recordAnswer(''); // all wrong → 0.0 accuracy
      }
      expect(cubit.state.bestAccuracy[0], 0.95);
    });

    test('ignores call when no active session', () async {
      final cubit = await makeCubit();
      final before = cubit.state;
      await cubit.recordAnswer('A');
      expect(cubit.state, same(before));
    });
  });

  group('FarnsworthCubit — canAdvance', () {
    test('false when session is incomplete', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      expect(cubit.state.canAdvance, isFalse);
    });

    test('true after perfect session on non-final level', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      for (int i = 0; i < 5; i++) {
        final prompt = cubit.state.currentRoundData!.prompt;
        await cubit.recordAnswer(prompt);
      }
      expect(cubit.state.canAdvance, isTrue);
    });

    test('false at the last Farnsworth level even with perfect score', () async {
      final lastIndex = kFarnsworthLevels.length - 1;
      final cubit = await makeCubit({'farnsworth_level_index': lastIndex});
      cubit.startSession();
      for (int i = 0; i < 5; i++) {
        final prompt = cubit.state.currentRoundData!.prompt;
        await cubit.recordAnswer(prompt);
      }
      expect(cubit.state.canAdvance, isFalse);
    });

    test('false when accuracy < 0.9', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      for (int i = 0; i < 5; i++) {
        await cubit.recordAnswer('');
      }
      expect(cubit.state.canAdvance, isFalse);
    });
  });

  group('FarnsworthCubit — advanceLevel()', () {
    test('increments levelIndex by 1', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      for (int i = 0; i < 5; i++) {
        final prompt = cubit.state.currentRoundData!.prompt;
        await cubit.recordAnswer(prompt);
      }
      await cubit.advanceLevel();
      expect(cubit.state.levelIndex, 1);
    });

    test('does nothing when canAdvance is false', () async {
      final cubit = await makeCubit();
      await cubit.advanceLevel();
      expect(cubit.state.levelIndex, 0);
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

  group('FarnsworthCubit — clearSession()', () {
    test('removes active session', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      cubit.clearSession();
      expect(cubit.state.inSession, isFalse);
    });

    test('resets currentRound to 0', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      await cubit.recordAnswer('A');
      cubit.clearSession();
      expect(cubit.state.currentRound, 0);
    });

    test('preserves levelIndex', () async {
      final cubit = await makeCubit({'farnsworth_level_index': 4});
      cubit.startSession();
      cubit.clearSession();
      expect(cubit.state.levelIndex, 4);
    });
  });

  group('FarnsworthCubit — sessionAccuracy', () {
    test('is 0 when no session', () async {
      final cubit = await makeCubit();
      expect(cubit.state.sessionAccuracy, 0.0);
    });

    test('is 0 when no rounds answered yet', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      expect(cubit.state.sessionAccuracy, 0.0);
    });

    test('is mean accuracy across all answered rounds', () async {
      final cubit = await makeCubit();
      cubit.startSession();
      // Answer first round perfectly, rest with empty string
      final prompt = cubit.state.currentRoundData!.prompt;
      await cubit.recordAnswer(prompt); // 1.0
      for (int i = 1; i < 5; i++) {
        await cubit.recordAnswer(''); // 0.0
      }
      // Mean = (1.0 + 0 + 0 + 0 + 0) / 5 = 0.2
      expect(cubit.state.sessionAccuracy, closeTo(0.2, 0.001));
    });
  });
}
