# Morse Comms App — Architecture Decisions

## Vision
A prepper-focused Morse code app: fully offline, free, no ads, useful for survival and learning.
Target: Android first, iOS later (same codebase).

## Platform
**Flutter** (Dart)
- Single codebase for Android and iOS
- Native performance
- Good audio/mic ecosystem
- User background: Java, C, Python — Dart is Java-like, easy transition

## State Management
**BLoC** (Business Logic Component)
- Explicit event/state model — maps well to Java-style thinking
- Best fit for complex concurrent audio state (recording + playing + decoding simultaneously)
- Package: `flutter_bloc`

## Dependency Injection
- `get_it` + `injectable`

---

## Implementation Status

### Phase 1 — Core Engine ✅ DONE
- `core/morse/morse_table.dart` — full ITU Morse table (A–Z, 0–9, punctuation)
- `core/morse/morse_timing.dart` — timing math, WPM constants (PARIS standard)
- `core/morse/morse_encoder.dart` — text → tone sequence
- 22 unit tests passing

### Phase 2 — Tone Generator ✅ DONE
- `features/player/player_service.dart` — SoLoud-backed sine beep engine (play / stop / dispose)
- Configurable frequency and WPM at construction time

### Phase 3 — Goertzel DSP ✅ DONE
- `core/dsp/goertzel.dart` — single-frequency energy detector
- `core/dsp/morse_decoder.dart` — energy frames → dot/dash/gap symbols
- `core/dsp/decoder_pipeline.dart` — streaming mic frames → symbol stream
- `core/dsp/offline_analyzer.dart` — batch WAV analysis
- 58 unit tests passing

### Phase 4 — Encoder Screen ✅ DONE
- `features/encoder/` — text field → Morse written notation + audio playback
- EncoderBloc handles play / stop / text changed events

### Phase 5 — Decoder Screen ✅ DONE
- `features/decoder/` — mic → Goertzel → decoded text
- DecoderBloc + DecoderService wired to mic stream
- Signal meter via StreamBuilder (~10 updates/s, bypasses BLoC for low latency)
- 100-frame noise-floor calibration before decoding starts; threshold = 6× noise floor
- **Known issue**: decoder algorithm needs tuning (adaptive timing ratios, AGC interaction)

### Phase 6 — Settings ✅ DONE
- `features/settings/data/settings_repository.dart` — SharedPreferences persistence
- `features/settings/bloc/settings_cubit.dart` + `settings_state.dart` — write-through cubit
- `features/settings/ui/settings_screen.dart` — full UI with:
  - Theme mode: System / Light / Dark (SegmentedButton, live app-level effect)
  - WPM slider (5–40 WPM, persisted, ready to wire into encoder/decoder)
  - Tone frequency slider (400–900 Hz, persisted, ready to wire into player)
  - Side-tone toggle (persisted, decoder wiring pending)
  - Premium unlock card (UI + stub dialog; purchase flow not yet implemented)
  - Open-source licences page
- SettingsCubit provided at app root; themeMode drives MaterialApp.router

### Phase 7 — Learning Module ✅ DONE
- `features/lessons/data/koch_curriculum.dart` — 36-char Koch order (A–Z + 0–9), `charsAt()` / `levelLabel()` helpers
- `features/lessons/data/lesson_repository.dart` — SharedPreferences persistence for progress + per-level best accuracy
- `features/lessons/bloc/lesson_state.dart` — `DrillRound`, `LessonState` (session accuracy, `canAdvance` computed property)
- `features/lessons/bloc/lesson_cubit.dart` — generates random 5-char prompts, char-level scoring, advances level on ≥90% accuracy
- `features/lessons/ui/lessons_screen.dart` — hub: current-level progress card, full Koch level list with lock state
- `features/lessons/ui/drill_screen.dart` — 5 rounds × 5 chars; play → listen → type → char-diff → session summary → advance
- `features/lessons/ui/reference_screen.dart` — full Morse table with visual dot/dash indicators, grouped by letters / digits / punctuation
- Free tier: levels 1–5 (K M R S U); Premium tier: levels 6–36
- `MorseTiming` WPM range extended 5–25 → **5–40** to match settings slider
- Nav bar updated to 4 tabs: Encoder / Decoder / Learn / Settings

