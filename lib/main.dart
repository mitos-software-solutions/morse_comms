import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/di.dart';
import 'features/lessons/data/lesson_repository.dart';
import 'features/player/player_service.dart';
import 'features/settings/bloc/settings_cubit.dart';
import 'features/settings/data/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();

  final player = PlayerService();
  try {
    await player.init();
  } catch (_) {
    // Audio unavailable (e.g. headless CI emulator) — app runs without sound.
  }

  final prefs = await SharedPreferences.getInstance();
  final settingsCubit = SettingsCubit(SettingsRepository(prefs));
  final lessonRepository = LessonRepository(prefs);

  runApp(MorseCommsApp(
    playerService: player,
    settingsCubit: settingsCubit,
    lessonRepository: lessonRepository,
  ));
}
