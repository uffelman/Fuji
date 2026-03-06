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
            defaults.set(enableIncrementShortcuts, forKey: DefaultsKeys.enableIncrementShortcuts)
        }
    }
    
    var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: DefaultsKeys.launchAtLogin)
            updateLaunchAtLogin(enabled: launchAtLogin)
        }
    }
    
    var showInDock: Bool {
        didSet {
            defaults.set(showInDock, forKey: DefaultsKeys.showInDock)
            updateDockVisibility()
        }
    }
    
    var showResolutionOverlay: Bool {
        didSet {
            defaults.set(showResolutionOverlay, forKey: DefaultsKeys.showResolutionOverlay)
        }
    }

    var incrementUpShortcut: KeyboardShortcut? {
        didSet {
            if let incrementUpShortcut {
                let data = try? JSONEncoder().encode(incrementUpShortcut)
                defaults.set(data, forKey: DefaultsKeys.incrementUpShortcut)
            } else {
                defaults.removeObject(forKey: DefaultsKeys.incrementUpShortcut)
            }
        }
    }

    var incrementDownShortcut: KeyboardShortcut? {
        didSet {
            if let incrementDownShortcut {
                let data = try? JSONEncoder().encode(incrementDownShortcut)
                defaults.set(data, forKey: DefaultsKeys.incrementDownShortcut)
            } else {
                defaults.removeObject(forKey: DefaultsKeys.incrementDownShortcut)
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
        
        enableIncrementShortcuts = defaults.bool(forKey: DefaultsKeys.enableIncrementShortcuts)
        launchAtLogin = defaults.bool(forKey: DefaultsKeys.launchAtLogin)
        showInDock = defaults.bool(forKey: DefaultsKeys.showInDock)
        showResolutionOverlay = defaults.bool(forKey: DefaultsKeys.showResolutionOverlay)
        
        if let data = defaults.data(forKey: DefaultsKeys.incrementUpShortcut) {
            incrementUpShortcut = try? JSONDecoder().decode(KeyboardShortcut.self, from: data)
        }
        if let data = defaults.data(forKey: DefaultsKeys.incrementDownShortcut) {
            incrementDownShortcut = try? JSONDecoder().decode(KeyboardShortcut.self, from: data)
        }
        
        loadPresets()
    }

    /// Loads presets from UserDefaults.
    ///
    /// Attempts to decode the stored preset data. If decoding fails or no data exists,
    /// initializes with an empty preset list.
    private func loadPresets() {
        guard let data = defaults.data(forKey: DefaultsKeys.displayPresets) else {
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
            defaults.set(data, forKey: DefaultsKeys.displayPresets)
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
