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
            // Sheet title
            Text(preset == nil ? "New Preset" : "Edit Preset")
                .font(.system(size: 17, weight: .semibold))

            // Preset Name
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("Preset Name")
                TextField("Enter preset name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13.5))
                    .onChange(of: name) { _, _ in
                        userEditedName = true
                    }
            }

            // Display Resolutions
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("Display Resolutions")

                VStack(spacing: 8) {
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
            }

            // Keyboard Shortcut
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("Keyboard Shortcut (Optional)")

                HStack(spacing: 10) {
                    if isRecordingShortcut {
                        Text("Press a key combination...")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.accentColor.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color.accentColor.opacity(0.2), lineWidth: 1)
                            )
                            .clipShape(.rect(cornerRadius: 6))
                    } else if let shortcut = keyboardShortcut {
                        Text(shortcut.displayString)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.separatorColor).opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color(.separatorColor), lineWidth: 1)
                            )
                            .clipShape(.rect(cornerRadius: 6))

                        Button {
                            keyboardShortcut = nil
                        } label: {
                            Text("× Clear")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("No shortcut set")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    PillButton(
                        isRecordingShortcut ? "Cancel" : "Record Shortcut",
                        style: .monochrome
                    ) {
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

            // Divider above action buttons
            Divider()

            // Action buttons — right-aligned
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

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

// MARK: - Section Label

/// An uppercase section label matching the design system used across settings views.
///
/// Renders 10.5pt semibold small-caps text in the secondary foreground color,
/// matching the metadata labels in ``AboutSettingsTab`` and form headers in ``GeneralSettingsTab``.
private struct SectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold).smallCaps())
            .foregroundStyle(.secondary)
    }
}

// MARK: - Display Mode Selector

/// A card for selecting a display mode from a list of available modes.
///
/// Shows the display's name and icon in a header row, separated by a divider from
/// a dropdown menu for choosing a resolution mode. Uses `controlBackgroundColor`
/// with 10pt corner radius to match the settings form card design.
private struct DisplayModeSelector: View {
    let display: Display
    let selectedMode: DisplayMode?
    let onModeSelected: (DisplayMode) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header row: icon + name + optional Main badge
            HStack(spacing: 8) {
                Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                Text(display.name)
                    .font(.system(size: 13.5, weight: .medium))

                if display.isMain {
                    Text("Main")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 1)
                        )
                        .clipShape(.rect(cornerRadius: 4))
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Resolution dropdown
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
                HStack(spacing: 8) {
                    Text(selectedMode?.displayString ?? "Select resolution...")
                        .font(.system(size: 13))
                        .foregroundStyle(selectedMode == nil ? .tertiary : .primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .clipShape(.rect(cornerRadius: 7))
            }
            .menuStyle(.borderlessButton)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color(.controlBackgroundColor))
        .clipShape(.rect(cornerRadius: 10))
    }
}

#Preview {
    PresetEditorSheet(
        displayManager: MockDisplayManager.preview,
        settingsManager: MockSettingsManager.preview,
        preset: nil,
        onSave: nil
    )
}
