## Testing Strategy for morse_comms

This document describes the current testing setup and planned test layers as the app grows.

The goal is to keep the **core Morse/DSP logic**, **feature logic (BLoC/cubits)**, and **user-facing flows** well covered, while staying pragmatic.

---

## Level: Unit & Logic Tests (`flutter_test`)

These tests live under `test/` and run with:

```bash
flutter test
```

- **Core/domain tests**
  - Location: `test/core/**`
  - Covers:
    - Morse table, timing, and encoder/decoder math.
    - DSP components (Goertzel, decoder pipeline, offline analyzer, limit tests).
  - Purpose: ensure the **algorithmic heart** of the app is correct and stable.

- **Feature logic tests (BLoC/cubits/services)**
  - Location: `test/features/**`
  - Examples:
    - `encoder_bloc_test.dart`
    - `settings_cubit_test.dart` and `settings_repository_test.dart`
    - Lessons tests (`lesson_cubit_test.dart`, `farnsworth_cubit_test.dart`, etc.)
  - Style:
    - Use `flutter_test`’s `test(...)` API.
    - Stub or mock out platform-dependent pieces (audio, speech, shared preferences).
  - Purpose:
    - Verify state transitions for BLoCs/cubits.
    - Ensure repositories persist and reload data correctly.
    - Guarantee settings/lessons/player behavior remains consistent as features evolve.

This layer is the **backbone** of the test suite.

Known intentional gaps at this level:

- `features/encoder/data/speech_service.dart` — **0% coverage** by unit tests because it is hardware / platform-channel dependent (mic + STT). It will be exercised via higher-level integration/device tests instead.
- `features/player/player_service.dart` — **0% coverage** by unit tests for real audio output; only stubbed in widget tests. Real audio behavior will be verified via integration/device tests.

---

## Level: Widget Tests (`flutter_test` with `testWidgets`)

Widget tests exercise UI components in a **simulated environment** (no real device), but with actual widgets and layout.

They live under `test/features/**` and run with the regular `flutter test` command.

- **App navigation widget tests**
  - File: `test/app/app_navigation_test.dart`
  - Builds the full `MorseCommsApp` with stubbed `PlayerService`, fake `LessonRepository`, and real `SettingsCubit` (mock `SharedPreferences`).
  - Verifies:
    - The app starts on the **Encoder** tab with `Morse Encoder` visible.
    - Tapping bottom navigation destinations switches between **Encoder**, **Decoder**, **Learn**, and **Settings**, with each section’s primary screen title shown (`Morse Decoder`, `Learn Morse`, `Settings`).

- **EncoderScreen widget tests**
  - File: `test/features/encoder/encoder_screen_test.dart`
  - Builds `EncoderScreen` inside a `MaterialApp`, with:
    - A real `SettingsCubit` backed by mock `SharedPreferences`.
    - A stub `PlayerService` (no real audio).
  - Verifies:
    - **Basic UI**:
      - App bar title `Morse Encoder` is shown.
      - The text field with label/hint `Enter text` is present.
    - **Text → Morse behavior**:
      - Typing `SOS` produces Morse output `... --- ...`.
    - **Play button behavior**:
      - Play button is disabled when there is no input.
      - After typing text, the Play button becomes enabled.
      - Tapping Play calls `PlayerService.play`.
    - **Recognised text card**:
      - Shows placeholder `— recognised text —` when empty.
      - For diacritics input like `héllo`, shows transliterated text `HELLO`
        plus the caption `Transliterated to Latin for Morse encoding`.
    - **Morse output card**:
      - Shows placeholder `— morse output —` initially.
      - After typing `SOS`, placeholder disappears and `... --- ...` is rendered.

- **DecoderScreen widget tests**
  - File: `test/features/decoder/decoder_screen_test.dart`
  - Builds `DecoderScreen` with a real `SettingsCubit` (mock `SharedPreferences`) and a stub `PlayerService`.
  - Verifies:
    - App bar title `Morse Decoder` is shown.
    - Initial placeholder text `Press Listen to start recording` is rendered with the main `Listen` button.
    - The “New Recording” app bar action is present.
    - The `Save to Device` button is not shown when there is no decoded result.

- **Learn / Lessons widget tests**
  - File: `test/features/lessons/lessons_screen_test.dart`
  - Builds `LessonsScreen` with:
    - A fake `LessonRepository` (pre-seeded progress) and stub `PlayerService`.
    - A real `SettingsCubit` backed by mock `SharedPreferences`.
  - Verifies:
    - The main Learn entry point (`Learn Morse`) and both method cards (`Koch Method`, `Farnsworth Method`) render.
    - Tapping the app bar reference icon opens `ReferenceScreen` (`Morse Reference` title visible).
    - Tapping the info icon opens the lessons info dialog (content mentioning “Koch”).
  - File: `test/features/lessons/reference_screen_test.dart`
  - Builds `ReferenceScreen` with a stub `PlayerService`.
  - Verifies:
    - App bar title and tabs (`Characters`, `Guide`) render.
    - Characters tab shows at least one character grid of tiles.
    - Guide tab shows the intro card (`What is Morse Code?`) when selected.

- **SettingsScreen widget tests**
  - File: `test/features/settings/settings_screen_test.dart`
  - Builds `SettingsScreen` with a real `SettingsCubit` backed by mock `SharedPreferences`.
  - Verifies:
    - Main sections and controls (appearance, Morse settings, speech recognition, about) are rendered.
    - The theme `SegmentedButton<ThemeMode>` is present and tapping the segments updates `themeMode`.
    - Dragging the WPM slider updates the visible WPM label (no longer `20 WPM` after drag).
    - Toggling the side‑tone switch updates the `sideTone` flag in state.

---

## Planned Level: Integration Tests (`integration_test`)

**Not implemented yet — future work.**

Integration tests will run on **real devices/emulators** (Android and iOS) and drive the full app:

- **Scope**
  - High-value end-to-end flows, for example:
    - Encoder flow: open app → go to Encoder → enter text → play tones.
    - Decoder flow: (with stubbed or sample audio) open app → Decoder → start listening → see decoded text.
    - Lessons flow: start a drill → complete rounds → see progress updated.
    - Settings flow: change WPM/tone frequency/theme → verify effects in other screens.
  - Exercise plugins and platform channels:
    - `record` (mic input) paths.
    - `speech_to_text` behavior where feasible.
    - `flutter_soloud` playback wiring.

- **Benefits**
  - Verifies that the app works as expected on **real hardware**, across platforms.
  - Good fit for CI on device farms or local emulators.

---

## Planned Level: Golden Tests (Visual Regression)

**Not implemented yet — future work.**

Golden tests record and compare **image snapshots** of widgets or screens:

- **Scope**
  - Key screens at multiple sizes/themes:
    - Encoder/Decoder/Lessons/Settings screens.
    - Important dialogs or error states.
  - Compare new renders against checked-in “golden” images.

- **Benefits**
  - Catch unintended visual/layout changes early.
  - Helpful as the UI grows or as themes are refined.

---

## How to Evolve the Test Suite

- **Short term**
  - Keep strengthening **core** and **feature logic** tests in `test/core/**` and `test/features/**` when adding new behavior.

- **Medium term**
  - Introduce **`integration_test`** flows for critical paths (encoder, lessons, settings).

- **Long term**
  - Add **golden tests** for visual stability if UI changes become frequent.

