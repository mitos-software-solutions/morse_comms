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
    - `test/core/dsp/morse_decoder_test.dart` — adaptive timing, bootstrap, and edge cases.
    - `test/core/dsp/custom_wav_test.dart` — decodes real captured YouTube WAV files (`yt1.wav`, `yt2.wav` in `scripts/test_wavs/custom_wavs/`); these are the **known-good baseline** for the live recording path.
    - `test/core/dsp/live_recording_simulation_test.dart` — **live recording path simulation** (see below).
  - Purpose: ensure the **algorithmic heart** of the app is correct and stable.

- **Live recording simulation tests**
  - File: `test/core/dsp/live_recording_simulation_test.dart`
  - Purpose: cover the recording degradation scenarios that cannot be tested with a real microphone. Synthetic PCM is injected directly into `OfflineAnalyzer.analyzeWav()` — the same code path used by `DecoderService.analyzeRecording()` after the 2026-03-10 unification.
  - Helper: `test/helpers/sine_morse_generator.dart` — generates ITU-timing sine-wave PCM; used across multiple DSP test files.
  - Test groups and what they verify:
    1. **Non-standard Morse timing** — senders with dash:dot ratio ≠ 3.0 and compressed inter-symbol gaps (root cause of the 2026-03-10 "OOOOO" device failure). Verifies the `dotMs < 150ms` guard routes low-WPM recordings through the seeded path, not adaptive bootstrap.
    2. **Mouse-click transient** — short wideband burst at recording start (user clicking to play the YouTube video). The `_filterShortOns` pass strips any ON event shorter than `minOnMs` (29ms) before decoding, so clicks do not produce spurious leading characters.
    3. **Simulated room reverb** — exponential Goertzel power decay injected after each tone burst. The gap-cluster threshold fix (`_findGapThreshold` + seeded `AdaptiveTiming`) makes letter-gap classification immune to reverb-inflated dotMs. Tests verify exact "SOS" decoding at 2-frame/15 WPM, 4-frame/10 WPM, and 8-frame/5 WPM reverb levels.
    4. **Tone frequency auto-detection** — unknown CW frequencies (450/600/750/800 Hz) decoded with `targetFrequencyHz: null`; verifies `_detectDominantFrequency` correctly selects the tone.
    5. **No silence lead-in** — recording starts mid-transmission (no calibration silence). Verifies the two-pass global noise floor still estimates correctly.
  - All previously-known reverb limitations are now resolved via the gap-cluster threshold (see `decoder_accuracy.md`).

- **Feature logic tests (BLoC/cubits/services)**
  - Location: `test/features/**`
  - Examples:
    - `decoder_bloc_test.dart` — full event handler coverage: all 10 public events + `_estimateDurationMs` helper; uses `MockDecoderService` / `MockPlayerService` from `test/helpers/fake_services.dart`.
    - `decoder_service_test.dart` — real `DecoderService` instantiation tests (no platform calls): `buildRecordingWav()` returns empty on a fresh instance, `recordedFrameCount` starts at 0, `analyzeRecording()` resolves to `(‘’, 0.0)` when nothing was recorded, `signalStream` is a broadcast stream, `onSideTone` wires correctly.
    - `encoder_bloc_test.dart`
    - `settings_cubit_test.dart` and `settings_repository_test.dart`
    - Lessons tests (`lesson_cubit_test.dart`, `farnsworth_cubit_test.dart`, etc.)
  - Style:
    - Use `flutter_test`’s `test(...)` / `blocTest(...)` API.
    - Stub or mock out platform-dependent pieces (audio, speech, shared preferences).
    - `mocktail` used for concrete-class mocking (`MockDecoderService extends Mock implements DecoderService`); register `Uint8List(0)` fallback value for `any()` matchers.
    - `DecoderService` can be instantiated in unit tests by registering a no-op mock handler for the `record` plugin's method channel (`com.llfbandit.record/messages`). The `create` method must return `0` (the recorder ID); all others return `null`. Only stateful methods (`startListening`, `hasPermission`) need a real device.
    - `SettingsCubit` accepts an optional `SttLocaleLoader localeLoader` parameter. Tests pass `_FakeSttLocaleLoader` (defined in `settings_cubit_test.dart` and `settings_screen_test.dart`); production uses the default `SttLocaleLoaderImpl` which wraps `SpeechToText`. This removes all platform channel calls from `SettingsCubit` tests. The real locale-loading logic lives in `lib/features/settings/data/stt_locale_loader.dart`.
  - Purpose:
    - Verify state transitions for BLoCs/cubits.
    - Ensure repositories persist and reload data correctly.
    - Guarantee settings/lessons/player behavior remains consistent as features evolve.

