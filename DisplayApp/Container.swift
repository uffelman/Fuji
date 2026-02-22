//
//  Container.swift
//  DisplayApp
//
//  Created by Stephen Uffelman on 2/22/26.
//

import Foundation

@MainActor
final class Container {
    let displayManager: any DisplayManaging = DisplayManager()
    let settingsManager: any SettingsManaging = SettingsManager()
    let permissionsManager: any PermissionsManaging = PermissionsManager()
    
    lazy var keyboardShortcutManager = KeyboardShortcutManager(
        displayManager,
        settingsManager,
        permissionsManager,
        resolutionOverlayController
    )
    lazy var menuBarController = MenuBarController(
        displayManager,
        settingsManager,
        resolutionOverlayController
    )
    lazy var onboardingWindowController = OnboardingWindowController(permissionsManager)
    lazy var resolutionOverlayController = ResolutionOverlayController(settingsManager)
}
