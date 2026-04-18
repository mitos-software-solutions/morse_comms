import 'package:speech_to_text/speech_to_text.dart';

import '../bloc/settings_state.dart';

abstract class SttLocaleLoader {
  Future<List<SttLocale>> load();
}

/// Production implementation — delegates to the device's speech engine.
class SttLocaleLoaderImpl implements SttLocaleLoader {
  final _stt = SpeechToText();

  @override
  Future<List<SttLocale>> load() async {
    final available = await _stt.initialize();
    if (!available) return [];
    final locales = await _stt.locales();
    locales.sort((a, b) => a.name.compareTo(b.name));
    return locales.map((l) => SttLocale(id: l.localeId, name: l.name)).toList();
  }
}
