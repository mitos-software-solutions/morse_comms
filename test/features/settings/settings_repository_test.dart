import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:morse_comms/features/settings/data/settings_repository.dart';

Future<SettingsRepository> makeRepo([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  return SettingsRepository(prefs);
}

void main() {
  group('SettingsRepository — theme mode', () {
    test('defaults to ThemeMode.system', () async {
      final repo = await makeRepo();
      expect(repo.themeMode, ThemeMode.system);
    });

    test('setThemeMode persists light', () async {
      final repo = await makeRepo();
      await repo.setThemeMode(ThemeMode.light);
      expect(repo.themeMode, ThemeMode.light);
    });

    test('setThemeMode persists dark', () async {
      final repo = await makeRepo();
      await repo.setThemeMode(ThemeMode.dark);
      expect(repo.themeMode, ThemeMode.dark);
    });

    test('loads persisted theme mode', () async {
      // ThemeMode.dark.index == 2
      final repo = await makeRepo({'theme_mode': ThemeMode.dark.index});
      expect(repo.themeMode, ThemeMode.dark);
    });
  });

  group('SettingsRepository — WPM', () {
    test('defaults to 20 WPM', () async {
      final repo = await makeRepo();
      expect(repo.wpm, 20);
    });

    test('setWpm persists value', () async {
      final repo = await makeRepo();
      await repo.setWpm(15);
      expect(repo.wpm, 15);
    });

    test('loads persisted WPM', () async {
      final repo = await makeRepo({'wpm': 30});
      expect(repo.wpm, 30);
    });
  });

  group('SettingsRepository — tone frequency', () {
    test('defaults to 600.0 Hz', () async {
      final repo = await makeRepo();
      expect(repo.toneFrequency, 600.0);
    });

    test('setToneFrequency persists value', () async {
      final repo = await makeRepo();
      await repo.setToneFrequency(750.0);
      expect(repo.toneFrequency, 750.0);
    });

    test('loads persisted frequency', () async {
      final repo = await makeRepo({'tone_frequency': 400.0});
      expect(repo.toneFrequency, 400.0);
    });
  });

  group('SettingsRepository — side-tone', () {
    test('defaults to false', () async {
      final repo = await makeRepo();
      expect(repo.sideTone, isFalse);
    });

    test('setSideTone persists true', () async {
      final repo = await makeRepo();
      await repo.setSideTone(true);
      expect(repo.sideTone, isTrue);
    });

    test('setSideTone persists false after being set to true', () async {
      final repo = await makeRepo({'side_tone': true});
      await repo.setSideTone(false);
      expect(repo.sideTone, isFalse);
    });
  });

}
