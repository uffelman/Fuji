# Fuji — Project Context

> **Keep this file updated.** When you add a new manager, feature, or significant architectural change, update the relevant section below so the next session starts with accurate context.

See `agents.md` for coding rules (Swift/SwiftUI conventions, API preferences, project structure guidelines).


## What the app is

Fuji is a **macOS menu bar utility** that lets users browse and switch display resolutions, save named presets, and trigger presets via global keyboard shortcuts. It has no main window — it lives entirely in the menu bar (`LSUIElement = true`).

- **Platform:** macOS 26.0+
- **Language:** Swift 6.2, strict concurrency
- **UI:** SwiftUI + AppKit (NSStatusItem menu, NSWindow for settings/onboarding)
- **Dependencies:** Sparkle 2.x (auto-updates via SPM)
- **Tests:** `FujiTests` target with unit tests for core logic (protocol+mock pattern enables further coverage)
- **Build:** Single-target Xcode project, Sparkle via SPM


## File map

```
Fuji/
├── FujiApp.swift                    @main entry; Settings scene
├── AppDelegate.swift                Startup orchestration, wires all managers
├── Container.swift                  Dependency container holding shared managers
├── Logger.swift                     OSLog extension (Logger.app)
├── Display.swift                    Display model with resolution stepping logic
├── DisplayMode.swift                Resolution mode model with aspect ratio detection
├── DisplayConfiguration.swift       Value type pairing a display ID with a mode
├── DisplayManager.swift             Core Graphics display enumeration + mode switching
├── ResolutionPreset.swift           Preset model with smart multi-display matching
├── SettingsManager.swift            UserDefaults persistence (presets, preferences)
├── UserDefaults+Keys.swift          Centralized key definitions + default registration
├── MenuBarController.swift          NSStatusItem + dynamic NSMenu construction
├── SettingsView.swift               Settings window (tabs: presets, general, about)
├── PresetsSettingsTab.swift         Preset list management tab
├── GeneralSettingsTab.swift         General settings tab (overlay, login, shortcuts)
├── AboutSettingsTab.swift           About tab (version, links, license)
├── PresetEditorSheet.swift          Modal for creating/editing presets
├── PillButton.swift                 Reusable pill-shaped button component
├── KeyboardShortcut.swift           Value type: Carbon keycode + modifier flags
├── KeyboardShortcutManager.swift    Carbon hotkey registration + ShortcutRecorder
├── ResolutionOverlayController.swift HUD overlay window for resolution change feedback
├── ResolutionOverlayView.swift      SwiftUI content view for the resolution overlay
├── VisualEffectBackground.swift     NSViewRepresentable for NSVisualEffectView materials
├── OnboardingView.swift             Two-page SwiftUI onboarding flow
├── OnboardingWindowController.swift Floating NSWindow hosting onboarding
├── UpdaterManager.swift             Sparkle auto-update wrapper (SPUStandardUpdaterController)
├── PermissionsManager.swift         AXIsProcessTrusted polling + protocol + mock
├── Bundle+App.swift                 Extensions for reading Info.plist values
├── ProcessInfo+Preview.swift        SwiftUI preview detection helper
├── DebugSettings.swift              #if DEBUG: force-onboarding flag
├── Fuji-Info.plist                  LSUIElement = true, Sparkle config
└── Assets.xcassets/                 App icon, accent color

FujiTests/
├── DisplayModeTests.swift           Equality, HiDPI, aspect ratio label tests
└── DisplayResolutionGroupingTests.swift  Resolution group sorting tests
```


## Architecture

**Pattern:** Singleton managers (`DisplayManager.shared`, `SettingsManager.shared`) coordinated through `AppDelegate`. All `@Observable`, all `@MainActor`.

**Startup flow:**
1. `AppDelegate.applicationDidFinishLaunching` creates `MenuBarController` and `KeyboardShortcutManager`.
2. If accessibility permission is missing, shows `OnboardingWindowController`.
3. Keyboard shortcuts register after a 500ms delay (reliability for login-item launch). Failed registrations retry after 2s.

**Key data flow:**
- `DisplayManager` enumerates displays via Core Graphics and watches for connect/disconnect via `CGDisplayRegisterReconfigurationCallback`.
- `SettingsManager` persists presets as JSON in UserDefaults. CRUD operations post `presetsDidChange` notification.
- `MenuBarController` and `KeyboardShortcutManager` both observe `presetsDidChange` to rebuild the menu / re-register hotkeys.
- `KeyboardShortcutManager` uses Carbon `RegisterEventHotKey` / `InstallEventHandler` for system-wide hotkeys (no modern Swift alternative exists).

**Settings window:** Opened manually via `NSWindow` + `NSHostingController` because SwiftUI `Settings` scene has limitations in menu bar apps.

**Onboarding window:** `NSWindow` at `.floating` level, temporarily drops to `.normal` when triggering the system accessibility dialog so the dialog isn't obscured.


## Key technical details

| Area | Approach |
|---|---|
| Display modes | `CGGetActiveDisplayList`, `CGDisplayCopyAllDisplayModes`, `CGDisplayCopyDisplayMode` |
| Resolution switching | `CGBeginDisplayConfiguration` / `CGCompleteDisplayConfiguration(.permanently)` — atomic for multi-display |
| HiDPI detection | `pixelWidth > width` on `CGDisplayMode` |
| Native resolution | Hardcoded table of known Apple panels + heuristic fallback |
| Aspect ratio badges | GCD-based ratio calculation with 1% tolerance; rendered as `NSTextAttachment` pill images |
| Global hotkeys | Carbon `RegisterEventHotKey` with OSType signature `'DSPL'` (0x4453504C) |
| Shortcut recording | `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` |
| Accessibility check | `AXIsProcessTrusted()` polled every 1.5s in background Task |
| Launch at login | `SMAppService.mainApp` |
| Preset matching | Three-tier: exact display ID → single-display fallback → mode-availability match |
| Resolution overlay | HUD window per display for shortcut-applied feedback (fade in/out) |
| Resolution stepping | Groups modes by dimensions, filtered by aspect ratio + HiDPI; ⌃⌥↑/⌃⌥↓ defaults |
| Auto-update | Sparkle 2.x via `SPUStandardUpdaterController`; appcast on GitHub Pages, ZIPs on GitHub Releases, EdDSA signed |


## Current state

- App icon is a placeholder.
- `FujiTests` target exists with unit tests for `DisplayMode` and resolution grouping logic. `PermissionsManaging` protocol + `MockPermissionsManager` enable further coverage.
