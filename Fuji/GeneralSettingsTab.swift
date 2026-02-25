//
//  GeneralSettingsTab.swift
//  Fuji
//
//  Created by Stephen Uffelman on 2/19/26.
//

import OSLog
import ServiceManagement
import SwiftUI

/// The general settings tab.
///
/// Provides controls for launch at login and dock visibility preferences.
/// In debug builds, an additional Developer section exposes convenience toggles
/// that are never compiled into release builds.
struct GeneralSettingsTab: View {
    let settingsManager: any SettingsManaging
    let onIncrementSettingsChanged: (() -> Void)?

    @State private var launchAtLogin = false
    @State private var showInDock = false
    @State private var showResolutionOverlay = true
    @State private var enableIncrementShortcuts = true
    @State private var incrementUpShortcut: KeyboardShortcut?
    @State private var incrementDownShortcut: KeyboardShortcut?
    @State private var isRecordingUpShortcut = false
    @State private var isRecordingDownShortcut = false

    private let shortcutRecorder = ShortcutRecorder()

    // Kept inside the view so the toggle stays reactive.
    // Compiled away entirely in release builds.
    #if DEBUG
    @State private var forceOnboarding = DebugSettings.alwaysShowOnboarding
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("General")
                .font(.system(size: 15, weight: .semibold))

            // Settings card
            VStack(spacing: 0) {
                SettingsFormRow(
                    label: "Show overlay when switching resolutions",
                    isOn: $showResolutionOverlay,
                    onChange: { newValue in
                        settingsManager.showResolutionOverlay = newValue
                    }
                )

                Divider()

                SettingsFormRow(
                    label: "Launch at Login",
                    isOn: $launchAtLogin,
                    onChange: { newValue in
                        settingsManager.launchAtLogin = newValue
                        updateLaunchAtLogin(enabled: newValue)
                    }
                )
                
                Divider()

                SettingsFormRow(
                    label: "Show in Dock",
                    isOn: $showInDock,
                    onChange: { newValue in
                        settingsManager.showInDock = newValue
                    }
                )
                
                Divider()
                
                SettingsFormRow(
                    label: "Increment resolutions with keyboard shortcuts",
                    isOn: $enableIncrementShortcuts,
                    onChange: { newValue in
                        settingsManager.enableIncrementShortcuts = newValue
                        onIncrementSettingsChanged?()
                    }
                )

                VStack(spacing: 0) {
                    IncrementShortcutRow(
                        label: "Increase",
                        shortcut: incrementUpShortcut,
                        defaultShortcut: .defaultIncrementUp,
                        isRecording: $isRecordingUpShortcut,
                        shortcutRecorder: shortcutRecorder,
                        onShortcutChanged: { newShortcut in
                            incrementUpShortcut = newShortcut
                            settingsManager.incrementUpShortcut = newShortcut
                            onIncrementSettingsChanged?()
                        },
                        onReset: {
                            incrementUpShortcut = nil
                            settingsManager.incrementUpShortcut = nil
                            onIncrementSettingsChanged?()
                        }
                    )

                    Divider()

                    IncrementShortcutRow(
                        label: "Decrease",
                        shortcut: incrementDownShortcut,
                        defaultShortcut: .defaultIncrementDown,
                        isRecording: $isRecordingDownShortcut,
                        shortcutRecorder: shortcutRecorder,
                        onShortcutChanged: { newShortcut in
                            incrementDownShortcut = newShortcut
                            settingsManager.incrementDownShortcut = newShortcut
                            onIncrementSettingsChanged?()
                        },
                        onReset: {
                            incrementDownShortcut = nil
                            settingsManager.incrementDownShortcut = nil
                            onIncrementSettingsChanged?()
                        }
                    )
                }
                .padding(.leading, 14)
                .frame(maxHeight: enableIncrementShortcuts ? .none : 0)
                .clipped()
                .allowsHitTesting(enableIncrementShortcuts)
            }
            .background(Color(.controlBackgroundColor))
            .clipShape(.rect(cornerRadius: 10))
            .animation(.easeInOut(duration: 0.25), value: enableIncrementShortcuts)

            // ── Developer section ─────────────────────────────────────────
            // Visible only in Debug builds. The entire block is stripped by the
            // compiler when building with the Release / Archive scheme.
            #if DEBUG
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "wrench.fill")
                        .foregroundStyle(Color(.systemOrange))
                    Text("Developer")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(.systemOrange))
                }

                Text("Visible in Debug builds only — never shown to users.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)

                VStack(spacing: 0) {
                    SettingsFormRow(
                        label: "Always show onboarding at launch",
                        isOn: $forceOnboarding,
                        onChange: {
                            DebugSettings.alwaysShowOnboarding = $0
                        }
                    )
                }
                .background(Color(.controlBackgroundColor).opacity(0.6))
                .clipShape(.rect(cornerRadius: 10))
            }
            .padding(14)
            .background(Color.orange.opacity(0.08))
            .clipShape(.rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
            #endif

            Spacer()
        }
        .padding()
        .onAppear {
            launchAtLogin = settingsManager.launchAtLogin
            showInDock = settingsManager.showInDock
            showResolutionOverlay = settingsManager.showResolutionOverlay
            enableIncrementShortcuts = settingsManager.enableIncrementShortcuts
            incrementUpShortcut = settingsManager.incrementUpShortcut
            incrementDownShortcut = settingsManager.incrementDownShortcut
            #if DEBUG
            forceOnboarding = DebugSettings.alwaysShowOnboarding
            #endif
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

/// A reusable form row with a leading text label and a trailing control.
private struct SettingsFormRow: View {
    let label: String
    @Binding var isOn: Bool
    let onChange: ((Bool) -> Void)?

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13.5))
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .onChange(of: isOn) { _, newValue in
                    onChange?(newValue)
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

/// A row for displaying and recording an increment/decrement keyboard shortcut.
///
/// Shows the current shortcut (or default), a reset button when custom, and a Record/Cancel toggle.
/// Mirrors the shortcut recording pattern from ``PresetEditorSheet``.
private struct IncrementShortcutRow: View {
    let label: String
    let shortcut: KeyboardShortcut?
    let defaultShortcut: KeyboardShortcut
    @Binding var isRecording: Bool
    let shortcutRecorder: ShortcutRecorder
    let onShortcutChanged: (KeyboardShortcut?) -> Void
    let onReset: () -> Void

    private var effectiveShortcut: KeyboardShortcut {
        shortcut ?? defaultShortcut
    }

    private var isCustom: Bool {
        shortcut != nil
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 13.5))
                .frame(width: 65, alignment: .leading)

            if isRecording {
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
            } else {
                Text(effectiveShortcut.displayString)
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
            }

            // Reset to default button (only shown when a custom shortcut is set)
            if isCustom && !isRecording {
                Button {
                    onReset()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Reset to default")
            }

            Spacer()

            PillButton(
                isRecording ? "Cancel" : "Record",
                style: .monochrome
            ) {
                if isRecording {
                    shortcutRecorder.stopRecording()
                    isRecording = false
                } else {
                    isRecording = true
                    shortcutRecorder.onShortcutRecorded = { recorded in
                        onShortcutChanged(recorded)
                        isRecording = false
                    }
                    shortcutRecorder.startRecording()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

#Preview {
    GeneralSettingsTab(
        settingsManager: MockSettingsManager.preview,
        onIncrementSettingsChanged: nil
    )
}
