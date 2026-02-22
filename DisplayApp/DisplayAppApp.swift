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
    
    private let container = Container()
    
    init() {
        appDelegate.container = container
    }

    var body: some Scene {
        Settings {
            SettingsView(
                displayManager: container.displayManager,
                settingsManager: container.settingsManager,
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
