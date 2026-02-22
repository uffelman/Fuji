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
    let keyboardShortcutManager: KeyboardShortcutManager
    let menuBarController: MenuBarController
    let onboardingWindowController: OnboardingWindowController
    let permissionsManager: any PermissionsManaging = PermissionsManager()
    let resolutionOverlayController: ResolutionOverlayController
    let settingsManager: any SettingsManaging = SettingsManager()
    
    init() {
        resolutionOverlayController = ResolutionOverlayController(
            settingsManager
        )
        keyboardShortcutManager = KeyboardShortcutManager(
            displayManager,
            settingsManager,
            permissionsManager,
            resolutionOverlayController
        )
        menuBarController = MenuBarController(
            displayManager,
            settingsManager,
            resolutionOverlayController
        )
        onboardingWindowController = OnboardingWindowController(
            permissionsManager
        )
    }
}
