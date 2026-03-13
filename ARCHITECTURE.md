# Morse Comms App — Architecture

## Vision
A prepper-focused Morse code app: fully offline, free, no ads, useful for survival and learning.
Target: Android-first, iOS same codebase.

## Platform
**Flutter** (Dart)
- Single codebase for Android and iOS
- Native performance
- Good audio/mic ecosystem

## State Management
**BLoC** (`flutter_bloc ^9.0.0`)
- Explicit event/state model — maps well to Java-style thinking
- Best fit for complex concurrent audio state (recording + playing + decoding simultaneously)
- Settings state uses a simpler `Cubit` (no events needed)

## Dependency Injection
`get_it ^8.0.0` + `injectable ^2.5.0` (code-gen via `build_runner`)

---

## Offline Analyzer Algorithm

`core/dsp/offline_analyzer.dart` — called after each recording stops or when a WAV file is loaded.

**Input:** Goertzel power magnitudes + frame duration (ms)
**Output:** `(decodedText, confidence)`

**Pipeline:**
1. **Two-pass noise floor** — p33 of the full power distribution → rough threshold → mean of silent frames → final threshold = `6 × noiseFloor`
2. **2-frame debounced event extraction** — mirrors `DecoderPipeline._runDecode`; produces `(isOn, durationMs)` pairs
3. **Adaptive segment break** — global bimodal pre-estimate → `max(3000ms, 10 × dotMs)` break threshold
4. **Segment splitting** — silence ≥ break threshold splits into segments; within each segment, `_detectSpeedChanges()` further splits on >30% dot-duration change (requires ≥ 4 events per sub-segment, CV < 0.40)
5. **Per-segment analysis:**
   - `< 4 ON events` → adaptive bootstrap (`_decodeAdaptive` with percentile pre-seed)
   - `≥ 4 ON events`:
     - Pass 1: pre-bimodal transient filter (`< 3 × frameDuration`)
     - `_robustBimodalSplit()` — tries every split point; scores by proximity to ideal 3.0 ratio + relative gap; CV thresholds: 0.80 near-perfect (2.7–3.3), 0.65 good (2.2–2.7 or 3.3–4.0), 0.50 standard
     - If standard bimodal fails and ≤ 7 events: retry with `minRatio=1.5` (soft bimodal)
     - If bimodal invalid: return `?`
     - If `ratio ≤ 2.0 AND dotMs < 90ms` (high WPM, low ratio): adaptive bootstrap
     - Otherwise: Pass 2 isolation filter → `_findGapThreshold()` → `_decodeSeeded()`

**Key constants:**
| Constant              | Value  | Purpose
|-----------------------|--------|------------------------------
| `_minOnEvents`        | 4      | Minimum ON events for bimodal
| `_minRatio`           | 1.8    | Standard minimum dash:dot ratio
| `_maxRatio`           | 4.5    | Maximum dash:dot ratio
| `_maxClusterCv`       | 0.50   | Max CV per timing cluster (standard)
| `_seedRatioThreshold` | 2.0    | Below this (+ high WPM) → adaptive
| `_segmentBreakMs`     | 3000ms | Floor for segment break threshold

---

## Folder Structure

```
lib/
  app/
    app.dart            # Root widget, go_router setup, SettingsCubit → MaterialApp.router
    di.dart             # get_it + injectable registration
  core/
    morse/              # Pure algorithm: table, timing, encoder, transliterator, Farnsworth
    dsp/                # Goertzel, AdaptiveTiming, DecoderPipeline, OfflineAnalyzer
    speech/             # STT abstraction (speech_to_text, Android offline)
    audio/              # Low-level platform audio helpers
  features/
    encoder/
      bloc/             # EncoderBloc + events + state
      data/             # EncoderRepository, SpeechService (STT)
      ui/               # EncoderScreen
    decoder/
      bloc/             # DecoderBloc + events + state (recordingQuality field)
      data/             # DecoderService (mic pipeline, WAV export, offline analysis)
      ui/               # DecoderScreen, RecordingQualityBadge (@visibleForTesting)
    player/
      player_service.dart  # SoLoud sine engine + WAV playback
    lessons/
      bloc/             # LessonCubit, FarnsworthCubit, LessonState
      data/             # KochCurriculum, FarnsworthCurriculum, LessonRepository
      ui/               # LessonsScreen hub, Koch/Farnsworth screens, DrillScreen, ReferenceScreen
    settings/
      bloc/             # SettingsCubit + SettingsState
      data/             # SettingsRepository (SharedPreferences)
      ui/               # SettingsScreen

test/
  app/                  # App navigation widget tests
  core/
    morse/              # Encoder, timing, transliterator unit tests
    dsp/                # Goertzel, AdaptiveTiming, OfflineAnalyzer unit + simulation tests
  features/             # BLoC/cubit/service unit tests + widget tests per feature
  helpers/
    sine_morse_generator.dart  # PCM generator for DSP simulation tests
    fake_services.dart          # MockDecoderService, MockPlayerService, makeMinimalWav()
```

