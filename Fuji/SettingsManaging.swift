//
//  SettingsManager.swift
//  Fuji
//
//  Created by Stephen Uffelman on 1/24/26.
//

import AppKit
import OSLog
import SwiftUI

@MainActor
protocol SettingsManaging: AnyObject {
    
    var launchAtLogin: Bool { get set }
    var presets: [ResolutionPreset] { get }
    var showInDock: Bool { get set }
    var showResolutionOverlay: Bool { get set }
    
    func addPreset(_ preset: ResolutionPreset)
    func updatePreset(_ preset: ResolutionPreset)
    func deletePreset(_ preset: ResolutionPreset)
    func deletePreset(at offsets: IndexSet)
    func movePreset(from source: IndexSet, to destination: Int)
    func preset(for shortcut: KeyboardShortcut) -> ResolutionPreset?
}

/// Manages app settings and resolution presets.
///
/// This class handles persistence of user preferences including resolution presets,
/// launch at login settings, and dock visibility. Settings are stored using UserDefaults.
@MainActor
@Observable
final class SettingsManager: SettingsManaging {
    
    private let presetsKey = "displayPresets"
    private let launchAtLoginKey = "launchAtLogin"
    private let showInDockKey = "showInDock"
    private let showResolutionOverlayKey = "showResolutionOverlay"

    private(set) var presets: [ResolutionPreset] = []

    var launchAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: launchAtLoginKey) }
        set { UserDefaults.standard.set(newValue, forKey: launchAtLoginKey) }
    }

    var showInDock: Bool {
        get { UserDefaults.standard.bool(forKey: showInDockKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: showInDockKey)
            updateDockVisibility()
        }
    }
    
    var showResolutionOverlay: Bool {
        get { UserDefaults.standard.bool(forKey: showResolutionOverlayKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: showResolutionOverlayKey)
        }
    }

    init() {
        registerDefaults()
        loadPresets()
    }

    /// Loads presets from UserDefaults.
    ///
    /// Attempts to decode the stored preset data. If decoding fails or no data exists,
    /// initializes with an empty preset list.
    private func loadPresets() {
        guard let data = UserDefaults.standard.data(forKey: presetsKey) else {
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
    
    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            launchAtLoginKey: false,
            showInDockKey: false,
            showResolutionOverlayKey: true
        ])
    }

    /// Saves the current presets to UserDefaults.
    ///
    /// Encodes the preset array as JSON and persists it. Logs errors if encoding fails.
    private func savePresets() {
        do {
            let data = try JSONEncoder().encode(presets)
            UserDefaults.standard.set(data, forKey: presetsKey)
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
}

@MainActor
@Observable
final class MockSettingsManager: SettingsManaging {
    static let preview = MockSettingsManager()
    
    var presets: [ResolutionPreset] = []
    var launchAtLogin = false
    var showInDock = false
    var showResolutionOverlay = true
    
    func addPreset(_ preset: ResolutionPreset) {}
    
    func updatePreset(_ preset: ResolutionPreset) {}
    
    func deletePreset(_ preset: ResolutionPreset) {}
    
    func deletePreset(at offsets: IndexSet) {}
    
    func movePreset(from source: IndexSet, to destination: Int) {}
    
    func preset(for shortcut: KeyboardShortcut) -> ResolutionPreset? { nil }
}
