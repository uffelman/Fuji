//
//  PresetEditorSheet.swift
//  DisplayApp
//
//  Created by Stephen Uffelman on 2/19/26.
//

import Foundation
import SwiftUI

/// A sheet view for creating or editing a resolution preset.
///
/// Provides an interface for naming the preset, selecting display modes for each display,
/// and optionally recording a keyboard shortcut. Supports both creating new presets and
/// editing existing ones.
struct PresetEditorSheet: View {
    let displayManager: any DisplayManaging
    let settingsManager: any SettingsManaging
    let preset: ResolutionPreset?
    let onSave: ((ResolutionPreset) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedModes: [CGDirectDisplayID: DisplayMode] = [:]
    @State private var keyboardShortcut: KeyboardShortcut?
    @State private var isRecordingShortcut = false
    @State private var userEditedName = false

    private let shortcutRecorder = ShortcutRecorder()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(preset == nil ? "New Preset" : "Edit Preset")
                .font(.title2)
                .fontWeight(.semibold)

            // Name field
            VStack(alignment: .leading, spacing: 8) {
                Text("Preset Name")
                    .font(.headline)
                TextField("Enter preset name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: name) { _, _ in
                        userEditedName = true
                    }
            }

            // Display configurations
            VStack(alignment: .leading, spacing: 8) {
                Text("Display Resolutions")
                    .font(.headline)

                Text("Select the resolution for each display")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(displayManager.displays) { display in
                    DisplayModeSelector(
                        display: display,
                        selectedMode: selectedModes[display.id],
                        onModeSelected: { mode in
                            selectedModes[display.id] = mode
                            updateDefaultName()
                        }
                    )
                }
            }

            // Keyboard shortcut
            VStack(alignment: .leading, spacing: 8) {
                Text("Keyboard Shortcut (Optional)")
                    .font(.headline)

                // Displays different UI states: recording, showing shortcut, or empty
                // When recording, shows a prompt. When a shortcut exists, displays it with a clear button.
                // Otherwise shows "No shortcut set" message. The Record/Cancel button toggles recording state.
                HStack {
                    if isRecordingShortcut {
                        Text("Press a key combination...")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(.rect(cornerRadius: 6))
                    } else if let shortcut = keyboardShortcut {
                        Text(shortcut.displayString)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(.rect(cornerRadius: 6))

                        Button("Clear") {
                            keyboardShortcut = nil
                        }
                        .buttonStyle(.borderless)
                    } else {
                        Text("No shortcut set")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(isRecordingShortcut ? "Cancel" : "Record Shortcut") {
                        if isRecordingShortcut {
                            shortcutRecorder.stopRecording()
                            isRecordingShortcut = false
                        } else {
                            isRecordingShortcut = true
                            shortcutRecorder.onShortcutRecorded = { shortcut in
                                keyboardShortcut = shortcut
                                isRecordingShortcut = false
                            }
                            shortcutRecorder.startRecording()
                        }
                    }
                }
            }

            Spacer()

            // Action buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    savePreset()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || selectedModes.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500, height: 500)
        .onAppear {
            if let preset = preset {
                name = preset.name
                keyboardShortcut = preset.keyboardShortcut
                for config in preset.configurations {
                    selectedModes[CGDirectDisplayID(config.displayID)] = config.mode
                }
                userEditedName = true
            } else {
                updateDefaultName()
            }
        }
    }

    /// Updates the preset name automatically based on selected display modes.
    ///
    /// Only updates if the user hasn't manually edited the name. For single displays,
    /// uses the full mode description. For multiple displays, combines their resolutions.
    private func updateDefaultName() {
        // Only update the name automatically if the user hasn't edited it
        guard !userEditedName else { return }
        
        // Generate a name based on selected resolutions
        if selectedModes.isEmpty {
            name = ""
        } else if selectedModes.count == 1, let mode = selectedModes.values.first {
            // Single display: use the mode's display string
            name = mode.displayString
        } else {
            // Multiple displays: combine their resolutions
            let sortedModes = selectedModes.sorted { $0.key < $1.key }
            name = sortedModes.map { _, mode in
                mode.shortDisplayString
            }.joined(separator: " + ")
        }
    }

    /// Saves the preset with current settings and dismisses the sheet.
    ///
    /// Creates a new `ResolutionPreset` from the current state. When editing an existing
    /// preset, the old record is removed first so the updated version takes its place in
    /// the list (position is preserved by `SettingsManager.updatePreset`).
    private func savePreset() {
        let configurations = selectedModes.map { displayID, mode in
            DisplayConfiguration(displayID: displayID, mode: mode)
        }

        let newPreset = ResolutionPreset(
            name: name,
            configurations: configurations,
            keyboardShortcut: keyboardShortcut
        )

        // When editing, remove the old record before handing the updated preset
        // to the caller — the caller's onSave handler re-inserts it.
        if let existingPreset = preset {
            settingsManager.deletePreset(existingPreset)
        }

        onSave?(newPreset)
        dismiss()
    }
}

/// A view for selecting a display mode from a list of available modes.
///
/// Shows the display's name and current selection, with a menu for choosing different modes.
private struct DisplayModeSelector: View {
    let display: Display
    let selectedMode: DisplayMode?
    let onModeSelected: (DisplayMode) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
                    .foregroundStyle(.secondary)

                Text(display.name)
                    .fontWeight(.medium)

                if display.isMain {
                    Text("Main")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .clipShape(.rect(cornerRadius: 4))
                }

                Spacer()

                if let mode = selectedMode {
                    Text(mode.displayString)
                        .foregroundStyle(.secondary)
                }
            }

            Menu {
                ForEach(display.modes) { mode in
                    Button(action: { onModeSelected(mode) }) {
                        HStack {
                            Text(mode.displayString)
                            if selectedMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(selectedMode?.displayString ?? "Select resolution...")
                        .foregroundStyle(selectedMode == nil ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))
                .clipShape(.rect(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(.rect(cornerRadius: 8))
    }
}

#Preview {
    PresetEditorSheet(
        displayManager: MockDisplayManager(),
        settingsManager: MockSettingsManager(),
        preset: nil,
        onSave: nil
    )
}
