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
    let displayManager: any DisplayManaging
    let settingsManager: any SettingsManaging
    let onPresetsChanged: (() -> Void)?

    @State private var selectedTab = SettingsTab.presets
    @Namespace private var tabAnimation

    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar — animation scoped here so only the pill slides,
            // not the tab content below.
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    SettingsTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        namespace: tabAnimation
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(3)
            .background(Color(.separatorColor).opacity(0.3))
            .clipShape(.rect(cornerRadius: 9))
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Tab content — no animation here to avoid content flicker.
            Group {
                switch selectedTab {
                case .presets:
                    PresetsTab(
                        displayManager: displayManager,
                        settingsManager: settingsManager,
                        onPresetsChanged: onPresetsChanged
                    )
                case .general:
                    GeneralTab(settingsManager: settingsManager)
                case .about:
                    AboutTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal)
        .padding(.bottom)
        .frame(minWidth: 500, minHeight: 400)
    }
}

/// A single button in the custom settings tab bar.
struct SettingsTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                Text(tab.title)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 5)
            .foregroundStyle(isSelected ? .primary : .secondary)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(.windowBackgroundColor))
                        .shadow(color: .primary.opacity(0.08), radius: 2, y: 1)
                        .matchedGeometryEffect(id: "activeTab", in: namespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Identifies the settings tabs.
enum SettingsTab: Int, CaseIterable {
    case presets, general, about

    var title: String {
        switch self {
        case .presets: "Presets"
        case .general: "General"
        case .about: "About"
        }
    }

    var icon: String {
        switch self {
        case .presets: "list.bullet.rectangle"
        case .general: "gearshape"
        case .about: "info.circle"
        }
    }
}

/// The presets management tab.
///
/// Allows users to create, edit, delete, and reorder resolution presets.
/// Shows warnings when accessibility permissions are not granted.
struct PresetsTab: View {
    let displayManager: any DisplayManaging
    let settingsManager: any SettingsManaging
    let onPresetsChanged: (() -> Void)?

    @State private var showingAddPreset = false
    @State private var editingPreset: ResolutionPreset?
    @State private var hasAccessibilityPermission = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Resolution Presets")
                    .font(.system(size: 15, weight: .semibold))

                Text(
                    "Quick-switch between display configurations using keyboard shortcuts."
                )
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }

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
                VStack(spacing: 0) {
                    ForEach(settingsManager.presets.enumerated(), id: \.element.id) { index, preset in
                        PresetRow(
                            preset: preset,
                            onEdit: {
                                editingPreset = preset
                            },
                            onDelete: {
                                settingsManager.deletePreset(preset)
                                onPresetsChanged?()
                            })

                        if index < settingsManager.presets.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(Color(.controlBackgroundColor))
                .clipShape(.rect(cornerRadius: 10))
            }

            Button(action: { showingAddPreset = true }) {
                Label("Add Preset", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .sheet(isPresented: $showingAddPreset) {
            PresetEditorSheet(
                displayManager: displayManager,
                settingsManager: settingsManager,
                preset: nil,
                onSave: { preset in
                    settingsManager.addPreset(preset)
                    onPresetsChanged?()
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
                    onPresetsChanged?()
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
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(preset.name)
                    .font(.system(size: 13.5, weight: .medium))

                Text(configurationSummary)
                    .font(.system(size: 11.5).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let shortcut = preset.keyboardShortcut {
                Text(shortcut.displayString)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.separatorColor).opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color(.separatorColor), lineWidth: 1)
                    )
                    .clipShape(.rect(cornerRadius: 5))
            }

            Button("Edit", systemImage: "pencil", action: onEdit)
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .foregroundStyle(.tertiary)

            Button("Delete", systemImage: "trash", action: onDelete)
                .buttonStyle(.plain)
                .labelStyle(.iconOnly)
                .foregroundStyle(Color(.systemRed).opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    /// Generates a comma-separated summary of the preset's display configurations.
    private var configurationSummary: String {
        let details = preset.configurations.map { config in
            let hiDPI = config.mode.isHiDPI ? "HiDPI" : "Standard"
            return "\(hiDPI) · \(config.mode.shortDisplayString)"
        }
        return details.joined(separator: ", ")
    }
}

/// A sheet view for creating or editing a resolution preset.
///
/// Provides an interface for naming the preset, selecting display modes for each display,
/// and optionally recording a keyboard shortcut. Supports both creating new presets and
/// editing existing ones.
struct PresetEditorSheet: View {
    let displayManager: any DisplayManaging
    let settingsManager: any SettingsManaging
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



/// The about tab showing app information.
///
/// Displays the app name, version, icon, build number, and description,
/// along with metadata and link buttons.
struct AboutTab: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 0) {
            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(.rect(cornerRadius: 18))
                .shadow(color: .accentColor.opacity(0.2), radius: 10, y: 4)
                .padding(.bottom, 14)

            // App name
            Text("DisplayApp")
                .font(.system(size: 20, weight: .bold))
                .padding(.bottom, 4)

            // Version + build
            Text("Version \(appVersion) (Build \(buildNumber))")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.bottom, 10)

            // Description
            Text("A lightweight menu bar utility for instantly switching display resolutions on macOS.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .padding(.bottom, 20)

            // Divider
            Divider()
                .padding(.bottom, 16)

            // Metadata grid
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                GridRow {
                    AboutMetaItem(label: "Developer", value: "Stephen Uffelman")
                    AboutMetaItem(label: "License", value: "Single User")
                }
                GridRow {
                    AboutMetaItem(label: "macOS", value: "14.0+ Required")
                    AboutMetaItem(label: "Framework", value: "SwiftUI")
                }
            }
            .padding(.bottom, 20)

            // Link buttons
            HStack(spacing: 10) {
                Button("Acknowledgements") {}
                    .buttonStyle(.bordered)
                    .tint(.accentColor)

                Button("Privacy Policy") {}
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
            }

            Spacer()
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A single metadata item for the About tab's info grid.
struct AboutMetaItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10.5, weight: .semibold).smallCaps())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13))
        }
    }
}

#Preview {
    SettingsView(
        displayManager: MockDisplayManager(),
        settingsManager: MockSettingsManager(),
        onPresetsChanged: nil
    )
}