### Phase 8 — Wire Settings into Features ✅ DONE
- `EncoderBloc` accepts initial WPM + frequency; `EncoderSettingsChanged` event re-encodes live
- `EncoderScreen` wraps with `BlocListener<SettingsCubit>` — settings take effect instantly
- `DrillScreen` + `FarnsworthDrillScreen` receive `frequencyHz` from settings; passed to `player.play()`
- `PlayerService` gains `startTone(frequencyHz)` / `stopTone()` for side-tone use
- `DecoderService` accepts optional `onSideTone` callback; fires on per-frame tone-state transitions
- `DecoderScreen` wires callback → `PlayerService.startTone/stopTone` when `sideTone` is enabled in settings
- IAP skipped — no package selected yet; `SettingsCubit.unlockPremium()` stub remains

---

## Pending Wiring
| Item | Status |
|------|--------|
| WPM setting → EncoderBloc / DrillScreens | ✅ Wired |
| Tone frequency setting → PlayerService | ✅ Wired |
| Side-tone setting → DecoderService | ✅ Wired |
| Decoder algorithm tuning | Known issue |

---

## Decoder Sensitivity Tiers

| Tier | Source | Approach | Complexity |
|------|--------|----------|------------|
| 1 | Phone speaker → mic | Goertzel, amplitude threshold | Low — ship first |
| 2 | Radio / consistent tone | Goertzel + adaptive timing ratio | Medium |
| 3 | Noisy audio / radio static | Bandpass FFT or lightweight ML | High — future |

**Key insight**: dot duration ≈ 1/3 of dash duration. Decode the ratio adaptively from the first few symbols — don't hardcode timing.

**Android AGC note**: Android's Automatic Gain Control on the mic fights amplitude-based detection. Use `MediaRecorder` or `AudioRecord` with AGC disabled via platform channel.

---

## Folder Structure

```
lib/
  features/
    encoder/        # Text/Voice → Morse (written + audio)
      bloc/
      ui/
      data/
    decoder/        # Audio → Morse → Text
      bloc/
      ui/
      data/
    player/         # Beep generation, WPM control
    lessons/        # Koch method, drills, exercises
      bloc/         # LessonCubit + LessonState
      data/         # KochCurriculum, LessonRepository
      ui/           # LessonsScreen, DrillScreen, ReferenceScreen
    settings/       # WPM, frequency, theme
      bloc/         # SettingsCubit + SettingsState
      data/         # SettingsRepository
      ui/           # SettingsScreen
  core/
    morse/          # Pure algorithm: encoding table, timing constants
    dsp/            # Goertzel algorithm, adaptive threshold
    speech/         # STT abstraction (Android SpeechRecognizer, offline)
    audio/          # Platform channel wrappers for low-level audio
  app/
    app.dart        # Root widget, router
    di.dart         # Dependency injection setup
```

---

## Key Package Decisions

| Need | Package | Notes |
|------|---------|-------|
| State management | `flutter_bloc` | BLoC pattern |
| DI | `get_it` + `injectable` | Code-gen DI |
| Audio playback | `flutter_soloud` | Low-latency, good for beep gen |
| Audio recording | `record` | Cross-platform mic access |
| Speech-to-text | `speech_to_text` | Wraps Android SpeechRecognizer, offline on Android 10+ |
| Navigation | `go_router` | Declarative, well-maintained |
| Settings persistence | `shared_preferences` | Key-value store for theme, WPM, lesson progress |
| DSP (Goertzel) | Custom Dart/platform channel | No suitable package exists |

---

## Offline Requirement
**100% offline — no exceptions.**
- STT: Android on-device recognition only (available Android 10+)
- No analytics, no cloud APIs, no network calls
- All Morse logic is pure algorithm

---

## Morse Timing Standards (20 WPM baseline)
- Dot = 1 unit (60ms at 20 WPM)
- Dash = 3 units
- Gap between symbols = 1 unit
- Gap between letters = 3 units
- Gap between words = 7 units
- Standard tone frequency: 700 Hz
