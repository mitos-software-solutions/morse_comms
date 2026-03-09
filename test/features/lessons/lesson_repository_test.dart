import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:morse_comms/features/lessons/data/koch_curriculum.dart';
import 'package:morse_comms/features/lessons/data/farnsworth_curriculum.dart';
import 'package:morse_comms/features/lessons/data/lesson_repository.dart';

Future<LessonRepository> makeRepo([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  return LessonRepository(prefs);
}

void main() {
  group('LessonRepository — Koch', () {
    test('unlockedCount defaults to kMinUnlockedCount', () async {
      final repo = await makeRepo();
      expect(repo.unlockedCount, kMinUnlockedCount);
    });

    test('setUnlockedCount persists the new count', () async {
      final repo = await makeRepo();
      await repo.setUnlockedCount(5);
      expect(repo.unlockedCount, 5);
    });

    test('unlockedCount clamps to valid range', () async {
      final repo = await makeRepo({'lesson_unlocked_count': 999});
      expect(repo.unlockedCount, kKochChars.length);
    });

    test('unlockedCount clamps minimum to kMinUnlockedCount', () async {
      final repo = await makeRepo({'lesson_unlocked_count': 0});
      expect(repo.unlockedCount, kMinUnlockedCount);
    });

    test('bestAccuracy returns null when not set', () async {
      final repo = await makeRepo();
      expect(repo.bestAccuracy(2), isNull);
    });

    test('saveBestAccuracy stores value', () async {
      final repo = await makeRepo();
      await repo.saveBestAccuracy(2, 0.8);
      expect(repo.bestAccuracy(2), 0.8);
    });

    test('saveBestAccuracy only updates when new value is higher', () async {
      final repo = await makeRepo();
      await repo.saveBestAccuracy(2, 0.8);
      await repo.saveBestAccuracy(2, 0.6); // lower — should be ignored
      expect(repo.bestAccuracy(2), 0.8);
    });

    test('saveBestAccuracy updates when new value is higher', () async {
      final repo = await makeRepo();
      await repo.saveBestAccuracy(2, 0.7);
      await repo.saveBestAccuracy(2, 0.95);
      expect(repo.bestAccuracy(2), 0.95);
    });

    test('loadAllBestAccuracy returns all saved entries', () async {
      final repo = await makeRepo();
      await repo.saveBestAccuracy(2, 0.8);
      await repo.saveBestAccuracy(3, 0.9);
      final all = repo.loadAllBestAccuracy();
      expect(all[2], 0.8);
      expect(all[3], 0.9);
    });

    test('loadAllBestAccuracy returns empty map when nothing saved', () async {
      final repo = await makeRepo();
      expect(repo.loadAllBestAccuracy(), isEmpty);
    });
  });

  group('LessonRepository — Farnsworth', () {
    test('farnsworthLevelIndex defaults to 0', () async {
      final repo = await makeRepo();
      expect(repo.farnsworthLevelIndex, 0);
    });

    test('setFarnsworthLevelIndex persists the new index', () async {
      final repo = await makeRepo();
      await repo.setFarnsworthLevelIndex(3);
      expect(repo.farnsworthLevelIndex, 3);
    });

    test('farnsworthLevelIndex clamps to valid range', () async {
      final repo = await makeRepo({'farnsworth_level_index': 999});
      expect(repo.farnsworthLevelIndex, kFarnsworthLevels.length - 1);
    });

    test('farnsworthBestAccuracy returns null when not set', () async {
      final repo = await makeRepo();
      expect(repo.farnsworthBestAccuracy(0), isNull);
    });

    test('saveFarnsworthBestAccuracy stores value', () async {
      final repo = await makeRepo();
      await repo.saveFarnsworthBestAccuracy(0, 0.75);
      expect(repo.farnsworthBestAccuracy(0), 0.75);
    });

    test('saveFarnsworthBestAccuracy only updates when higher', () async {
      final repo = await makeRepo();
      await repo.saveFarnsworthBestAccuracy(0, 0.9);
      await repo.saveFarnsworthBestAccuracy(0, 0.5);
      expect(repo.farnsworthBestAccuracy(0), 0.9);
    });

    test('loadAllFarnsworthBestAccuracy returns all saved entries', () async {
      final repo = await makeRepo();
      await repo.saveFarnsworthBestAccuracy(0, 0.8);
      await repo.saveFarnsworthBestAccuracy(2, 0.95);
      final all = repo.loadAllFarnsworthBestAccuracy();
      expect(all[0], 0.8);
      expect(all[2], 0.95);
    });

    test('loadAllFarnsworthBestAccuracy returns empty map when nothing saved', () async {
      final repo = await makeRepo();
      expect(repo.loadAllFarnsworthBestAccuracy(), isEmpty);
    });
  });
}
