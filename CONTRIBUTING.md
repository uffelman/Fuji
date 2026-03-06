# Contributing to Fuji

Thanks for your interest in contributing to Fuji! This guide covers everything you need to build the app from source and submit changes.

## Requirements

- **macOS 26.0+**
- **Xcode 26.x** (includes Swift 6.2)
- No Apple Developer account needed — the project builds and runs unsigned for local development.

## Building from Source

1. Clone the repository:

   ```bash
   git clone https://github.com/uffelman/Fuji.git
   cd Fuji
   ```

2. Open the Xcode project:

   ```bash
   open Fuji.xcodeproj
   ```

3. Xcode will automatically resolve the Sparkle 2 package dependency via Swift Package Manager. No manual dependency setup is required.

4. Select the **Fuji** scheme and press **⌘R** to build and run. Xcode handles signing automatically with your local development certificate ("Sign to Run Locally").

The app will appear as a menu bar icon — there is no main window.

## Project Structure

Fuji is a single-target Xcode project with no third-party dependencies beyond Sparkle (added via SPM for auto-updates). The codebase uses Swift 6.2 with strict concurrency, SwiftUI for views, and AppKit for the menu bar, settings window, and system integration.

Key areas to be aware of:

- **Display management** uses Core Graphics APIs (`CGDisplayCopyAllDisplayModes`, `CGBeginDisplayConfiguration`, etc.) and requires real display hardware to fully exercise.
- **Keyboard shortcuts** use the Carbon `RegisterEventHotKey` API. There is no modern Swift alternative for system-wide hotkeys.
- **Accessibility permission** (`AXIsProcessTrusted`) is required for keyboard shortcuts to work. The app includes an onboarding flow that guides users through granting this.

See `CLAUDE.md` in the repo root for a detailed file map, architecture overview, and technical notes.

## Development Setup

### Pre-Commit Hook

The project includes a pre-commit hook that prevents accidentally committing a hardcoded `DEVELOPMENT_TEAM` value to the Xcode project file. Enable it after cloning:

```bash
git config core.hooksPath .githooks
```

This is also enforced by CI, so even without the local hook, PRs with hardcoded team IDs will be rejected.

### Signing

The project file has `DEVELOPMENT_TEAM` set to an empty string by default. Xcode's automatic signing with "Sign to Run Locally" is sufficient for development. Do not commit your personal team ID — the pre-commit hook and CI guard exist specifically to prevent this.

For release builds (signing, notarization, distribution), see [RELEASING.md](RELEASING.md).

## Running Tests

Fuji has a `FujiTests` unit test target. Run tests locally with **⌘U** in Xcode, or from the command line:

```bash
./scripts/ci-build-and-test.sh
```

This script performs unsigned Debug and Release builds and runs the test suite. It's the same script CI uses.

Note: some app behavior (display mode switching, system-wide hotkeys, accessibility permission) cannot be meaningfully tested in an automated environment. These areas rely on protocol abstractions with mock implementations to make surrounding logic testable.

## CI

Pull requests and pushes are checked by a GitHub Actions workflow that runs on `macos-15` hosted runners. The CI performs:

- Unsigned Debug build
- Unsigned Release build
- Unit tests (skipped gracefully if the runner's macOS version is lower than the app's deployment target)
- A guard check ensuring no hardcoded `DEVELOPMENT_TEAM` values are present

You do not need any Apple credentials or secrets for CI to pass on your PR.

## Submitting Changes

1. Fork the repository and create a branch from `main`.
2. Make your changes. Follow the existing code style — the project uses `@Observable` with `@MainActor` throughout, avoids UIKit, and follows the Swift and SwiftUI conventions documented in `agents.md`.
3. If you're adding new logic, consider whether it can be covered by unit tests. Pure value types and manager methods behind protocols are the easiest to test.
4. Run the build and tests locally before pushing.
5. Open a pull request against `main` with a clear description of what you changed and why.

## Code Style

The project follows a specific set of Swift and SwiftUI conventions. A few highlights:

- Target macOS 26.0+, Swift 6.2 with strict concurrency.
- Use `@Observable` classes (not `ObservableObject`), always marked `@MainActor`.
- Prefer SwiftUI over AppKit unless AppKit is required (menu bar, window management, Carbon APIs).
- Avoid third-party dependencies without discussion first.
- Break different types into separate files rather than grouping multiple types in one file.
- Avoid force unwraps and force `try`.

See `agents.md` for the full set of conventions.

## License

By contributing, you agree that your contributions will be licensed under the [AGPL v3](LICENSE) license.
