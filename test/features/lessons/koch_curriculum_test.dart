import 'package:flutter_test/flutter_test.dart';
import 'package:morse_comms/features/lessons/data/koch_curriculum.dart';

void main() {
  group('kKochChars', () {
    test('has 36 characters', () {
      expect(kKochChars.length, 36);
    });

    test('starts with K and M', () {
      expect(kKochChars[0], 'K');
      expect(kKochChars[1], 'M');
    });

    test('contains all 26 letters', () {
      final letters = kKochChars.where((c) => c.codeUnitAt(0) >= 65 && c.codeUnitAt(0) <= 90);
      expect(letters.length, 26);
    });

    test('contains digits 0-9', () {
      final digits = kKochChars.where((c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57);
      expect(digits.length, 10);
    });

    test('has no duplicates', () {
      expect(kKochChars.toSet().length, kKochChars.length);
    });
  });

  group('kMinUnlockedCount', () {
    test('is 2', () {
      expect(kMinUnlockedCount, 2);
    });
  });

  group('kKochTotalLevels', () {
    test('is 35 (36 chars - 2 starting + 1)', () {
      expect(kKochTotalLevels, 35);
    });
  });

  group('charsAt()', () {
    test('returns the first N characters', () {
      expect(charsAt(2), ['K', 'M']);
      expect(charsAt(3), ['K', 'M', 'R']);
    });

    test('returns all chars at full count', () {
      expect(charsAt(kKochChars.length).length, kKochChars.length);
    });
  });

  group('kochDisplayLevel()', () {
    test('unlockedCount=2 maps to display level 1', () {
      expect(kochDisplayLevel(2), 1);
    });

    test('unlockedCount=3 maps to display level 2', () {
      expect(kochDisplayLevel(3), 2);
    });

    test('unlockedCount=36 maps to display level 35', () {
      expect(kochDisplayLevel(36), 35);
    });

    test('display level is always unlockedCount - kMinUnlockedCount + 1', () {
      for (int i = kMinUnlockedCount; i <= kKochChars.length; i++) {
        expect(kochDisplayLevel(i), i - kMinUnlockedCount + 1);
      }
    });
  });

  group('levelLabel()', () {
    test('level 1 (unlockedCount=2) shows "Level 1 — K + M"', () {
      expect(levelLabel(2), 'Level 1 — K + M');
    });

    test('unlockedCount=3 shows "Level 2 — + R"', () {
      expect(levelLabel(3), 'Level 2 — + R');
    });

    test('unlockedCount=4 shows "Level 3 — + S"', () {
      expect(levelLabel(4), 'Level 3 — + S');
    });

    test('last level shows correct display level', () {
      final last = kKochChars.length; // 36
      final label = levelLabel(last);
      expect(label, contains('Level 35'));
    });

    test('never shows "Level 2 — Starting pair" (was old bug)', () {
      // The starting pair label only appears on the very first tile
      for (int i = kMinUnlockedCount + 1; i <= kKochChars.length; i++) {
        expect(levelLabel(i), isNot(contains('Starting pair')));
      }
    });

    test('level numbers are sequential starting from 1', () {
      for (int i = kMinUnlockedCount; i <= kKochChars.length; i++) {
        final expected = i - kMinUnlockedCount + 1;
        expect(levelLabel(i), contains('Level $expected'));
      }
    });
  });
}
