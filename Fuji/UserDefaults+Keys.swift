//
//  UserDefaults+Keys.swift
//  Fuji
//
//  Created by Stephen Uffelman on 2/27/26.
//

import Foundation

enum DefaultsKeys {
    static let displayPresets = "displayPresets"
    static let enableIncrementShortcuts = "enableIncrementShortcuts"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let incrementDownShortcut = "incrementDownShortcut"
    static let incrementUpShortcut = "incrementUpShortcut"
    static let launchAtLogin = "launchAtLogin"
    static let showInDock = "showInDock"
    static let showResolutionOverlay = "showResolutionOverlay"
}

extension UserDefaults {
    /// Defaults without a persistence layer, designed for use in previews.
    static var preview: UserDefaults {
        let previewDefaults = UserDefaults(suiteName: "PreviewDefaults")!
            previewDefaults.removePersistentDomain(forName: "PreviewDefaults")
        return previewDefaults
    }
    
    /// Sets any unset values for the keys to the defaults specified.
    func register() {
        register(defaults: [
            DefaultsKeys.launchAtLogin: false,
            DefaultsKeys.showInDock: false,
            DefaultsKeys.showResolutionOverlay: true,
            DefaultsKeys.enableIncrementShortcuts: true
        ])
    }
}
