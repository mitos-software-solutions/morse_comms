import 'package:shared_preferences/shared_preferences.dart';

import 'farnsworth_curriculum.dart';
import 'koch_curriculum.dart';

class LessonRepository {
  static const _keyUnlockedCount = 'lesson_unlocked_count';
  static const _keyBestPrefix = 'lesson_best_';

  // Farnsworth keys
  static const _keyFarnsworthLevelIndex = 'farnsworth_level_index';
  static const _keyFarnsworthBestPrefix = 'farnsworth_best_';

  final SharedPreferences _prefs;

  LessonRepository(this._prefs);

  // ---------------------------------------------------------------------------
  // Koch progress
  // ---------------------------------------------------------------------------

  int get unlockedCount =>
      (_prefs.getInt(_keyUnlockedCount) ?? kMinUnlockedCount)
          .clamp(kMinUnlockedCount, kKochChars.length);

  Future<void> setUnlockedCount(int count) =>
      _prefs.setInt(_keyUnlockedCount, count);

  double? bestAccuracy(int unlockedCount) {
    final v = _prefs.getDouble('$_keyBestPrefix$unlockedCount');
    return v;
  }

  Future<void> saveBestAccuracy(int unlockedCount, double accuracy) async {
    final existing = bestAccuracy(unlockedCount) ?? 0.0;
    if (accuracy > existing) {
      await _prefs.setDouble('$_keyBestPrefix$unlockedCount', accuracy);
    }
  }

  Map<int, double> loadAllBestAccuracy() {
    final result = <int, double>{};
    for (int i = kMinUnlockedCount; i <= kKochChars.length; i++) {
      final v = bestAccuracy(i);
      if (v != null) result[i] = v;
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Farnsworth progress
  // ---------------------------------------------------------------------------

  int get farnsworthLevelIndex =>
      (_prefs.getInt(_keyFarnsworthLevelIndex) ?? 0)
          .clamp(0, kFarnsworthLevels.length - 1);

  Future<void> setFarnsworthLevelIndex(int index) =>
      _prefs.setInt(_keyFarnsworthLevelIndex, index);

  double? farnsworthBestAccuracy(int levelIndex) =>
      _prefs.getDouble('$_keyFarnsworthBestPrefix$levelIndex');

  Future<void> saveFarnsworthBestAccuracy(int levelIndex, double accuracy) async {
    final existing = farnsworthBestAccuracy(levelIndex) ?? 0.0;
    if (accuracy > existing) {
      await _prefs.setDouble('$_keyFarnsworthBestPrefix$levelIndex', accuracy);
    }
  }

  Map<int, double> loadAllFarnsworthBestAccuracy() {
    final result = <int, double>{};
    for (int i = 0; i < kFarnsworthLevels.length; i++) {
      final v = farnsworthBestAccuracy(i);
      if (v != null) result[i] = v;
    }
    return result;
  }
}
