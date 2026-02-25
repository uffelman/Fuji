//
//  AppDelegate.swift
//  Fuji
//
//  Created by Stephen Uffelman on 2/8/26.
//

import AppKit
import OSLog
import SwiftUI

/// Application delegate that initializes core app components.
///
/// Sets up the menu bar controller, keyboard shortcut manager, and handles
/// app lifecycle events including launch-time initialization and accessibility permissions.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    var container: Container!
    
    private lazy var keyboardShortcutManager = KeyboardShortcutManager(
        displayManager: container.displayManager,
        settingsManager: container.settingsManager,
        permissionsManager: container.permissionsManager,
        resolutionOverlayController: resolutionOverlayController
    )
    private lazy var menuBarController = MenuBarController(
        displayManager: container.displayManager,
        resolutionOverlayController: resolutionOverlayController,
        settingsManager: container.settingsManager
    )
    private lazy var onboardingWindowController = OnboardingWindowController(
        permissions: container.permissionsManager
    )
    private lazy var resolutionOverlayController = ResolutionOverlayController(
        settingsManager: container.settingsManager
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !ProcessInfo.processInfo.isSwiftUIPreview else { return }
        
        // Show item in menu bar
        menuBarController.setupStatusItem()
        
        // Configure settings factory closure
        menuBarController.makeSettingsViewController = { [weak self] in
            guard let self else { return nil }
            return NSHostingController(
                rootView: SettingsView(
                    displayManager: self.container.displayManager,
                    settingsManager: self.container.settingsManager,
                    onPresetsChanged: { [weak self] in
                        self?.updateMenuBarAndKeyboardShortcuts()
                    }
                )
            )
        }
        
        // Hide dock icon by default (menu bar app)
        if !container.settingsManager.showInDock {
            NSApplication.shared.setActivationPolicy(.accessory)
        }

        // Show onboarding once on first launch. After the user has seen it,
        // it will not appear again unless the debug toggle forces it.
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        #if DEBUG
        let forceOnboarding = DebugSettings.alwaysShowOnboarding
        let shouldShowOnboarding = forceOnboarding || !hasCompletedOnboarding
        #else
        let shouldShowOnboarding = !hasCompletedOnboarding
        #endif
        if shouldShowOnboarding {
            onboardingWindowController.show(startOnPage: 0)
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }

        // Register existing shortcuts with a slight delay to ensure system is ready
        // This is especially important when the app launches at login
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            self?.keyboardShortcutManager.refreshHotKeys()
        }

        // Handle shortcut triggers
        keyboardShortcutManager.onShortcutTriggered = { [weak self] _ in
            MainActor.assumeIsolated {
                self?.menuBarController.rebuildMenu()
            }
        }

        // Handle increment/decrement triggers
        keyboardShortcutManager.onIncrementTriggered = { [weak self] increase in
            MainActor.assumeIsolated {
                self?.menuBarController.incrementResolution(increase: increase)
            }
        }
        
        // Re-register shortcuts when app becomes active (e.g., settings window opened)
        // This helps recover from launch-time registration failures
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                // Only re-register if we don't have all shortcuts registered
                let expectedPresetCount = self.container.settingsManager.presets.filter { $0.keyboardShortcut != nil }.count
                let expectedIncrementCount = self.container.settingsManager.enableIncrementShortcuts ? 2 : 0
                let expectedShortcutCount = expectedPresetCount + expectedIncrementCount
                if self.keyboardShortcutManager.registeredHotKeyCount != expectedShortcutCount {
                    Logger.app.info("App became active - re-registering shortcuts (expected: \(expectedShortcutCount), current: \(self.keyboardShortcutManager.registeredHotKeyCount))")
                    self.keyboardShortcutManager.refreshHotKeys()
                }
            }
        }
    }
    
    /// Rebuilds the menu and keyboard shortcuts.
    ///
    /// Must be called any time the resolution presets change.
    func updateMenuBarAndKeyboardShortcuts() {
        menuBarController.rebuildMenu()
        keyboardShortcutManager.refreshHotKeys()
    }

    /// Prevents the app from terminating when all windows are closed.
    ///
    /// This is essential for menu bar apps that should continue running in the background.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
