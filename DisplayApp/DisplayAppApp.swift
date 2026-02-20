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
    private let displayManager: any DisplayManaging
    private let settingsManager: any SettingsManaging
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        if ProcessInfo.processInfo.isSwiftUIPreview {
            displayManager = MockDisplayManager.preview
            settingsManager = MockSettingsManager.preview
        } else {
            let displayManager = DisplayManager()
            self.displayManager = displayManager
            settingsManager = SettingsManager()
            
            appDelegate.displayManager = displayManager
            appDelegate.permissionsManager = PermissionsManager()
            appDelegate.settingsManager = settingsManager
        }
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
