//
//  PresetsSettingsTab.swift
//  Fuji
//
//  Created by Stephen Uffelman on 2/19/26.
//

import ApplicationServices
import SwiftUI

/// The presets management tab.
///
/// Allows users to create, edit, delete, and reorder resolution presets.
/// Shows warnings when accessibility permissions are not granted.
struct PresetsSettingsTab<DM: DisplayManaging>: View {
    let displayManager: DM
    let settingsManager: SettingsManager
    let onPresetsChanged: (() -> Void)?

    @State private var showingAddPreset = false
    @State private var editingPreset: ResolutionPreset?
    @State private var hasAccessibilityPermission = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(.presetsTitle)
                    .font(.system(size: 15, weight: .semibold))

                Text(.presetsSubtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }

            if !hasAccessibilityPermission {
                AccessibilityPermissionWarning {
                    hasAccessibilityPermission = checkAccessibilityPermission()
                }
            }

            ScrollView {
                if settingsManager.presets.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.stack.badge.plus")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(.presetsEmptyTitle)
                            .font(.headline)
                        Text(.presetsEmptyDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.vertical, alignment: .center)
                } else {
                    VStack(spacing: 0) {
                        ForEach(settingsManager.presets) { preset in
                            if preset.id != settingsManager.presets.first?.id {
                                Divider()
                            }
                            PresetRow(
                                preset: preset,
                                onEdit: {
                                    editingPreset = preset
                                },
                                onDelete: {
                                    settingsManager.deletePreset(preset)
                                    onPresetsChanged?()
                                })
                        }
                        .padding(.trailing)
                    }
                    .background(Color(.controlBackgroundColor))
                    .clipShape(.rect(cornerRadius: 10))
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            
            PillButton(.presetsAddButton, style: .monochrome) {
                showingAddPreset = true
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal)
        .sheet(isPresented: $showingAddPreset) {
            PresetEditorSheet(
                displayManager: displayManager,
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
private struct AccessibilityPermissionWarning: View {
    let onRecheck: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(.presetsAccessibilityTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(.presetsAccessibilityBody)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if let url = URL(
                    string:
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                ) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text(.presetsOpenSettings)
            }

            Button {
                onRecheck()
            } label: {
                Text(.presetsRecheck)
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

#Preview {
    PresetsSettingsTab(
        displayManager: MockDisplayManager.preview,
        settingsManager: SettingsManager(defaults: .preview),
        onPresetsChanged: nil
    )
}
