# DisplayApp — Project Context

> **Keep this file updated.** When you add a new manager, feature, or significant architectural change, update the relevant section below so the next session starts with accurate context.

See `agents.md` for coding rules (Swift/SwiftUI conventions, API preferences, project structure guidelines).


## What the app is

DisplayApp is a **macOS menu bar utility** that lets users browse and switch display resolutions, save named presets, and trigger presets via global keyboard shortcuts. It has no main window — it lives entirely in the menu bar (`LSUIElement = true`).

- **Platform:** macOS 26.2+
- **Language:** Swift 6.2, strict concurrency
- **UI:** SwiftUI + AppKit (NSStatusItem menu, NSWindow for settings/onboarding)
- **Dependencies:** None (no third-party frameworks)
- **Tests:** None yet (protocol+mock pattern is in place for future unit tests)
- **Build:** Single-target Xcode project, no SPM packages


## File map

```
DisplayApp/
├── DisplayAppApp.swift              @main entry; Settings scene
├── AppDelegate.swift                Startup orchestration, wires all managers
├── DisplayManager.swift             Core Graphics display enumeration + mode switching
├── DisplayConfiguration.swift       Value type pairing a display ID with a mode
├── ResolutionPreset.swift           Preset model with smart multi-display matching
├── SettingsManager.swift            UserDefaults persistence (presets, preferences)
├── MenuBarController.swift          NSStatusItem + dynamic NSMenu construction
├── SettingsView.swift               Settings window (tabs: presets, general, about)
├── KeyboardShortcut.swift           Value type: Carbon keycode + modifier flags
├── KeyboardShortcutManager.swift    Carbon hotkey registration + ShortcutRecorder
├── OnboardingView.swift             Two-page SwiftUI onboarding flow
├── OnboardingWindowController.swift Floating NSWindow hosting onboarding
├── PermissionsManager.swift         AXIsProcessTrusted polling + protocol + mock
├── DebugSettings.swift              #if DEBUG: force-onboarding flag
├── Info.plist                       LSUIElement = true
└── Assets.xcassets/                 App icon, accent color
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
| Notifications | `UNUserNotificationCenter` for shortcut-applied feedback |


## Current state

- Working title "DisplayApp" — final name TBD.
- App icon is a placeholder.
- No test target exists yet; `PermissionsManaging` protocol + `MockPermissionsManager` are ready for unit testing.
