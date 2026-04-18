import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:morse_comms/features/settings/bloc/settings_cubit.dart';
import 'package:morse_comms/features/settings/data/settings_repository.dart';
import 'package:morse_comms/features/settings/data/stt_locale_loader.dart';

class _FakeSttLocaleLoader implements SttLocaleLoader {
  final List<SttLocale> locales;
  int callCount = 0;

  _FakeSttLocaleLoader([this.locales = const []]);

  @override
  Future<List<SttLocale>> load() async {
    callCount++;
    return List.of(locales);
  }
}

Future<SettingsCubit> makeCubit([
  Map<String, Object> prefs = const {},
  SttLocaleLoader? localeLoader,
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  return SettingsCubit(
    SettingsRepository(sp),
    localeLoader: localeLoader ?? _FakeSttLocaleLoader(),
  );
}

void main() {
  group('SettingsCubit — initial state', () {
    test('loads defaults when nothing persisted', () async {
      final cubit = await makeCubit();
      expect(cubit.state.themeMode, ThemeMode.system);
      expect(cubit.state.wpm, 20);
      expect(cubit.state.toneFrequency, 600.0);
      expect(cubit.state.sideTone, isFalse);
    });

    test('loads persisted values from SharedPreferences', () async {
      final cubit = await makeCubit({
        'theme_mode': ThemeMode.dark.index,
        'wpm': 15,
        'tone_frequency': 440.0,
        'side_tone': true,
      });
      expect(cubit.state.themeMode, ThemeMode.dark);
      expect(cubit.state.wpm, 15);
      expect(cubit.state.toneFrequency, 440.0);
      expect(cubit.state.sideTone, isTrue);
    });
  });

  group('SettingsCubit — setThemeMode()', () {
    test('emits new themeMode in state', () async {
      final cubit = await makeCubit();
      await cubit.setThemeMode(ThemeMode.light);
      expect(cubit.state.themeMode, ThemeMode.light);
    });

    test('persists themeMode so a new cubit sees it', () async {
      final cubit = await makeCubit();
      await cubit.setThemeMode(ThemeMode.dark);
      final sp = await SharedPreferences.getInstance();
      final repo = SettingsRepository(sp);
      expect(repo.themeMode, ThemeMode.dark);
    });

    test('does not change other fields', () async {
      final cubit = await makeCubit({'wpm': 25});
      await cubit.setThemeMode(ThemeMode.dark);
      expect(cubit.state.wpm, 25);
    });
  });

  group('SettingsCubit — setWpm()', () {
    test('emits new wpm in state', () async {
      final cubit = await makeCubit();
      await cubit.setWpm(30);
      expect(cubit.state.wpm, 30);
    });

    test('persists wpm', () async {
      final cubit = await makeCubit();
      await cubit.setWpm(10);
      final sp = await SharedPreferences.getInstance();
      expect(SettingsRepository(sp).wpm, 10);
    });

    test('does not change other fields', () async {
      final cubit = await makeCubit({'tone_frequency': 800.0});
      await cubit.setWpm(15);
      expect(cubit.state.toneFrequency, 800.0);
    });
  });

  group('SettingsCubit — setToneFrequency()', () {
    test('emits new toneFrequency in state', () async {
      final cubit = await makeCubit();
      await cubit.setToneFrequency(750.0);
      expect(cubit.state.toneFrequency, 750.0);
    });

    test('persists toneFrequency', () async {
      final cubit = await makeCubit();
      await cubit.setToneFrequency(500.0);
      final sp = await SharedPreferences.getInstance();
      expect(SettingsRepository(sp).toneFrequency, 500.0);
    });
  });

  group('SettingsCubit — setSideTone()', () {
    test('emits true when enabled', () async {
      final cubit = await makeCubit();
      await cubit.setSideTone(true);
      expect(cubit.state.sideTone, isTrue);
    });

    test('emits false when disabled', () async {
      final cubit = await makeCubit({'side_tone': true});
      await cubit.setSideTone(false);
      expect(cubit.state.sideTone, isFalse);
    });

    test('persists sideTone', () async {
      final cubit = await makeCubit();
      await cubit.setSideTone(true);
      final sp = await SharedPreferences.getInstance();
      expect(SettingsRepository(sp).sideTone, isTrue);
    });
  });

  group('SettingsCubit — initial sttLocaleId', () {
    test('defaults to en_US when not persisted', () async {
      final cubit = await makeCubit();
      expect(cubit.state.sttLocaleId, 'en_US');
    });

    test('loads persisted sttLocaleId on construction', () async {
      final cubit = await makeCubit({'stt_locale_id': 'ja_JP'});
      expect(cubit.state.sttLocaleId, 'ja_JP');
    });
  });

  group('SettingsCubit — setSttLocaleId()', () {
    test('emits new sttLocaleId in state', () async {
      final cubit = await makeCubit();
      await cubit.setSttLocaleId('de_DE');
      expect(cubit.state.sttLocaleId, 'de_DE');
    });

    test('persists sttLocaleId so a new repo sees it', () async {
      final cubit = await makeCubit();
      await cubit.setSttLocaleId('fr_FR');
      final sp = await SharedPreferences.getInstance();
      expect(SettingsRepository(sp).sttLocaleId, 'fr_FR');
    });

    test('does not change other fields', () async {
      final cubit = await makeCubit({'wpm': 25, 'tone_frequency': 700.0});
      await cubit.setSttLocaleId('es_ES');
      expect(cubit.state.wpm, 25);
      expect(cubit.state.toneFrequency, 700.0);
    });

    test('can be updated multiple times', () async {
      final cubit = await makeCubit();
      await cubit.setSttLocaleId('pt_BR');
      await cubit.setSttLocaleId('zh_CN');
      expect(cubit.state.sttLocaleId, 'zh_CN');
    });
  });

  group('SettingsCubit — loadSttLocales()', () {
    test('emits locales returned by the loader', () async {
      const locales = [
        SttLocale(id: 'en_US', name: 'English (United States)'),
        SttLocale(id: 'el_GR', name: 'Greek (Greece)'),
      ];
      final cubit = await makeCubit({}, _FakeSttLocaleLoader(locales));
      await cubit.loadSttLocales();
      expect(cubit.state.sttLocales, hasLength(2));
      expect(cubit.state.sttLocales[0].id, 'en_US');
      expect(cubit.state.sttLocales[1].id, 'el_GR');
    });

    test('emits nothing when loader returns empty', () async {
      final cubit = await makeCubit({}, _FakeSttLocaleLoader());
      await cubit.loadSttLocales();
      expect(cubit.state.sttLocales, isEmpty);
    });

    test('is idempotent — loader called only once on repeated calls', () async {
      final loader = _FakeSttLocaleLoader(
        [const SttLocale(id: 'en_US', name: 'English')],
      );
      final cubit = await makeCubit({}, loader);
      await cubit.loadSttLocales();
      await cubit.loadSttLocales();
      expect(loader.callCount, 1);
    });

    test('does not change other settings fields when loading locales', () async {
      const locales = [SttLocale(id: 'en_US', name: 'English')];
      final cubit = await makeCubit({'wpm': 25}, _FakeSttLocaleLoader(locales));
      await cubit.loadSttLocales();
      expect(cubit.state.wpm, 25);
    });
  });
}