- **Shared test helpers**
  - File: `test/helpers/fake_services.dart`
  - Provides:
    - `MockDecoderService` / `MockPlayerService` — `mocktail` mocks for both services.
    - `stubDecoderServiceOk(svc, {...})` — happy-path stubs for all `DecoderService` methods in one call.
    - `stubPlayerServiceOk(player)` — stubs `playWav`, `stopWav`, `dispose`.
    - `makeMinimalWav([Uint8List? pcmBytes])` — builds a valid 44-byte WAV header + payload (byteRate = 88200) for use in tests that need audio bytes without a real file.

This layer is the **backbone** of the test suite.

Known intentional gaps at this level:

- `features/encoder/data/speech_service.dart` — **~0% coverage** by unit tests because it is hardware / platform-channel dependent (mic + STT). It will be exercised via higher-level integration/device tests instead.
- `features/player/player_service.dart` — **~0% coverage** by unit tests for real audio output; only stubbed in widget tests. Real audio behavior will be verified via integration/device tests.

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
    - **State-driven UI** (via `encoderBloc(tester).emit(...)`):
      - Playing state → button shows `Stop` (red) instead of `Play`.
      - `SttStatus.listening` → `"Listening… speak now"` row visible.
      - `SttStatus.error` → `"Microphone unavailable"` error text shown.
      - Settings WPM change via `settingsCubit.setWpm(x)` → `BlocListener` dispatches `EncoderSettingsChanged`; screen remains functional.
    - **Layout / overflow** (simulated phone + keyboard):
      - Uses `tester.view.physicalSize`, `tester.view.devicePixelRatio`, and `tester.view.viewInsets` (`FakeViewPadding`) to replicate a mid-range Android phone (360×780 dp) with the soft keyboard raised (~280 dp inset).
      - `addTearDown(tester.view.reset)` restores defaults after each test so other tests are unaffected.
      - Verifies no `FlutterError` overflow with short text (`SOS`) and with long text (~30 chars) that produces multi-line Morse output.
      - **Why these tests exist**: the default test surface (800×600) never triggers overflow; `tester.enterText()` does not shrink the viewport. The overflow bug (fixed by replacing `Padding` with `SingleChildScrollView`) was only visible when both conditions held simultaneously on real hardware.

- **DecoderScreen widget tests**
  - File: `test/features/decoder/decoder_screen_test.dart`
  - Builds `DecoderScreen` with a real `SettingsCubit` (mock `SharedPreferences`) and a stub `PlayerService`.
  - Accesses the internally-created `DecoderBloc` via `tester.element(find.byType(FilledButton).first).read<DecoderBloc>()` — no production-code changes needed.
  - **Note:** `BlocBuilder` uses an async broadcast stream. After `bloc.emit(state)`, two consecutive `await tester.pump()` calls are required: the first delivers the stream event and schedules `setState`, the second renders the rebuilt frame.
  - Verifies:
    - **Basic UI / idle state**: title, placeholder, Listen button, audio toolbar (New Recording / Load Example / Open Recording), Play and Save hidden when no audio.
    - **Listening state**: Stop button replaces Listen; recording header shows formatted timer (e.g. `1:05`); signal meter shows `TONE` or `silence` based on snapshot.
    - **Analyzing state**: spinner + `”Analyzing…”` label shown; button disabled.
    - **Result state**: decoded text or `”No Morse detected”` placeholder; Play+Save appear when `audioBytes != null`; Play icon toggles to Stop when `isPlayingAudio=true`.
    - **Quality badges**: MED (`0.8`) shows fair-quality message; LOW (`0.5`) shows poor-quality message; HIGH (`1.0`) shows no badge.
    - **Banners**: permission-denied and error banners rendered from state.
    - **Saved chip**: filename + Share button shown when `savedPath` is set.
    - **Reset button**: disabled at idle, enabled at result, tapping dispatches `DecoderCleared` → state returns to idle.

