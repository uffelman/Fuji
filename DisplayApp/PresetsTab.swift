//
//  PresetsTab.swift
//  DisplayApp
//
//  Created by Stephen Uffelman on 2/19/26.
//

import ApplicationServices
import Foundation
import SwiftUI

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
private struct AccessibilityPermissionWarning: View {
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
