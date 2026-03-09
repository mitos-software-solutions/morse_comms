/// Koch method character order (letters + digits only).
///
/// The Koch method starts with the two most distinct characters (K and M)
/// at full target speed, then adds one character at a time as you reach
/// 90% accuracy on the current set.
const List<String> kKochChars = [
  // Core letters — most distinct sound profiles
  'K', 'M', 'R', 'S', 'U', 'A', 'P', 'T', 'L', 'O',
  'W', 'I', 'N', 'J', 'E', 'F', 'Y', 'V', 'G', 'Q',
  'Z', 'H', 'B', 'C', 'D', 'X',
  // Digits
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
];

/// Number of Koch characters available for free (no premium required).
const int kFreeKochLevels = 5; // K M R S U

/// Minimum unlocked count (always start with the first 2 chars).
const int kMinUnlockedCount = 2;

/// Returns the set of characters unlocked at [unlockedCount].
List<String> charsAt(int unlockedCount) =>
    kKochChars.take(unlockedCount).toList();

/// Total number of Koch levels (Level 1 = kMinUnlockedCount chars, last = all 36).
int get kKochTotalLevels => kKochChars.length - kMinUnlockedCount + 1;

/// Converts an [unlockedCount] (2…36) to a 1-based display level number.
int kochDisplayLevel(int unlockedCount) =>
    unlockedCount - kMinUnlockedCount + 1;

/// Returns a human-readable label for a lesson, e.g. "Level 2 — + R".
String levelLabel(int unlockedCount) {
  if (unlockedCount == kMinUnlockedCount) {
    return 'Level 1 — ${kKochChars[0]} + ${kKochChars[1]}';
  }
  final display = kochDisplayLevel(unlockedCount);
  final newChar = kKochChars[unlockedCount - 1];
  return 'Level $display — + $newChar';
}