- **RecordingQualityBadge widget tests**
  - File: `test/features/decoder/recording_quality_badge_test.dart`
  - Tests the `RecordingQualityBadge` widget directly (exposed with `@visibleForTesting`).
  - Verifies the two quality tiers:
    - **MED** (`0.7 ≤ quality < 1.0`) — renders `info_outline` icon and `”Recording quality: fair — some segments were unclear”` message. Tested at `0.7` (boundary) and `0.8`.
    - **LOW** (`quality < 0.7`) — renders `warning_amber_rounded` icon and `”Recording quality: poor — output may be approximate”` message. Tested at `0.69` (just below boundary), `0.3`, and `0.0`.
  - Verifies the exact `0.7` boundary: `0.699` → LOW, `0.7` → MED.
  - Verifies the badge is not present in the screen at initial idle state (quality defaults to `1.0`).

- **DecoderState `recordingQuality` tests** (in `decoder_bloc_test.dart`)
  - Added to the existing `DecoderBloc` test group under `recordingQuality`:
    - Default `recordingQuality` is `1.0` (HIGH — badge hidden).
    - `copyWith` updates and preserves `recordingQuality` correctly.
    - Quality `>= 1.0` satisfies the hide-badge condition.
    - Quality `0.7` (MED boundary) and `0.8` are NOT low (`< 0.7` is false).
    - Quality `0.69` (just below threshold) and `0.0` ARE low.
    - Badge is not shown when `status != result` even if quality is low (guards `hasResult && quality < 1.0`).

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
    - Dragging the tone frequency slider updates the Hz label (no longer `600 Hz` after drag).
    - Toggling the side‑tone switch updates the `sideTone` flag in state.
    - Support & Contribute section renders "Get involved" and "Buy me a coffee?" headings, and both `FilledButton`s (View on GitHub, Buy Me a Coffee) with correct icons, minimum 48×48 touch targets, and accessibility semantics.
    - About section renders the `ABOUT` header, `Version` tile, and `Open-source licences` tile.
    - `_LocalePickerDialog`: opens with a `CircularProgressIndicator` when `sttLocales` is empty; shows `RadioListTile`s when locales are pre-seeded; Cancel closes the dialog; tapping a locale updates `sttLocaleId` in state and closes the dialog.
  - **Note — `_LocalePickerDialog` test setup**: `_openPicker()` fires `loadSttLocales()` without `await`. With `_FakeSttLocaleLoader` this completes instantly with no platform calls. However, the `SpeechToText` singleton (used by `SttLocaleLoaderImpl`) registers a persistent `setMethodCallHandler` the first time it is instantiated anywhere in the test process, which prevents `pumpAndSettle` from draining after a dialog tap. Tests use `pump()` + `pump(Duration(milliseconds: 350))` instead of `pumpAndSettle` after dialog open/close interactions. Test locales use IDs other than the default `'en_US'` to avoid the locale name appearing both in the tile subtitle and inside the dialog.

---

## Level: Integration Tests (`integration_test`)

**Planned — not yet implemented.**

Integration tests drive the full running app (real platform channels, real widget tree, real routing) using the `integration_test` package and the same `find` / `tester` API as widget tests.

---

### CI target strategy

| Runner | Target | Cost | What it can test |
|--------|--------|------|-----------------|
| `ubuntu-latest` (existing) | Flutter web / Chrome | Free, fast | Navigation, encoder, decoder file-load, settings, lessons |
| `windows-latest` (new job) | Windows desktop | ~2× slower | Same flows + Windows-specific save dialog |
| Physical device / emulator | Android | Not in CI | Mic recording, real STT, real audio |

**Phase 1** targets the existing `ubuntu-latest` runner using `-d chrome`. No new runner cost, runs alongside unit tests. Flows that require a microphone, real audio output, or a native file picker are explicitly out of scope for CI and deferred to device-level testing.

