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
    private let displayManager = DisplayManager()
    private let keyboardShortcutManager: KeyboardShortcutManager
    private let menuBarController: MenuBarController
    private let onboardingWindowController: OnboardingWindowController
    private let permissionsManager = PermissionsManager()
    private let settingsManager: any SettingsManaging = SettingsManager()
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        keyboardShortcutManager = KeyboardShortcutManager(
            displayManager: displayManager,
            settingsManager: settingsManager,
            permissionsManager: permissionsManager
        )
        onboardingWindowController = OnboardingWindowController(permissions: permissionsManager)
        
        menuBarController = MenuBarController(
            displayManager: displayManager,
            settingsManager: settingsManager
        )
        
        appDelegate.keyboardShortcutManager = keyboardShortcutManager
        appDelegate.menuBarController = menuBarController
        appDelegate.onboardingWindowController = onboardingWindowController
        appDelegate.permissionsManager = permissionsManager
        appDelegate.settingsManager = settingsManager
    }

    var body: some Scene {
        Settings {
            SettingsView(
                displayManager: displayManager,
                settingsManager: settingsManager,
                onPresetsChanged: {
                    // Rebuild menu when presets change
                    NotificationCenter.default.post(name: .presetsDidChange, object: nil)
                }
            )
            .frame(
                width: SettingsView.size.width,
                height: SettingsView.size.height
            )
        }
    }
}

/// Notification name posted when presets are modified.
extension Notification.Name {
    static let presetsDidChange = Notification.Name("presetsDidChange")
}
