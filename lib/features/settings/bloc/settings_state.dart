import 'package:flutter/material.dart';

/// A lightweight locale option surfaced from the device's speech engine.
class SttLocale {
  final String id;
  final String name;
  const SttLocale({required this.id, required this.name});
}

class SettingsState {
  final ThemeMode themeMode;
  final int wpm;
  final double toneFrequency;
  final bool sideTone;
  final String sttLocaleId;
  final List<SttLocale> sttLocales;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.wpm = 20,
    this.toneFrequency = 600.0,
    this.sideTone = false,
    this.sttLocaleId = 'en_US',
    this.sttLocales = const [],
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    int? wpm,
    double? toneFrequency,
    bool? sideTone,
    String? sttLocaleId,
    List<SttLocale>? sttLocales,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      wpm: wpm ?? this.wpm,
      toneFrequency: toneFrequency ?? this.toneFrequency,
      sideTone: sideTone ?? this.sideTone,
      sttLocaleId: sttLocaleId ?? this.sttLocaleId,
      sttLocales: sttLocales ?? this.sttLocales,
    );
  }
}
