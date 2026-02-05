//
//  SettingsManager.swift
//  DisplayApp
//
//  Created by Stephen Uffelman on 1/24/26.
//

import AppKit
import Foundation
import SwiftUI

@MainActor
@Observable
final class SettingsManager {
    static let shared = SettingsManager()

    private let presetsKey = "displayPresets"
    private let launchAtLoginKey = "launchAtLogin"
    private let showInDockKey = "showInDock"

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

    init() {
        loadPresets()
    }

    private func loadPresets() {
        guard let data = UserDefaults.standard.data(forKey: presetsKey) else {
            presets = []
            return
        }

        do {
            presets = try JSONDecoder().decode([ResolutionPreset].self, from: data)
        } catch {
            print("Failed to decode presets: \(error)")
            presets = []
        }
    }

    private func savePresets() {
        do {
            let data = try JSONEncoder().encode(presets)
            UserDefaults.standard.set(data, forKey: presetsKey)
        } catch {
            print("Failed to encode presets: \(error)")
        }
    }

    func addPreset(_ preset: ResolutionPreset) {
        presets.append(preset)
        savePresets()
    }

    func updatePreset(_ preset: ResolutionPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            savePresets()
        }
    }

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

    func preset(for shortcut: KeyboardShortcut) -> ResolutionPreset? {
        return presets.first { $0.keyboardShortcut == shortcut }
    }

    private func updateDockVisibility() {
        if showInDock {
            NSApplication.shared.setActivationPolicy(.regular)
        } else {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }
}
