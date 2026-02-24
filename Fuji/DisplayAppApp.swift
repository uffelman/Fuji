//
//  FujiApp.swift
//  Fuji
//
//  Created by Stephen Uffelman on 1/24/26.
//

import AppKit
import ApplicationServices
import SwiftUI

/// The main app structure for Fuji.
///
/// Configures the SwiftUI app with a Settings scene for managing display presets and preferences.
@main
struct FujiApp: App {
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
                onPresetsChanged: appDelegate.updateMenuBarAndKeyboardShortcuts
            )
            .frame(
                width: SettingsViewMetrics.size.width,
                height: SettingsViewMetrics.size.height
            )
        }
    }
}
