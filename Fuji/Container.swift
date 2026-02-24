//
//  Container.swift
//  Fuji
//
//  Created by Stephen Uffelman on 2/22/26.
//

import Foundation

@MainActor
final class Container {
    let displayManager = DisplayManager()
    let settingsManager = SettingsManager()
    let permissionsManager = PermissionsManager()
}
