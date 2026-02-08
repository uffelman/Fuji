//
//  DisplayAppApp.swift
//  DisplayApp
//
//  Created by Stephen Uffelman on 1/24/26.
//

import AppKit
import ApplicationServices
import SwiftUI

/// The main app structure for DisplayApp.
///
/// Configures the SwiftUI app with a Settings scene for managing display presets and preferences.
@main
struct DisplayAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                displayManager: DisplayManager.shared,
                settingsManager: SettingsManager.shared,
                onPresetsChanged: {
                    // Rebuild menu when presets change
                    NotificationCenter.default.post(name: .presetsDidChange, object: nil)
                }
            )
            .frame(minWidth: 500, minHeight: 400)
        }
    }
}

/// Notification name posted when presets are modified.
extension Notification.Name {
    static let presetsDidChange = Notification.Name("presetsDidChange")
}

/// Application delegate that initializes core app components.
///
/// Sets up the menu bar controller, keyboard shortcut manager, and handles
/// app lifecycle events including launch-time initialization and accessibility permissions.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController!
    private var keyboardShortcutManager: KeyboardShortcutManager!
    private let displayManager = DisplayManager.shared
    private let settingsManager = SettingsManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon by default (menu bar app)
        if !settingsManager.showInDock {
            NSApplication.shared.setActivationPolicy(.accessory)
        }

        // Request accessibility permissions (adds app to the list in System Settings)
        requestAccessibilityPermission()

        // Initialize menu bar controller
        menuBarController = MenuBarController(
            displayManager: displayManager,
            settingsManager: settingsManager
        )

        // Initialize keyboard shortcut manager
        keyboardShortcutManager = KeyboardShortcutManager(
            displayManager: displayManager,
            settingsManager: settingsManager
        )

        // Register existing shortcuts with a slight delay to ensure system is ready
        // This is especially important when the app launches at login
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.keyboardShortcutManager.refreshHotKeys()
        }

        // Handle shortcut triggers
        keyboardShortcutManager.onShortcutTriggered = { [weak self] _ in
            self?.menuBarController.rebuildMenu()
        }

        // Listen for preset changes from Settings window
        NotificationCenter.default.addObserver(
            forName: .presetsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.menuBarController.rebuildMenu()
            self?.keyboardShortcutManager.refreshHotKeys()
        }
        
        // Re-register shortcuts when app becomes active (e.g., settings window opened)
        // This helps recover from launch-time registration failures
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Only re-register if we don't have all shortcuts registered
            guard let self = self else { return }
            let expectedShortcutCount = self.settingsManager.presets.filter { $0.keyboardShortcut != nil }.count
            if self.keyboardShortcutManager.registeredHotKeyCount != expectedShortcutCount {
                print("App became active - re-registering shortcuts (expected: \(expectedShortcutCount), current: \(self.keyboardShortcutManager.registeredHotKeyCount))")
                self.keyboardShortcutManager.refreshHotKeys()
            }
        }
    }

    /// Prevents the app from terminating when all windows are closed.
    ///
    /// This is essential for menu bar apps that should continue running in the background.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    /// Requests accessibility permissions from the system.
    ///
    /// Shows the system prompt to add the app to the Accessibility list in System Settings.
    /// This is required for global keyboard shortcuts to function.
    private func requestAccessibilityPermission() {
        // Show prompt and add app to Accessibility list in System Settings
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
