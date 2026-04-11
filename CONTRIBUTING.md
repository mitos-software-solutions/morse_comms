## Contributing to morse_comms

Thanks for your interest in contributing to **morse_comms** — a prepper-focused, fully offline Morse code app.

---

### Branch strategy

```
feature/* or fix/*  →  develop  →  main
                          ↑              ↑
                     anyone PRs     maintainer merges
                                    (triggers release)
```

| Branch | Purpose |
|--------|---------|
| `main` | Release-only. Protected — no direct pushes. Every merge creates a GitHub Release. |
| `develop` | Integration branch. All contributor PRs target here. |
| `feature/*`, `fix/*` | Your working branch. Branch off `develop`, PR back to `develop`. |

---

### Getting started

**Prerequisites:**
- Flutter SDK matching the version in `pubspec.yaml`
- Android SDK + emulator or physical device

**Setup:**
```bash
git clone https://github.com/mitos-software-solutions/morse_comms.git
cd morse_comms
git checkout develop
flutter pub get
flutter test
```

---

### Workflow for contributors

1. **Fork** the repo (external contributors) or create a branch (collaborators).
2. **Branch off `develop`:**
   ```bash
   git checkout develop
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes.** Follow the code style below.
4. **Verify locally before pushing:**
   ```bash
   flutter analyze --fatal-infos
   flutter test
   ```
5. **Open a PR** targeting `develop` (not `main`).
6. CI runs automatically — the PR is blocked until tests and analysis pass.
7. A maintainer reviews and merges into `develop`.

---

### Releasing (maintainers only)

When `develop` is ready to ship:

1. Bump the version in **4 places** (see the version bump checklist in `.context/`):
   - `pubspec.yaml` — `version: X.Y.Z+N`
   - `CHANGELOG.md`
   - F-Droid recipe
   - `fdroiddata` yml
2. Open a PR from `develop` → `main`.
3. On merge, the `release.yml` workflow automatically:
   - Runs tests
   - Builds Windows zip + Android APK
   - Creates a GitHub Release tagged `vX.Y.Z` with auto-generated notes and artifacts attached

---

### Code style and architecture

- Follow the existing **feature + core** structure:
  - `lib/core/*` — shared Morse/DSP/audio/speech logic
  - `lib/features/*` — UI, state management (BLoC/cubits), feature-specific logic
- State management: `flutter_bloc` (BLoCs and cubits)
- Dependency injection: `get_it` + `injectable`
- Keep new behaviour covered by tests, especially in `lib/core/`

---

### Running the app

```bash
# Android emulator
flutter run -d emulator-5554

# Windows
flutter run -d windows
```

See `README.md` for full build commands and ADB shortcuts.

---

### Non-code contributions

Bug reports, feature requests, and documentation improvements are welcome.
Please open a GitHub issue before starting large or breaking changes.