---

### Setup required

1. **`pubspec.yaml`** — add to `dev_dependencies`:
   ```yaml
   integration_test:
     sdk: flutter
   ```

2. **Directory** — create `integration_test/` at the repo root (sibling of `test/`).

3. **`integration_test/app_test.dart`** — entry point that calls `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` and bootstraps the real app (`main()`-style setup: SharedPreferences, PlayerService stub or real, SettingsCubit with `SttLocaleLoaderImpl`).

4. **`.github/workflows/test.yml`** — add a second job (or extend the existing one) that runs:
   ```
   flutter test integration_test/ -d chrome --browser-name chrome
   ```
   Keep unit tests on `ubuntu-latest`; integration tests can share the same job or run separately.

---

### Flows to implement (ordered by value / feasibility)

#### 1. App navigation — `integration_test/navigation_test.dart`
- App starts on Encoder tab (`Morse Encoder` title visible).
- Tap each bottom nav item in order (Decoder → Learn → Settings → Encoder) and verify the primary screen title for each.
- **CI safe:** yes. No audio, no permissions.

#### 2. Encoder flow — `integration_test/encoder_flow_test.dart`
- Type `SOS` into the text field.
- Verify Morse output `... --- ...` is displayed.
- Verify Play button is enabled.
- Verify the output card disappears after clearing the field.
- **CI safe:** yes. Does not tap Play (audio playback has no output device in CI).

#### 3. Decoder: Load Example flow — `integration_test/decoder_flow_test.dart`
- Navigate to Decoder tab.
- Tap the "Load Example" popup button (flask icon).
- Select "SOS (20 WPM)" from the menu.
- Verify the Analyzing spinner appears then resolves.
- Verify decoded text `SOS` is shown on screen.
- Verify the Play and Save buttons appear (audio bytes are available).
- **CI safe:** yes. Uses `rootBundle` — no file picker, no microphone.
- **Note:** this test exercises the full DSP pipeline end-to-end on a real device target.

#### 4. Settings: WPM persistence — `integration_test/settings_flow_test.dart`
- Navigate to Settings.
- Drag the WPM slider to a new value (e.g. 30 WPM).
- Navigate to Encoder and back to Settings.
- Verify the WPM label still shows the updated value (SharedPreferences round-trip).
- **CI safe:** yes.

#### 5. Lessons: Browse and enter a drill — `integration_test/lessons_flow_test.dart`
- Navigate to Learn tab.
- Verify Koch Method and Farnsworth Method cards are visible.
- Tap Koch Method → verify the Koch lesson list screen opens.
- Tap the reference icon → verify Reference screen opens with Characters tab.
- **CI safe:** yes. Does not start audio drills.

---

### Intentionally out of scope for CI

| Feature | Reason | How to test |
|---------|--------|-------------|
| Live recording (mic) | No microphone in CI | Manual / device farm |
| Audio playback (SoLoud) | No output device in CI | Manual / device farm |
| Real STT locales | Platform-specific STT engine | Manual on Android/Windows |
| Native file picker | Requires OS file dialog | Manual / Windows device |
| Save-to-path (desktop) | Requires writable fs dialog | Manual on Windows |

---

### Known integration test constraints

- **`compute` isolates on web:** Flutter web does not support true Dart isolates; `compute()` falls back to running inline. The DSP pipeline will still complete correctly but will block the UI thread briefly during analysis. This is acceptable for tests but is a known difference from native.
- **`flutter_soloud` on web:** `PlayerService.init()` may throw or no-op if no audio context is available in a headless Chrome runner. The integration test bootstrap should catch and swallow this error so tests can continue without audio.
- **SharedPreferences on web:** uses `localStorage`; state is isolated per test run by default.

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
  - Implement the five **integration test** flows above (navigation, encoder, decoder file-load, settings persistence, lessons browse).
  - Add a `windows-latest` CI job for Windows-specific paths (save dialog, Windows STT).

- **Long term**
  - Add **golden tests** for visual stability if UI changes become frequent.

