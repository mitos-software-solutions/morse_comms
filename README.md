# Morse Comms

[![Tests](https://github.com/mitos-software-solutions/morse_comms/actions/workflows/test.yml/badge.svg)](https://github.com/mitos-software-solutions/morse_comms/actions/workflows/test.yml)
[![Coverage](https://codecov.io/gh/mitos-software-solutions/morse_comms/branch/main/graph/badge.svg)](https://app.codecov.io/gh/mitos-software-solutions/morse_comms)
![Platform](https://img.shields.io/badge/platform-Android-blue)
![Platform](https://img.shields.io/badge/platform-iOS-lightgrey)
![License](https://img.shields.io/badge/license-MIT-blue)

Prepper-focused Morse code app — fully offline, free, useful for survival and learning.
- See [ARCHITECTURE.md](ARCHITECTURE.md) for design decisions.
- See [CONTRIBUTING.md](CONTRIBUTING.md) for how to set up your dev environment and submit changes.
- See [TESTING.md](TESTING.md) for the testing strategy and test layers.


## Build

**Release AAB (for Play Store upload):**
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```
Requires `android/key.properties` with signing credentials (gitignored — see a maintainer).

**Debug APK (fast, no signing needed):**
```bash
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk
```

**Release APK (optimised, requires signing config):**
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

**Install to connected device/emulator after build:**
```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.mitossoftwaresolutions.morsecomms/.MainActivity
```

## Testing the app

Run the Flutter test suite:
```bash
flutter test
```

## Static analysis

Run the analyser with info-level checks enforced (zero warnings/infos allowed):
```bash
flutter analyze
```

This is the same command run in CI. All code merged to `main` must pass cleanly.

## Running on Android emulator

**Full dev mode (hot reload):**
```bash
flutter run -d emulator-5554
```

**Quick relaunch (APK already installed):**
```bash
adb shell am start -n com.mitossoftwaresolutions.morsecomms/.MainActivity
```

**Install + launch from built APK:**
```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n com.mitossoftwaresolutions.morsecomms/.MainActivity
```

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on setup, coding style, testing, and opening pull requests.

## Build notes

- `record: ^6.0.0` required (5.x ships incompatible `record_linux`)
- First build takes ~3 min (CMake + NDK download for `flutter_soloud` native layer)
- Subsequent builds are fast (~10s Gradle incremental)
- If build fails with SDK `.temp` directory error: delete `%LOCALAPPDATA%\Android\Sdk\.temp\` and retry
