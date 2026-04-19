import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:morse_comms/features/settings/bloc/settings_cubit.dart';
import 'package:morse_comms/features/settings/data/settings_repository.dart';
import 'package:morse_comms/features/settings/data/stt_locale_loader.dart';
import 'package:morse_comms/features/settings/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSttLocaleLoader implements SttLocaleLoader {
  @override
  Future<List<SttLocale>> load() async => [];
}

Future<Widget> _buildApp({bool dark = false}) async {
  SharedPreferences.setMockInitialValues(const {});
  final sp = await SharedPreferences.getInstance();
  final settings = SettingsCubit(
    SettingsRepository(sp),
    localeLoader: _FakeSttLocaleLoader(),
  );

  return BlocProvider<SettingsCubit>.value(
    value: settings,
    child: MaterialApp(
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const SettingsScreen(),
    ),
  );
}

void _setUpPackageInfoChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/package_info'),
    (call) async => {
      'appName': 'Morse Comms',
      'packageName': 'com.mitossoftwaresolutions.morsecomms',
      'version': '1.1.0',
      'buildNumber': '6',
      'buildSignature': '',
      'installerStore': null,
    },
  );
}

void _tearDownPackageInfoChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/package_info'),
    null,
  );
}

void main() {
  setUpAll(_setUpPackageInfoChannel);
  tearDownAll(_tearDownPackageInfoChannel);

  group('SettingsScreen golden', () {
    testGoldens('top section light theme', (tester) async {
      await tester.pumpWidgetBuilder(
        await _buildApp(),
        surfaceSize: const Size(400, 700),
      );
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'settings_screen_top_light');
    });

    testGoldens('top section dark theme', (tester) async {
      await tester.pumpWidgetBuilder(
        await _buildApp(dark: true),
        surfaceSize: const Size(400, 700),
      );
      await tester.pumpAndSettle();
      await screenMatchesGolden(tester, 'settings_screen_top_dark');
    });
  });
}
