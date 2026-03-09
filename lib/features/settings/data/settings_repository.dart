import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  static const _keyThemeMode = 'theme_mode';
  static const _keyWpm = 'wpm';
  static const _keyToneFrequency = 'tone_frequency';
  static const _keySideTone = 'side_tone';
  static const _keyIsPremium = 'is_premium';
  static const _keySttLocaleId = 'stt_locale_id';

  final SharedPreferences _prefs;

  SettingsRepository(this._prefs);

  // --- Theme ---
  ThemeMode get themeMode {
    final index = _prefs.getInt(_keyThemeMode) ?? ThemeMode.system.index;
    return ThemeMode.values[index];
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setInt(_keyThemeMode, mode.index);

  // --- WPM (5–40, default 20) ---
  int get wpm => _prefs.getInt(_keyWpm) ?? 20;

  Future<void> setWpm(int wpm) => _prefs.setInt(_keyWpm, wpm);

  // --- Tone frequency in Hz (400–900, default 600) ---
  double get toneFrequency => _prefs.getDouble(_keyToneFrequency) ?? 600.0;

  Future<void> setToneFrequency(double hz) =>
      _prefs.setDouble(_keyToneFrequency, hz);

  // --- Side-tone during decode ---
  bool get sideTone => _prefs.getBool(_keySideTone) ?? false;

  Future<void> setSideTone(bool enabled) =>
      _prefs.setBool(_keySideTone, enabled);

  // --- Premium ---
  bool get isPremium => _prefs.getBool(_keyIsPremium) ?? false;

  Future<void> setPremium(bool value) => _prefs.setBool(_keyIsPremium, value);

  // --- STT locale (BCP-47 locale id, e.g. 'en_US') ---
  String get sttLocaleId => _prefs.getString(_keySttLocaleId) ?? 'en_US';

  Future<void> setSttLocaleId(String localeId) =>
      _prefs.setString(_keySttLocaleId, localeId);
}