---

## Package Decisions

| Need                 | Package                  | Version   | Notes 
|----------------------|--------------------------|-----------|----------------
| State management     | `flutter_bloc`           | ^9.0.0    | BLoC + Cubit 
| DI                   | `get_it` + `injectable`  | ^8 / ^2.5 | Code-gen 
| Audio playback       | `flutter_soloud`         | ^3.0.0    | Low-latency sine engine + WAV 
| Audio recording      | `record`                 | ^6.0.0    | `^5.x` incompatible (record_linux mismatch) 
| Speech-to-text       | `speech_to_text`         | latest    | Android on-device, offline (Android 10+) 
| Navigation           | `go_router`              | ^14.0.0   | Declarative 
| Settings persistence | `shared_preferences`     | ^2.3.0    | Theme, WPM, frequency, lesson progress 
| File sharing         | `share_plus`             | ^10.0.0   | `Share.shareXFiles([XFile(path)])` — store-safe save-to-device 
| File picking         | `file_selector`          | ^1.0.0    | `openFile(acceptedTypeGroups: [...])` 
| Path resolution      | `path_provider`          | ^2.1.0    | Temp dir for WAV export before share 

---

## Offline Requirement
**100% offline — no exceptions.**
- STT: Android on-device recognition only (Android 10+)
- No analytics, no cloud APIs, no network calls
- All Morse logic and DSP are pure Dart algorithms

---

## Morse Timing Standards

| Element       | Duration | At 20 WPM 
|---------------|----------|----------
| Dot           | 1 unit   | 60 ms 
| Dash          | 3 units  | 180 ms 
| Symbol gap    | 1 unit   | 60 ms 
| Letter gap    | 3 units  | 180 ms
| Word gap      | 7 units  | 420 ms
| Standard tone |    —     | 700 Hz

Farnsworth method: characters sent at normal (or higher) WPM; inter-letter and inter-word gaps expanded so the overall effective WPM is lower. Used in drill screens.

---

## Test Coverage

881 tests, all passing (`flutter test`). **85.1% line coverage** (2504/2941). Zero regressions across all phases.

| Area            | Files                                                     | What's covered
|-----------------|-----------------------------------------------------------|----------------------------------------------------------
| Core Morse      | `test/core/morse/`                                        | Table, timing, encoder, transliterator, Farnsworth timing
| DSP unit        | `test/core/dsp/`                                          | Goertzel, AdaptiveTiming, OfflineAnalyzer (all paths), edge cases, limits, CV diagnostics
| DSP simulation  | `live_recording_simulation_test.dart`                     | Non-standard timing, click transients, room reverb, auto freq detection, no lead-in silence
| Real WAV        | `custom_wav_test.dart`, `stereo_wav_test.dart`            | yt1.wav, yt2.wav (YouTube), stereo downmix
| Feature BLoCs   | `test/features/*/`                                        | State transitions, repository persistence, full event handler coverage (DecoderBloc, EncoderBloc)
| Widget tests    | `*_screen_test.dart`, `recording_quality_badge_test.dart` | UI render, state-driven transitions, badge tiers, navigation
| App navigation  | `app/app_navigation_test.dart`                            | Bottom nav, tab switching
| Test helpers    | `test/helpers/`                                           | `MockDecoderService`, `MockPlayerService`, `makeMinimalWav()`, `stubDecoderServiceOk()` 

---

## Android-Specific Notes

**AGC / Noise Suppression:** Android's Automatic Gain Control and Noise Suppressor treat periodic Morse tones as noise and corrupt timing. Fixed by recording with `AndroidAudioSource.unprocessed` (`RecordConfig.androidConfig`). Requires Android API 24+ (Android 7.0).

**Goertzel power-lingering:** The Goertzel detector integrates energy over a 512-sample frame (~11.6 ms at 44.1 kHz). Tone energy bleeds into the first frame after the tone ends, inflating measured ON durations by ~1 frame. The offline analyzer accounts for this:
- `_findGapThreshold` lower bound: `0.5 × dotMs` (not `1.0 ×`) to accept gap thresholds below the inflated dotMs
- `_seedRatioThreshold` guard: ratios ≤ 2.0 with short dotMs use adaptive bootstrap, not the seeded path

**ADB log encoding:** ADB logcat on Windows outputs UTF-16. To decode: `adb logcat | python3 -c "import sys; sys.stdout.buffer.write(sys.stdin.buffer.read().decode('utf-16').encode('utf-8'))"`.
