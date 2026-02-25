//
//  SettingsManager.swift
//  Fuji
//
//  Created by Stephen Uffelman on 1/24/26.
//

import AppKit
import OSLog
import ServiceManagement
import SwiftUI

/// Manages app settings and resolution presets.
///
/// This class handles persistence of user preferences including resolution presets,
/// launch at login settings, and dock visibility. Settings are stored using UserDefaults.
@MainActor
@Observable
final class SettingsManager {
    
    private let defaults: UserDefaults
    private(set) var presets: [ResolutionPreset] = []

    var enableIncrementShortcuts: Bool {
        didSet {
            defaults.set(enableIncrementShortcuts, forKey: Keys.enableIncrementShortcuts)
        }
    }
    
    var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            updateLaunchAtLogin(enabled: launchAtLogin)
        }
    }
    
    var showInDock: Bool {
        didSet {
            defaults.set(showInDock, forKey: Keys.showInDock)
            updateDockVisibility()
        }
    }
    
    var showResolutionOverlay: Bool {
        didSet {
            defaults.set(showResolutionOverlay, forKey: Keys.showResolutionOverlay)
        }
    }

    var incrementUpShortcut: KeyboardShortcut? {
        get {
            guard let data = defaults.data(forKey: Keys.incrementUpShortcut) else {
                return nil
            }
            return try? JSONDecoder().decode(KeyboardShortcut.self, from: data)
        }
        set {
            if let newValue {
                let data = try? JSONEncoder().encode(newValue)
                defaults.set(data, forKey: Keys.incrementUpShortcut)
            } else {
                defaults.removeObject(forKey: Keys.incrementUpShortcut)
            }
        }
    }

    var incrementDownShortcut: KeyboardShortcut? {
        get {
            guard let data = defaults.data(forKey: Keys.incrementDownShortcut) else {
                return nil
            }
            return try? JSONDecoder().decode(KeyboardShortcut.self, from: data)
        }
        set {
            if let newValue {
                let data = try? JSONEncoder().encode(newValue)
                defaults.set(data, forKey: Keys.incrementDownShortcut)
            } else {
                defaults.removeObject(forKey: Keys.incrementDownShortcut)
            }
        }
    }

    var effectiveIncrementUpShortcut: KeyboardShortcut {
        incrementUpShortcut ?? .defaultIncrementUp
    }

    var effectiveIncrementDownShortcut: KeyboardShortcut {
        incrementDownShortcut ?? .defaultIncrementDown
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register()
        
        enableIncrementShortcuts = defaults.bool(forKey: Keys.enableIncrementShortcuts)
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        showInDock = defaults.bool(forKey: Keys.showInDock)
        showResolutionOverlay = defaults.bool(forKey: Keys.showResolutionOverlay)
        
        loadPresets()
    }

    /// Loads presets from UserDefaults.
    ///
    /// Attempts to decode the stored preset data. If decoding fails or no data exists,
    /// initializes with an empty preset list.
    private func loadPresets() {
        guard let data = defaults.data(forKey: Keys.displayPresets) else {
            presets = []
            return
        }

        do {
            presets = try JSONDecoder().decode([ResolutionPreset].self, from: data)
        } catch {
            Logger.app.error("Failed to decode presets: \(error)")
            presets = []
        }
    }

    /// Saves the current presets to UserDefaults.
    ///
    /// Encodes the preset array as JSON and persists it. Logs errors if encoding fails.
    private func savePresets() {
        do {
            let data = try JSONEncoder().encode(presets)
            defaults.set(data, forKey: Keys.displayPresets)
        } catch {
            Logger.app.error("Failed to encode presets: \(error)")
        }
    }

    /// Adds a new preset to the list and saves it.
    ///
    /// - Parameter preset: The preset to add
    func addPreset(_ preset: ResolutionPreset) {
        presets.append(preset)
        savePresets()
    }

    /// Updates an existing preset with new values.
    ///
    /// Finds the preset by ID and replaces it with the updated version.
    /// - Parameter preset: The updated preset
    func updatePreset(_ preset: ResolutionPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            savePresets()
        }
    }

    /// Deletes a preset from the list.
    ///
    /// - Parameter preset: The preset to delete
    func deletePreset(_ preset: ResolutionPreset) {
        presets.removeAll { $0.id == preset.id }
        savePresets()
    }

    func deletePreset(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
        savePresets()
    }

    func movePreset(from source: IndexSet, to destination: Int) {
        presets.move(fromOffsets: source, toOffset: destination)
        savePresets()
    }

    /// Finds a preset that has the given keyboard shortcut.
    ///
    /// - Parameter shortcut: The keyboard shortcut to search for
    /// - Returns: The matching preset, or nil if none is found
    func preset(for shortcut: KeyboardShortcut) -> ResolutionPreset? {
        return presets.first { $0.keyboardShortcut == shortcut }
    }

    /// Updates the app's dock visibility based on the current setting.
    ///
    /// Changes the app's activation policy between regular (visible in dock)
    /// and accessory (menu bar only).
    private func updateDockVisibility() {
        if showInDock {
            NSApplication.shared.setActivationPolicy(.regular)
        } else {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }
    
    /// Registers or unregisters the app to launch at login using SMAppService.
    ///
    /// - Parameter enabled: Whether to enable or disable launch at login
    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger.app.error("Failed to update launch at login: \(error)")
        }
    }
}

private enum Keys {
    static let displayPresets = "displayPresets"
    static let enableIncrementShortcuts = "enableIncrementShortcuts"
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
            Keys.launchAtLogin: false,
            Keys.showInDock: false,
            Keys.showResolutionOverlay: true,
            Keys.enableIncrementShortcuts: true
        ])
    }
}
