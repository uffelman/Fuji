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
