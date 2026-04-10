import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data/settings_repository.dart';
import 'settings_state.dart';

export 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final SettingsRepository _repo;
  final _stt = SpeechToText();
  bool _sttLocalesLoaded = false;

  SettingsCubit(this._repo)
      : super(SettingsState(
          themeMode: _repo.themeMode,
          wpm: _repo.wpm,
          toneFrequency: _repo.toneFrequency,
          sideTone: _repo.sideTone,
          sttLocaleId: _repo.sttLocaleId,
        ));

  Future<void> setThemeMode(ThemeMode mode) async {
    await _repo.setThemeMode(mode);
    emit(state.copyWith(themeMode: mode));
  }

  Future<void> setWpm(int wpm) async {
    await _repo.setWpm(wpm);
    emit(state.copyWith(wpm: wpm));
  }

  Future<void> setToneFrequency(double hz) async {
    await _repo.setToneFrequency(hz);
    emit(state.copyWith(toneFrequency: hz));
  }

  Future<void> setSideTone(bool enabled) async {
    await _repo.setSideTone(enabled);
    emit(state.copyWith(sideTone: enabled));
  }

  Future<void> setSttLocaleId(String localeId) async {
    await _repo.setSttLocaleId(localeId);
    emit(state.copyWith(sttLocaleId: localeId));
  }

  /// Loads the device's available STT locales into state.
  ///
  /// Idempotent — subsequent calls are no-ops once locales are loaded.
  Future<void> loadSttLocales() async {
    if (_sttLocalesLoaded) return;
    _sttLocalesLoaded = true;
    final available = await _stt.initialize();
    if (!available) return;
    final locales = await _stt.locales();
    locales.sort((a, b) => a.name.compareTo(b.name));
    emit(state.copyWith(
      sttLocales: locales
          .map((l) => SttLocale(id: l.localeId, name: l.name))
          .toList(),
    ));
  }

}
