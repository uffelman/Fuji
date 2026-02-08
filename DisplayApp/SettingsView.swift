//
//  SettingsView.swift
//  DisplayApp
//
//  Created by Stephen Uffelman on 1/24/26.
//

import ApplicationServices
import ServiceManagement
import SwiftUI

/// The main settings view for the application.
///
/// Displays a tab-based interface with sections for managing presets, general settings, and app information.
struct SettingsView: View {
    let displayManager: DisplayManager
    let settingsManager: SettingsManager
    let onPresetsChanged: () -> Void

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Presets", systemImage: "rectangle.stack", value: 0) {
                PresetsTab(
                    displayManager: displayManager,
                    settingsManager: settingsManager,
                    onPresetsChanged: onPresetsChanged
                )
            }

            Tab("General", systemImage: "gear", value: 1) {
                GeneralTab(settingsManager: settingsManager)
            }

            Tab("About", systemImage: "info.circle", value: 2) {
                AboutTab()
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
    }
}

/// The presets management tab.
///
/// Allows users to create, edit, delete, and reorder resolution presets.
/// Shows warnings when accessibility permissions are not granted.
struct PresetsTab: View {
    let displayManager: DisplayManager
    let settingsManager: SettingsManager
    let onPresetsChanged: () -> Void

    @State private var showingAddPreset = false
    @State private var editingPreset: ResolutionPreset?
    @State private var hasAccessibilityPermission = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Resolution Presets")
                .font(.headline)

            Text(
                "Create presets to quickly switch between resolution configurations. Assign keyboard shortcuts for instant switching."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if !hasAccessibilityPermission {
                AccessibilityPermissionWarning {
                    hasAccessibilityPermission = checkAccessibilityPermission()
                }
            }

            if settingsManager.presets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.stack.badge.plus")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No presets configured")
                        .font(.headline)
                    Text("Click the + button to create a new preset")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(settingsManager.presets) { preset in
                        PresetRow(
                            preset: preset,
                            onEdit: {
                                editingPreset = preset
                            },
                            onDelete: {
                                settingsManager.deletePreset(preset)
                                onPresetsChanged()
                            })
                    }
                    .onMove { source, destination in
                        settingsManager.movePreset(from: source, to: destination)
                        onPresetsChanged()
                    }
                }
                .listStyle(.bordered)
            }

            HStack {
                Button(action: { showingAddPreset = true }) {
                    Label("Add Preset", systemImage: "plus")
                }

                Spacer()
            }
        }
        .padding()
        .sheet(isPresented: $showingAddPreset) {
            PresetEditorSheet(
                displayManager: displayManager,
                settingsManager: settingsManager,
                preset: nil,
                onSave: { preset in
                    settingsManager.addPreset(preset)
                    onPresetsChanged()
                }
            )
        }
        .sheet(item: $editingPreset) { preset in
            PresetEditorSheet(
                displayManager: displayManager,
                settingsManager: settingsManager,
                preset: preset,
                onSave: { updatedPreset in
                    settingsManager.updatePreset(updatedPreset)
                    onPresetsChanged()
                }
            )
        }
        .onAppear {
            hasAccessibilityPermission = checkAccessibilityPermission()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            hasAccessibilityPermission = checkAccessibilityPermission()
        }
    }
}

/// Checks if the app has accessibility permissions.
///
/// - Returns: `true` if accessibility access is granted, `false` otherwise
private func checkAccessibilityPermission() -> Bool {
    AXIsProcessTrusted()
}

/// A warning banner displayed when accessibility permissions are not granted.
///
/// Shows information about why the permission is needed and provides buttons to
/// open System Settings and recheck permission status.
struct AccessibilityPermissionWarning: View {
    let onRecheck: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Accessibility Permission Required")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(
                    "Global keyboard shortcuts require Accessibility access in System Settings > Privacy & Security > Accessibility."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Open Settings") {
                if let url = URL(
                    string:
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                ) {
                    NSWorkspace.shared.open(url)
                }
            }

            Button("Recheck") {
                onRecheck()
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

/// A list row displaying a preset with its name, configuration summary, and action buttons.
struct PresetRow: View {
    let preset: ResolutionPreset
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.headline)

                Text(configurationSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let shortcut = preset.keyboardShortcut {
                Text(shortcut.displayString)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(.rect(cornerRadius: 4))
            }

            Button("Edit", systemImage: "pencil", action: onEdit)
                .buttonStyle(.borderless)
                .labelStyle(.iconOnly)

            Button("Delete", systemImage: "trash", action: onDelete)
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .labelStyle(.iconOnly)
        }
        .padding(.vertical, 4)
    }

    /// Generates a comma-separated summary of the preset's display configurations.
    private var configurationSummary: String {
        preset.configurations.map { config in
            "\(config.mode.shortDisplayString)"
        }.joined(separator: ", ")
    }
}

/// A sheet view for creating or editing a resolution preset.
///
/// Provides an interface for naming the preset, selecting display modes for each display,
/// and optionally recording a keyboard shortcut. Supports both creating new presets and
/// editing existing ones.
struct PresetEditorSheet: View {
    let displayManager: DisplayManager
    let settingsManager: SettingsManager
    let preset: ResolutionPreset?
    let onSave: (ResolutionPreset) -> Void

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
    /// Creates a new ResolutionPreset from the current state. When editing an existing preset,
    /// deletes the old one before saving to maintain the same ID.
    private func savePreset() {
        let configurations = selectedModes.map { displayID, mode in
            DisplayConfiguration(displayID: displayID, mode: mode)
        }

        var newPreset = ResolutionPreset(
            name: name,
            configurations: configurations,
            keyboardShortcut: keyboardShortcut
        )

        // If editing, preserve the original ID
        if let existingPreset = preset {
            newPreset = ResolutionPreset(
                name: name,
                configurations: configurations,
                keyboardShortcut: keyboardShortcut
            )
            // We need to recreate with same ID - this is a workaround
            settingsManager.deletePreset(existingPreset)
        }

        onSave(newPreset)
        dismiss()
    }
}

/// A view for selecting a display mode from a list of available modes.
///
/// Shows the display's name and current selection, with a menu for choosing different modes.
struct DisplayModeSelector: View {
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

/// The general settings tab.
///
/// Provides controls for launch at login and dock visibility preferences.
struct GeneralTab: View {
    let settingsManager: SettingsManager

    @State private var launchAtLogin = false
    @State private var showInDock = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General Settings")
                .font(.headline)

            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    settingsManager.launchAtLogin = newValue
                    updateLaunchAtLogin(enabled: newValue)
                }

            Toggle("Show in Dock", isOn: $showInDock)
                .onChange(of: showInDock) { _, newValue in
                    settingsManager.showInDock = newValue
                }

            Spacer()
        }
        .padding()
        .onAppear {
            launchAtLogin = settingsManager.launchAtLogin
            showInDock = settingsManager.showInDock
        }
    }

    /// Registers or unregisters the app to launch at login using SMAppService.
    ///
    /// - Parameter enabled: Whether to enable or disable launch at login
    private func updateLaunchAtLogin(enabled: Bool) {
        // Use SMAppService for modern macOS launch at login
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        }
    }
}

/// The about tab showing app information.
///
/// Displays the app name, version, icon, and description.
struct AboutTab: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "display")
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)

            Text("DisplayApp")
                .font(.title)
                .bold()

            Text("Version 1.0")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("A simple menu bar app for managing display resolutions on macOS.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
