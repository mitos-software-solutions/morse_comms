import 'dart:async';
import 'dart:io' show Platform;

import 'package:golden_toolkit/golden_toolkit.dart';

// Automatically discovered and executed by Flutter's test runner before any
// test file runs. Configures golden_toolkit so every screenMatchesGolden()
// call writes to the correct platform subdirectory without any per-test setup.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await loadAppFonts();

  await GoldenToolkit.runWithConfiguration(
    () async => testMain(),
    config: GoldenToolkitConfiguration(
      fileNameFactory: (name) =>
          'goldens/${Platform.operatingSystem}/$name.png',
    ),
  );
}
