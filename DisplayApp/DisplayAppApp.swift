//
//  DisplayAppApp.swift
//  DisplayApp
//
//  Created by Stephen Uffelman on 1/24/26.
//

import AppKit
import ApplicationServices
import SwiftUI

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

extension Notification.Name {
    static let presetsDidChange = Notification.Name("presetsDidChange")
}

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

        // Register existing shortcuts
        keyboardShortcutManager.refreshHotKeys()

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
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func requestAccessibilityPermission() {
        // Show prompt and add app to Accessibility list in System Settings
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
