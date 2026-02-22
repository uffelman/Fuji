//
//  AppDelegate.swift
//  DisplayApp
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

        // Show onboarding whenever the app launches without accessibility access.
        // The window is dismissed via its own close button or internal navigation,
        // and will not reappear until the next launch.
        //
        // Because we already know permissions are missing at this point, we skip
        // straight to the permissions page (startOnPage: 1) so the user is not
        // presented with a welcome screen they must click through first.
        //
        // In debug builds, the developer toggle can force the full welcome flow
        // (startOnPage: 0) to show at every launch regardless of permission state.
        #if DEBUG
        let forceOnboarding = UserDefaults.standard.bool(forKey: DebugSettings.forceOnboardingKey)
        if forceOnboarding || !container.permissionsManager.isAccessibilityTrusted {
            // Full welcome flow when force-enabled so the developer can preview both pages;
            // permissions-only page when triggered naturally by missing access.
            onboardingWindowController.show(startOnPage: forceOnboarding ? 0 : 1)
        }
        #else
        if !container.permissionsManager.isAccessibilityTrusted {
            onboardingWindowController.show(startOnPage: 1)
        }
        #endif

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
                let expectedShortcutCount = self.container.settingsManager.presets.filter { $0.keyboardShortcut != nil }.count
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
