//
//  GeneralSettingsTab.swift
//  Fuji
//
//  Created by Stephen Uffelman on 2/19/26.
//

import OSLog
import SwiftUI

/// The general settings tab.
///
/// Provides controls for launch at login and dock visibility preferences.
/// In debug builds, an additional Developer section exposes convenience toggles
/// that are never compiled into release builds.
struct GeneralSettingsTab: View {
    
    @Environment(SettingsManager.self) private var settingsManager
    let onIncrementSettingsChanged: (() -> Void)?

    @State private var isRecordingUpShortcut = false
    @State private var isRecordingDownShortcut = false

    private let shortcutRecorder = ShortcutRecorder()

    #if DEBUG
    @State private var forceOnboarding = DebugSettings.alwaysShowOnboarding
    #endif

    var body: some View {
        @Bindable var settingsManager = settingsManager

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(.generalTitle)
                    .font(.system(size: 15, weight: .semibold))
                
                // Settings card
                VStack(spacing: 0) {
                    SettingsFormRow(
                        label: .generalShowOverlay,
                        isOn: $settingsManager.showResolutionOverlay
                    )
                    
                    Divider()
                    
                    SettingsFormRow(
                        label: .generalLaunchAtLogin,
                        isOn: $settingsManager.launchAtLogin
                    )
                    
                    Divider()
                    
                    SettingsFormRow(
                        label: .generalShowInDock,
                        isOn: $settingsManager.showInDock
                    )
                    
                    Divider()
                    
                    SettingsFormRow(
                        label: .generalEnableIncrementShortcuts,
                        isOn: $settingsManager.enableIncrementShortcuts
                    )
                    
                    VStack(spacing: 0) {
                        IncrementShortcutRow(
                            label: .generalIncrease,
                            shortcut: settingsManager.incrementUpShortcut,
                            defaultShortcut: .defaultIncrementUp,
                            isRecording: $isRecordingUpShortcut,
                            shortcutRecorder: shortcutRecorder,
                            onShortcutChanged: { newShortcut in
                                settingsManager.incrementUpShortcut = newShortcut
                                onIncrementSettingsChanged?()
                            },
                            onReset: {
                                settingsManager.incrementUpShortcut = nil
                                onIncrementSettingsChanged?()
                            }
                        )
                        
                        Divider()
                        
                        IncrementShortcutRow(
                            label: .generalDecrease,
                            shortcut: settingsManager.incrementDownShortcut,
                            defaultShortcut: .defaultIncrementDown,
                            isRecording: $isRecordingDownShortcut,
                            shortcutRecorder: shortcutRecorder,
                            onShortcutChanged: { newShortcut in
                                settingsManager.incrementDownShortcut = newShortcut
                                onIncrementSettingsChanged?()
                            },
                            onReset: {
                                settingsManager.incrementDownShortcut = nil
                                onIncrementSettingsChanged?()
                            }
                        )
                    }
                    .padding(.leading, 14)
                    .frame(maxHeight: settingsManager.enableIncrementShortcuts ? .none : 0)
                    .clipped()
                    .allowsHitTesting(settingsManager.enableIncrementShortcuts)
                }
                .background(Color(.controlBackgroundColor))
                .clipShape(.rect(cornerRadius: 10))
                .animation(.easeInOut(duration: 0.25), value: settingsManager.enableIncrementShortcuts)
                
                // ── Developer section ─────────────────────────────────────────
                // Visible only in Debug builds. The entire block is stripped by the
                // compiler when building with the Release / Archive scheme.
#if DEBUG
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "wrench.fill")
                            .foregroundStyle(Color(.systemOrange))
                        Text(.generalDeveloper)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(.systemOrange))
                    }
                    
                    Text(.generalDeveloperDescription)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                    
                    VStack(spacing: 0) {
                        SettingsFormRow(
                            label: .generalAlwaysShowOnboarding,
                            isOn: Binding(
                                get: { DebugSettings.alwaysShowOnboarding },
                                set: { DebugSettings.alwaysShowOnboarding = $0 }
                            )
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
            }
            .padding()
        }
    }
}

/// A reusable form row with a leading text label and a trailing control.
private struct SettingsFormRow: View {
    let label: LocalizedStringResource
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13.5))
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
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
    let label: LocalizedStringResource
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
                Text(.generalPressKeyCombo)
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
                .help(String(localized: .generalResetToDefault))
            }

            Spacer()

            PillButton(
                isRecording ? .generalCancel : .generalRecordShortcut,
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
        onIncrementSettingsChanged: nil
    )
    .environment(SettingsManager(defaults: .preview))
}
