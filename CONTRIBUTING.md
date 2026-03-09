## Contributing to morse_comms

Thanks for your interest in contributing to **morse_comms** — a prepper-focused, fully offline Morse code app.

### Getting started

- **Prerequisites**:
  - Flutter SDK (matching the version in `pubspec.yaml`).
  - Android SDK + emulator (or physical device).
- **Setup**:
  - Clone the repo.
  - Run:
    - `flutter pub get`
    - `flutter test`

### Running the app

- Start an Android emulator or connect a device.
- Run:
  - `flutter run -d emulator-5554` (or your device ID).

See `README.md` for more detailed build and run commands.

### Code style and architecture

- Follow the existing **feature + core** structure:
  - `lib/core/*` for shared Morse/DSP/audio/speech logic.
  - `lib/features/*` for UI, state management (BLoC/cubits), and feature-specific logic.
- Prefer:
  - BLoC/cubits for state management (`flutter_bloc`).
  - Dependency injection via `get_it` + `injectable`.
- Keep new code covered by tests when practical, especially in:
  - `lib/core/*`
  - `lib/features/*`

### Tests

- Run all tests before opening a PR:
  - `flutter test`
- If you add or change behavior, add or update tests in `test/` to match.

### Submitting changes

1. Fork the repo and create a feature branch.
2. Make your changes and ensure:
   - `flutter analyze` (or your IDE's analyzer) shows no new issues.
   - `flutter test` passes.
3. Open a pull request with:
   - A clear description of the change and motivation.
   - Notes on testing (commands run and results).

### Non-code contributions

Bug reports, feature requests, and documentation improvements are welcome.  
Please use GitHub issues for discussing ideas before large or breaking changes.

